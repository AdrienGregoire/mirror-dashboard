#
## EPITECH PROJECT, 2026
## widget_instance.ex
## File description:
## Ecto Schema of a configured widget placed on a user dashboard
#

defmodule Dashboard.Widgets.WidgetInstance do
  @moduledoc """
  A widget instance is a widget type (`service` + `widget`) configured by a
  user and placed on their dashboard.

    * `config` - values of the widget type params
    * `refresh_rate` - seconds between two data refreshes (used by the timer)
    * `position` - index of the widget on the dashboard, starting at 0
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Dashboard.Services
  alias Dashboard.Services.WidgetType

  @min_refresh_rate 10
  @max_refresh_rate 86_400

  schema "widget_instances" do
    field :service, :string
    field :widget, :string
    field :config, :map, default: %{}
    field :refresh_rate, :integer
    field :position, :integer

    belongs_to :user, Dashboard.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def refresh_rate_range, do: @min_refresh_rate..@max_refresh_rate

  @doc """
  Changeset used when a widget is added to the dashboard.
  """
  def create_changeset(widget_instance, attrs) do
    widget_instance
    |> cast(attrs, [:service, :widget, :config, :refresh_rate, :position, :user_id])
    |> validate_required([:service, :widget, :refresh_rate, :position, :user_id])
    |> validate_widget_type()
    |> validate_config()
    |> validate_refresh_rate()
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset used to reconfigure a widget. The widget type cannot change.
  """
  def update_changeset(widget_instance, attrs) do
    widget_instance
    |> cast(attrs, [:config, :refresh_rate])
    |> validate_required([:refresh_rate])
    |> validate_config()
    |> validate_refresh_rate()
  end

  def position_changeset(widget_instance, position) do
    change(widget_instance, position: position)
  end

  defp validate_widget_type(changeset) do
    service = get_field(changeset, :service)
    widget = get_field(changeset, :widget)

    if service && widget && is_nil(widget_type(changeset)) do
      add_error(changeset, :widget, "does not exist for this service")
    else
      changeset
    end
  end

  defp validate_config(changeset) do
    case widget_type(changeset) do
      nil ->
        changeset

      widget_type ->
        case WidgetType.cast_config(widget_type, get_field(changeset, :config) || %{}) do
          {:ok, config} ->
            put_change(changeset, :config, config)

          {:error, errors} ->
            Enum.reduce(errors, changeset, fn {param, message}, changeset ->
              add_error(changeset, :config, "#{param} #{message}", param: param)
            end)
        end
    end
  end

  defp validate_refresh_rate(changeset) do
    validate_number(changeset, :refresh_rate,
      greater_than_or_equal_to: @min_refresh_rate,
      less_than_or_equal_to: @max_refresh_rate
    )
  end

  defp widget_type(changeset) do
    Services.get_widget_type(get_field(changeset, :service), get_field(changeset, :widget))
  end
end
