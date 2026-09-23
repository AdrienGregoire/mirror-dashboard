#
## EPITECH PROJECT, 2026
## service.ex
## File description:
## Definition of a service and the widget types it provides
#

defmodule Dashboard.Services.Service do
  @moduledoc """
  A service is an external source of data (weather, rss, github, ...).

  `auth` tells how a user gains access to it:

    * `:none` - available by default to any authenticated user
    * `:oauth` - the user links an account, we store its tokens
    * `:credentials` - the user provides a username and a password
  """

  alias Dashboard.Services.WidgetType

  @derive {Jason.Encoder, only: [:name, :widgets]}
  @enforce_keys [:name, :description, :auth, :widgets]
  defstruct [:name, :description, :auth, widgets: []]

  @type auth :: :none | :oauth | :credentials
  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          auth: auth(),
          widgets: [WidgetType.t()]
        }

  def requires_subscription?(%__MODULE__{auth: :none}), do: false
  def requires_subscription?(%__MODULE__{}), do: true

  @doc """
  Keys that must be present in the credentials stored for this service.
  """
  def required_credentials(%__MODULE__{auth: :oauth}), do: ["access_token"]
  def required_credentials(%__MODULE__{auth: :credentials}), do: ["username", "password"]
  def required_credentials(%__MODULE__{auth: :none}), do: []

  def get_widget(%__MODULE__{widgets: widgets}, name) do
    Enum.find(widgets, &(&1.name == name))
  end
end
