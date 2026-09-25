#
## EPITECH PROJECT, 2026
## widgets.ex
## File description:
## Context module for the widget instances of a user dashboard
#

defmodule Dashboard.Widgets do
  @moduledoc """
  The widgets context: add, reconfigure, move and delete the widget
  instances of a user dashboard.

  Positions of a user widgets always go from 0 to `count - 1` with no gap.
  """

  import Ecto.Query

  alias Dashboard.Repo
  alias Dashboard.Accounts.User
  alias Dashboard.Services
  alias Dashboard.Timer
  alias Dashboard.Widgets.WidgetInstance

  def list_widgets(%User{id: user_id}) do
    WidgetInstance
    |> where(user_id: ^user_id)
    |> order_by([:position, :id])
    |> Repo.all()
  end

  @doc """
  Returns every widget instance. Used by the timer when the application boots.
  """
  def list_all do
    WidgetInstance
    |> order_by(:id)
    |> Repo.all()
  end

  @doc """
  Returns a widget only if it belongs to the user.
  """
  def get_widget(%User{id: user_id}, id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} -> Repo.get_by(WidgetInstance, id: id, user_id: user_id)
      :error -> nil
    end
  end

  def change_widget(%WidgetInstance{} = widget_instance, attrs \\ %{}) do
    WidgetInstance.update_changeset(widget_instance, attrs)
  end

  @doc """
  Adds a widget at the end of the user dashboard.

  `attrs` must contain `service`, `widget`, `config` and `refresh_rate`.
  The service must be available to the user (no account needed or subscribed).
  """
  def add_widget(%User{id: user_id} = user, attrs) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

    Repo.transaction(fn ->
      positions = lock_positions(user_id)

      %WidgetInstance{}
      |> WidgetInstance.create_changeset(
        Map.merge(attrs, %{"user_id" => user_id, "position" => length(positions)})
      )
      |> validate_service_available(user)
      |> Repo.insert()
      |> unwrap_or_rollback()
    end)
    |> track_refresh()
  end

  @doc """
  Updates the config and / or the refresh rate of a widget.
  """
  def reconfigure_widget(%WidgetInstance{refresh_rate: previous} = widget_instance, attrs) do
    widget_instance
    |> WidgetInstance.update_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} = result ->
        if updated.refresh_rate != previous, do: Timer.register(updated)
        result

      error ->
        error
    end
  end

  @doc """
  Moves a widget to `new_position`, shifting the widgets in between.
  Out of range positions are clamped to the first / last slot.
  """
  def move_widget(%WidgetInstance{id: id, user_id: user_id}, new_position)
      when is_integer(new_position) do
    Repo.transaction(fn ->
      positions = lock_positions(user_id)

      with %WidgetInstance{position: old} = widget_instance <- Repo.get(WidgetInstance, id) do
        new = new_position |> max(0) |> min(length(positions) - 1)
        others = where(WidgetInstance, [w], w.user_id == ^user_id and w.id != ^id)

        cond do
          new < old ->
            others
            |> where([w], w.position >= ^new and w.position < ^old)
            |> Repo.update_all(inc: [position: 1])

          new > old ->
            others
            |> where([w], w.position > ^old and w.position <= ^new)
            |> Repo.update_all(inc: [position: -1])

          true ->
            :ok
        end

        widget_instance
        |> WidgetInstance.position_changeset(new)
        |> Repo.update()
        |> unwrap_or_rollback()
      else
        nil -> Repo.rollback(:not_found)
      end
    end)
  end

  @doc """
  Deletes a widget and closes the gap it leaves on the dashboard.
  """
  def delete_widget(%WidgetInstance{id: id, user_id: user_id}) do
    Repo.transaction(fn ->
      lock_positions(user_id)

      with %WidgetInstance{position: position} = widget_instance <- Repo.get(WidgetInstance, id),
           {:ok, deleted} <- Repo.delete(widget_instance) do
        WidgetInstance
        |> where([w], w.user_id == ^user_id and w.position > ^position)
        |> Repo.update_all(inc: [position: -1])

        deleted
      else
        nil -> Repo.rollback(:not_found)
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, deleted} = result ->
        Timer.unregister(deleted.id)
        result

      error ->
        error
    end
  end

  defp lock_positions(user_id) do
    WidgetInstance
    |> where(user_id: ^user_id)
    |> select([w], w.position)
    |> lock("FOR UPDATE")
    |> Repo.all()
  end

  defp validate_service_available(changeset, user) do
    service = Ecto.Changeset.get_field(changeset, :service)

    if Services.get_service(service) && not Services.subscribed?(user, service) do
      Ecto.Changeset.add_error(changeset, :service, "requires a subscription")
    else
      changeset
    end
  end

  defp track_refresh({:ok, widget} = result) do
    Timer.register(widget)
    result
  end

  defp track_refresh(error), do: error

  defp unwrap_or_rollback({:ok, result}), do: result
  defp unwrap_or_rollback({:error, reason}), do: Repo.rollback(reason)
end
