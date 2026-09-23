#
## EPITECH PROJECT, 2026
## widget_type.ex
## File description:
## Definition of a widget type offered by a service
#

defmodule Dashboard.Services.WidgetType do
  @moduledoc """
  A widget type is the template a user picks to create a widget instance.

  `params` lists the configuration options of the widget. Each param is a
  map with a `:name` and a `:type` (`"string"` or `"integer"`).
  """

  @derive {Jason.Encoder, only: [:name, :description, :params]}
  @enforce_keys [:name, :description, :params]
  defstruct [:name, :description, params: []]

  @param_types ["string", "integer"]

  @type param :: %{name: String.t(), type: String.t()}
  @type t :: %__MODULE__{name: String.t(), description: String.t(), params: [param()]}

  def param_types, do: @param_types
end
