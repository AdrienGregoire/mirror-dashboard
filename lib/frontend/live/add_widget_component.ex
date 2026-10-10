#
## EPITECH PROJECT, 2026
## add_widget_component.ex
## File description:
## "Add a widget" flow: type, configuration, refresh rate, confirmation
#

defmodule DashboardWeb.AddWidgetComponent do
  @moduledoc """
  Four steps flow adding a widget of `service` to the `user` dashboard.
  Notifies the parent LiveView with `{DashboardWeb.AddWidgetComponent, {:added, widget}}`
  once the widget is created.
  """
  use DashboardWeb, :live_component

  alias Dashboard.{Services, Widgets}
  alias Dashboard.Services.WidgetType
  alias Dashboard.Widgets.WidgetInstance

  @steps [
    type: "Type",
    config: "Configuration",
    refresh: "Refresh",
    confirm: "Confirmation"
  ]

  @rate_presets [30, 60, 300, 900, 3600]
  @default_rate 300

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       step: :type,
       widget_type: nil,
       config: %{},
       config_errors: %{},
       dynamic_options: %{},
       refresh_rate: @default_rate,
       rate_parts: rate_parts(@default_rate),
       rate_error: nil,
       submit_error: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    service = Services.get_service(assigns.service)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(widget_types: if(service, do: service.widgets, else: []))}
  end

  @impl true
  def handle_event("select_type", %{"widget" => name}, socket) do
    case Enum.find(socket.assigns.widget_types, &(&1.name == name)) do
      nil ->
        {:noreply, socket}

      widget_type ->
        same_type? = socket.assigns.widget_type == widget_type
        config = if same_type?, do: socket.assigns.config, else: %{}
        dynamic_options = if same_type?, do: socket.assigns.dynamic_options, else: %{}

        {:noreply,
         socket
         |> assign(
           widget_type: widget_type,
           config: config,
           config_errors: %{},
           dynamic_options: dynamic_options,
           step: :config
         )
         |> load_options()}
    end
  end

  def handle_event("validate_config", %{"config" => config}, socket) do
    old_config = socket.assigns.config
    config = reset_dependents(socket.assigns.widget_type, old_config, config)
    errors = Map.drop(socket.assigns.config_errors, Map.keys(changed(old_config, config)))

    {:noreply,
     socket
     |> assign(config: config, config_errors: errors)
     |> load_options()}
  end

  def handle_event("submit_config", params, socket) do
    config = Map.get(params, "config", %{})

    case WidgetType.cast_config(socket.assigns.widget_type, config) do
      {:ok, _casted} ->
        {:noreply, assign(socket, config: config, config_errors: %{}, step: :refresh)}

      {:error, errors} ->
        {:noreply, assign(socket, config: config, config_errors: Map.new(errors))}
    end
  end

  def handle_event("select_rate", %{"rate" => rate}, socket) do
    {:noreply, assign_rate(socket, rate_parts(String.to_integer(rate)))}
  end

  def handle_event("change_rate", %{"rate" => parts}, socket) do
    {:noreply, assign_rate(socket, parts)}
  end

  def handle_event("submit_rate", params, socket) do
    socket = assign_rate(socket, Map.get(params, "rate", socket.assigns.rate_parts))

    if socket.assigns.rate_error do
      {:noreply, socket}
    else
      {:noreply,
       assign(socket, rate_parts: rate_parts(socket.assigns.refresh_rate), step: :confirm)}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: previous_step(socket.assigns.step), submit_error: nil)}
  end

  def handle_event("confirm", _params, socket) do
    %{user: user, service: service, widget_type: widget_type} = socket.assigns

    attrs = %{
      service: service,
      widget: widget_type.name,
      config: socket.assigns.config,
      refresh_rate: socket.assigns.refresh_rate
    }

    case Widgets.add_widget(user, attrs) do
      {:ok, widget} ->
        send(self(), {__MODULE__, {:added, widget}})
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply,
         assign(socket, submit_error: gettext("Unable to add this widget. Please try again."))}
    end
  end

  @impl true
  def handle_async({:options, name}, result, socket) do
    case {result, socket.assigns.dynamic_options[name]} do
      {{:ok, {key, options}}, %{key: key}} ->
        {:noreply, put_options(socket, name, key, options)}

      {{:exit, reason}, %{key: key}} ->
        {:noreply,
         put_options(
           socket,
           name,
           key,
           {:error, "#{gettext("Unable to load:")} #{inspect(reason)}"}
         )}

      _ ->
        {:noreply, socket}
    end
  end

  defp reset_dependents(nil, _old, config), do: config

  defp reset_dependents(%WidgetType{params: params}, old, config) do
    Enum.reduce(params, config, fn
      %{name: name, depends_on: deps}, config ->
        if Enum.any?(deps, &(Map.get(old, &1) != Map.get(config, &1))),
          do: Map.put(config, name, ""),
          else: config

      _param, config ->
        config
    end)
  end

  defp load_options(socket) do
    %{widget_type: widget_type, config: config} = socket.assigns

    Enum.reduce(widget_type.params, socket, fn
      %{name: name, options_from: {module, function}, depends_on: deps}, socket ->
        values = Map.new(deps, &{&1, config |> Map.get(&1, "") |> to_string() |> String.trim()})
        key = if Enum.all?(values, fn {_dep, value} -> value != "" end), do: values
        current = get_in(socket.assigns.dynamic_options, [name, :key])

        cond do
          key == current ->
            socket

          key == nil ->
            assign(socket, dynamic_options: Map.delete(socket.assigns.dynamic_options, name))

          true ->
            socket
            |> put_options(name, key, :loading)
            |> start_async({:options, name}, fn -> {key, apply(module, function, [key])} end)
        end

      _param, socket ->
        socket
    end)
  end

  defp put_options(socket, name, key, state) do
    assign(socket,
      dynamic_options: Map.put(socket.assigns.dynamic_options, name, %{key: key, state: state})
    )
  end

  defp options_for(%{options: options}, _dynamic) when is_list(options), do: options

  defp options_for(%{name: name, options_from: _}, dynamic) do
    case dynamic[name] do
      %{state: {:ok, options}} -> options
      _ -> []
    end
  end

  defp options_for(_param, _dynamic), do: []

  defp select_param?(param),
    do: Map.has_key?(param, :options) or Map.has_key?(param, :options_from)

  defp options_status(%{name: name, options_from: _}, dynamic) do
    case dynamic[name] do
      nil -> gettext("First, enter the league and the season.")
      %{state: :loading} -> gettext("Loading...")
      %{state: {:error, message}} -> message
      %{state: {:ok, _options}} -> nil
    end
  end

  defp options_status(_param, _dynamic), do: nil

  defp display_value(param, config, dynamic) do
    value = Map.get(config, param.name)

    case Enum.find(options_for(param, dynamic), fn {_label, option} -> option == value end) do
      {label, _value} -> label
      nil -> value
    end
  end

  defp assign_rate(socket, parts) do
    parts = Map.take(parts, ~w(hours minutes seconds))

    case parse_rate(parts) do
      {:ok, rate} ->
        assign(socket, refresh_rate: rate, rate_parts: parts, rate_error: nil)

      {:error, message} ->
        assign(socket, refresh_rate: nil, rate_parts: parts, rate_error: message)
    end
  end

  defp parse_rate(parts) do
    with {:ok, hours} <- parse_unit(parts["hours"]),
         {:ok, minutes} <- parse_unit(parts["minutes"]),
         {:ok, seconds} <- parse_unit(parts["seconds"]) do
      validate_rate(hours * 3600 + minutes * 60 + seconds)
    end
  end

  defp parse_unit(value) when value in [nil, ""], do: {:ok, 0}

  defp parse_unit(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {unit, ""} when unit >= 0 -> {:ok, unit}
      _ -> {:error, gettext("Specifies positive integers (hours, minutes, seconds).")}
    end
  end

  defp parse_unit(_value),
    do: {:error, gettext("Specifies positive integers (hours, minutes, seconds).")}

  defp validate_rate(rate) do
    range = WidgetInstance.refresh_rate_range()

    if rate in range do
      {:ok, rate}
    else
      {:error,
       "#{gettext("Choose a value between")} #{format_rate(range.first)} #{gettext("and")} #{format_rate(range.last)}."}
    end
  end

  defp rate_parts(seconds) do
    %{
      "hours" => to_string(div(seconds, 3600)),
      "minutes" => to_string(div(rem(seconds, 3600), 60)),
      "seconds" => to_string(rem(seconds, 60))
    }
  end

  defp changed(old, new), do: Map.reject(new, fn {key, value} -> Map.get(old, key) == value end)

  defp previous_step(step) do
    keys = Keyword.keys(@steps)
    index = Enum.find_index(keys, &(&1 == step))
    Enum.at(keys, max(index - 1, 0))
  end

  defp step_index(step), do: Enum.find_index(Keyword.keys(@steps), &(&1 == step))

  defp widget_label(name) do
    labels = %{
      "standings" => gettext("Standings"),
      "news" => gettext("News"),
      "stats" => gettext("Stats"),
      "next_match" => gettext("Next match"),
      "top_scorers" => gettext("Top scorers"),
      "player_ranking" => gettext("Player ranking"),
      "current_events" => gettext("Current events")
    }

    Map.get(labels, name, name |> String.replace("_", " ") |> String.capitalize())
  end

  defp widget_icon(name) do
    icons = %{
      "standings" => "hero-trophy",
      "news" => "hero-newspaper",
      "stats" => "hero-chart-bar",
      "next_match" => "hero-calendar-days",
      "top_scorers" => "hero-star",
      "player_ranking" => "hero-trophy",
      "current_events" => "hero-globe-alt"
    }

    Map.get(icons, name, "hero-squares-2x2")
  end

  defp param_label(name) do
    labels = %{
      "league" => gettext("League"),
      "number" => gettext("Number"),
      "team" => gettext("Team"),
      "circuit" => gettext("Circuit (ATP/WTA)"),
      "player" => gettext("Player"),
      "season" => gettext("Season")
    }

    Map.get(labels, name, name |> String.replace("_", " ") |> String.capitalize())
  end

  defp param_placeholder(name) do
    placeholders = %{
      "league" => "ex : ligue-1",
      "number" => "ex : 5",
      "team" => "ex : psg",
      "circuit" => "ex : atp",
      "player" => "ex : jannik sinner",
      "season" => "ex : 2024"
    }

    Map.get(placeholders, name)
  end

  defp error_message("can't be blank"), do: gettext("This field is required.")
  defp error_message("must be an integer"), do: gettext("Must be an integer.")
  defp error_message("is too long"), do: gettext("Value is too long.")
  defp error_message(message), do: Gettext.gettext(DashboardWeb.Gettext, message)

  def format_rate(seconds) when is_integer(seconds) and seconds > 0 do
    [{div(seconds, 3600), "h"}, {div(rem(seconds, 3600), 60), "min"}, {rem(seconds, 60), "s"}]
    |> Enum.reject(fn {value, _unit} -> value == 0 end)
    |> Enum.map_join(" ", fn {value, unit} -> "#{value} #{unit}" end)
  end

  def format_rate(_seconds), do: ""

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        steps: [
          type: gettext("Type"),
          config: gettext("Configuration"),
          refresh: gettext("Refresh"),
          confirm: gettext("Confirmation")
        ],
        rate_presets: @rate_presets,
        rate_units: [
          {"hours", gettext("Hours"), div(WidgetInstance.refresh_rate_range().last, 3600)},
          {"minutes", gettext("Minutes"), 59},
          {"seconds", gettext("Seconds"), 59}
        ]
      )

    ~H"""
    <div id={@id} class="space-y-8">
      <div class="space-y-2 pr-8">
        <h2 class="glass-title text-3xl">{gettext("Add a widget")}</h2>
        <p class="glass-muted capitalize">{@service}</p>
      </div>

      <.stepper steps={@steps} current={@step} />

      <div :if={@step == :type} class="space-y-4">
        <p class="glass-muted">{gettext("What kind of widget do you want to add ?")}</p>
        <div class="grid sm:grid-cols-2 gap-4">
          <button
            :for={widget_type <- @widget_types}
            type="button"
            phx-click="select_type"
            phx-value-widget={widget_type.name}
            phx-target={@myself}
            class={[
              "glass-button cursor-pointer flex-col items-start! justify-start! text-left gap-2 p-5! h-full",
              @widget_type && @widget_type.name == widget_type.name && "ring-2 ring-primary"
            ]}
          >
            <span class="flex items-center gap-2 font-semibold text-base">
              <.icon name={widget_icon(widget_type.name)} class="size-5 text-primary" />
              {widget_label(widget_type.name)}
            </span>
            <span class="glass-muted text-sm font-normal">{Gettext.gettext(
              DashboardWeb.Gettext,
              widget_type.description
            )}</span>
          </button>
        </div>
      </div>

      <.form
        :if={@step == :config}
        for={to_form(@config, as: :config)}
        id="add-widget-config"
        phx-change="validate_config"
        phx-submit="submit_config"
        phx-target={@myself}
        class="space-y-6"
      >
        <p class="glass-muted">
          {gettext("Config your widget")} <span class="font-semibold">{widget_label(@widget_type.name)}</span>.
        </p>

        <div :for={param <- @widget_type.params} class="space-y-2">
          <label for={"config_#{param.name}"} class="block text-sm font-medium">
            {param_label(param.name)}
          </label>
          <select
            :if={select_param?(param)}
            id={"config_#{param.name}"}
            name={"config[#{param.name}]"}
            disabled={not is_nil(options_status(param, @dynamic_options))}
            class={["glass-input", @config_errors[param.name] && "ring-2 ring-error/60"]}
          >
            <option value="">
              {options_status(param, @dynamic_options) || gettext("Choose")}
            </option>
            <option
              :for={{label, value} <- options_for(param, @dynamic_options)}
              value={value}
              selected={Map.get(@config, param.name) == value}
            >
              {label}
            </option>
          </select>
          <input
            :if={!select_param?(param)}
            id={"config_#{param.name}"}
            name={"config[#{param.name}]"}
            type={if param.type == "integer", do: "number", else: "text"}
            value={Map.get(@config, param.name)}
            placeholder={param_placeholder(param.name)}
            phx-debounce="200"
            class={["glass-input", @config_errors[param.name] && "ring-2 ring-error/60"]}
          />
          <p
            :if={message = @config_errors[param.name]}
            class="text-sm text-error flex gap-1 items-center"
          >
            <.icon name="hero-exclamation-circle" class="size-4" />
            {error_message(message)}
          </p>
        </div>

        <.nav_buttons myself={@myself} submit_label={gettext("Next")} />
      </.form>

      <.form
        :if={@step == :refresh}
        for={%{}}
        id="add-widget-refresh"
        phx-change="change_rate"
        phx-submit="submit_rate"
        phx-target={@myself}
        class="space-y-6"
      >
        <p class="glass-muted">{gettext("How often should the widget update ?")}</p>
        <div class="flex flex-wrap gap-3">
          <button
            :for={rate <- @rate_presets}
            type="button"
            phx-click="select_rate"
            phx-value-rate={rate}
            phx-target={@myself}
            class={["glass-button cursor-pointer", @refresh_rate == rate && "ring-2 ring-primary"]}
          >
            {format_rate(rate)}
          </button>
        </div>

        <fieldset class="space-y-2">
          <legend class="block text-sm font-medium">
            {gettext("Or a custom duration (hours, minutes, seconds)")}
          </legend>
          <div class="grid grid-cols-3 gap-3">
            <div :for={{key, label, max} <- @rate_units} class="space-y-1">
              <label for={"rate_#{key}"} class="block text-xs glass-muted">{label}</label>
              <input
                id={"rate_#{key}"}
                name={"rate[#{key}]"}
                type="number"
                inputmode="numeric"
                min="0"
                max={max}
                value={@rate_parts[key]}
                phx-debounce="200"
                class={["glass-input", @rate_error && "ring-2 ring-error/60"]}
              />
            </div>
          </div>
          <p :if={@rate_error} class="text-sm text-error flex gap-1 items-center">
            <.icon name="hero-exclamation-circle" class="size-4" />
            {@rate_error}
          </p>
        </fieldset>

        <.nav_buttons myself={@myself} submit_label={gettext("Next")} />
      </.form>

      <div :if={@step == :confirm} class="space-y-6">
        <p class="glass-muted">{gettext("Check the information before adding the widget.")}</p>
        <dl class="glass-panel rounded-2xl divide-y divide-(color:--glass-border)">
          <.summary_row label={gettext("Sport")} value={@service} />
          <.summary_row label={gettext("Widget")} value={widget_label(@widget_type.name)} />
          <.summary_row
            :for={param <- @widget_type.params}
            label={param_label(param.name)}
            value={display_value(param, @config, @dynamic_options)}
          />
          <.summary_row
            label={gettext("Refreshment")}
            value={"#{gettext("Every")} #{format_rate(@refresh_rate)}"}
          />
        </dl>
        <p :if={@submit_error} class="text-sm text-error flex gap-1 items-center">
          <.icon name="hero-exclamation-circle" class="size-4" />
          {@submit_error}
        </p>

        <div class="flex justify-between gap-3">
          <button
            type="button"
            phx-click="back"
            phx-target={@myself}
            class="glass-button cursor-pointer"
          >
            <.icon name="hero-arrow-left" class="size-4 mr-2" /> {gettext("Back")}
          </button>
          <button
            type="button"
            phx-click="confirm"
            phx-target={@myself}
            phx-disable-with={gettext("Add...")}
            class="glass-button cursor-pointer text-primary font-semibold"
          >
            <.icon name="hero-check" class="size-4 mr-2" /> {gettext("Add the widget")}
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :steps, :list, required: true
  attr :current, :atom, required: true

  defp stepper(assigns) do
    assigns = assign(assigns, current_index: step_index(assigns.current))

    ~H"""
    <ol class="flex items-center gap-2">
      <li
        :for={{{_key, label}, index} <- Enum.with_index(@steps)}
        class="flex-1 flex flex-col gap-2"
        aria-current={index == @current_index && "step"}
      >
        <span class={[
          "h-1.5 rounded-full transition-colors duration-300",
          if(index <= @current_index, do: "bg-primary", else: "bg-(color:--glass-field)")
        ]}></span>
        <span class={[
          "text-xs hidden sm:block",
          if(index == @current_index, do: "font-semibold", else: "glass-muted")
        ]}>
          {index + 1}. {label}
        </span>
      </li>
    </ol>
    """
  end

  attr :myself, :any, required: true
  attr :submit_label, :string, required: true

  defp nav_buttons(assigns) do
    ~H"""
    <div class="flex justify-between gap-3">
      <button type="button" phx-click="back" phx-target={@myself} class="glass-button cursor-pointer">
        <.icon name="hero-arrow-left" class="size-4 mr-2" /> {gettext("Back")}
      </button>
      <button type="submit" class="glass-button cursor-pointer text-primary font-semibold">
        {@submit_label} <.icon name="hero-arrow-right" class="size-4 ml-2" />
      </button>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp summary_row(assigns) do
    ~H"""
    <div class="flex justify-between gap-4 px-5 py-3">
      <dt class="glass-muted">{@label}</dt>
      <dd class="font-medium text-right capitalize break-all">{@value}</dd>
    </div>
    """
  end
end
