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
  map with a `:name` and a `:type` (`"string"` or `"integer"`), and may carry:

    * `:options` - a list of `{label, value}` the user picks from
    * `:options_from` and `:depends_on` - options computed by `{module, function}`
      from the values of the params listed in `:depends_on`. The function gets
      a map of those raw values and returns `{:ok, [{label, value}]}` or
      `{:error, message}`.
  """

  @enforce_keys [:name, :description, :params]
  defstruct [:name, :description, params: []]

  @param_types ["string", "integer"]
  @max_string_length 2048

  @type option :: {label :: String.t(), value :: String.t()}
  @type param :: %{
          required(:name) => String.t(),
          required(:type) => String.t(),
          optional(:options) => [option()],
          optional(:options_from) => {module(), atom()},
          optional(:depends_on) => [String.t()]
        }
  @type t :: %__MODULE__{name: String.t(), description: String.t(), params: [param()]}

  def param_types, do: @param_types

  @doc """
  Validates a user supplied config against the widget params.

  Every param is required. Integers may be given as strings (form input).
  Unknown keys are dropped. Returns the config with string keys and typed
  values, or the list of `{param_name, message}` errors.
  """
  @spec cast_config(t(), map()) :: {:ok, map()} | {:error, [{String.t(), String.t()}]}
  def cast_config(%__MODULE__{params: params}, config) when is_map(config) do
    config = Map.new(config, fn {key, value} -> {to_string(key), value} end)

    {casted, errors} =
      Enum.reduce(params, {%{}, []}, fn %{name: name, type: type}, {casted, errors} ->
        case cast_param(type, Map.get(config, name)) do
          {:ok, value} -> {Map.put(casted, name, value), errors}
          {:error, message} -> {casted, [{name, message} | errors]}
        end
      end)

    if errors == [], do: {:ok, casted}, else: {:error, Enum.reverse(errors)}
  end

  def cast_config(%__MODULE__{}, _config), do: {:error, [{"config", "is invalid"}]}

  defp cast_param(_type, nil), do: {:error, "can't be blank"}

  defp cast_param("string", value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, "can't be blank"}
      value when byte_size(value) > @max_string_length -> {:error, "is too long"}
      value -> {:ok, value}
    end
  end

  defp cast_param("integer", value) when is_integer(value), do: {:ok, value}

  defp cast_param("integer", value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, "must be an integer"}
    end
  end

  defp cast_param("integer", _value), do: {:error, "must be an integer"}
  defp cast_param(_type, _value), do: {:error, "is invalid"}
end

defimpl Jason.Encoder, for: Dashboard.Services.WidgetType do
  def encode(widget_type, opts) do
    Jason.Encode.map(
      %{
        name: widget_type.name,
        description: widget_type.description,
        params: Enum.map(widget_type.params, &Map.take(&1, [:name, :type]))
      },
      opts
    )
  end
end
