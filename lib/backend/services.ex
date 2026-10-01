#
## EPITECH PROJECT, 2026
## services.ex
## File description:
## Context module for services, widget types and user subscriptions
#

defmodule Dashboard.Services do
  @moduledoc """
  The services context: catalog of services / widget types and user
  subscriptions to the services that require an account.
  """

  import Ecto.Query

  alias Dashboard.Repo
  alias Dashboard.Accounts.User
  alias Dashboard.Services.{Registry, Service, Subscription}

  @doc """
  Returns the list of available services on Dashboard
  """
  def list_services, do: Registry.all()

  def get_service(name), do: Registry.get(name)

  def get_widget_type(service_name, widget_name) do
    case Registry.get(service_name) do
      nil -> nil
      service -> Service.get_widget(service, widget_name)
    end
  end

  @doc """
  Services the user can use right now: the ones requiring no account and
  the ones they subscribed to.
  """
  def available_services(%User{} = user) do
    subscribed = MapSet.new(subscribed_service_names(user))

    Enum.filter(Registry.all(), fn service ->
      not Service.requires_subscription?(service) or MapSet.member?(subscribed, service.name)
    end)
  end

  def list_subscriptions(%User{id: user_id}) do
    Subscription
    |> where(user_id: ^user_id)
    |> order_by(:service)
    |> Repo.all()
  end

  def subscribed?(%User{} = user, service_name) do
    case Registry.get(service_name) do
      nil -> false
      %Service{auth: :none} -> true
      _ -> service_name in subscribed_service_names(user)
    end
  end

  @doc """
  Subscribes the user to a service, or replaces the stored credentials if
  the user is already subscribed (e.g. refreshed OAuth tokens).
  """
  def subscribe(%User{id: user_id}, service_name, credentials) do
    %Subscription{}
    |> Subscription.changeset(%{
      user_id: user_id,
      service: service_name,
      credentials: credentials
    })
    |> Repo.insert(
      on_conflict: {:replace, [:credentials, :updated_at]},
      conflict_target: [:user_id, :service],
      returning: true
    )
  end

  def unsubscribe(%User{id: user_id}, service_name) do
    {count, _} =
      Subscription
      |> where(user_id: ^user_id, service: ^service_name)
      |> Repo.delete_all()

    if count > 0, do: :ok, else: {:error, :not_subscribed}
  end

  @doc """
  Returns the decrypted credentials the user stored for a service.
  """
  def get_credentials(%User{id: user_id}, service_name) do
    case Repo.get_by(Subscription, user_id: user_id, service: service_name) do
      nil -> {:error, :not_subscribed}
      %Subscription{credentials: credentials} -> {:ok, credentials}
    end
  end

  defp subscribed_service_names(%User{id: user_id}) do
    Subscription
    |> where(user_id: ^user_id)
    |> select([s], s.service)
    |> Repo.all()
  end
end
