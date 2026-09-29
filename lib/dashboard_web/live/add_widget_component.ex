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
    refresh: "Rafraîchissement",
    confirm: "Confirmation"
  ]

  @rate_presets [30, 60, 300, 900, 3600]
  @default_rate 300

  @widget_labels %{
    "standings" => {"Classement", "hero-trophy"},
    "news" => {"Actualités", "hero-newspaper"},
    "stats" => {"Statistiques", "hero-chart-bar"},
    "next_match" => {"Prochain match", "hero-calendar-days"}
  }

  @param_labels %{
    "league" => {"Championnat", "ex : ligue-1"},
    "number" => {"Nombre d'éléments", "ex : 5"},
    "team" => {"Équipe / joueur", "ex : psg"}
  }

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       step: :type,
       widget_type: nil,
       config: %{},
       config_errors: %{},
       refresh_rate: @default_rate,
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
        config =
          if socket.assigns.widget_type == widget_type, do: socket.assigns.config, else: %{}

        {:noreply,
         assign(socket,
           widget_type: widget_type,
           config: config,
           config_errors: %{},
           step: :config
         )}
    end
  end

  def handle_event("validate_config", %{"config" => config}, socket) do
    errors =
      Map.drop(socket.assigns.config_errors, Map.keys(changed(socket.assigns.config, config)))

    {:noreply, assign(socket, config: config, config_errors: errors)}
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
    {:noreply, assign_rate(socket, rate)}
  end

  def handle_event("change_rate", %{"refresh_rate" => rate}, socket) do
    {:noreply, assign_rate(socket, rate)}
  end

  def handle_event("submit_rate", params, socket) do
    socket = assign_rate(socket, Map.get(params, "refresh_rate", socket.assigns.refresh_rate))

    if socket.assigns.rate_error do
      {:noreply, socket}
    else
      {:noreply, assign(socket, step: :confirm)}
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
        {:noreply, assign(socket, submit_error: "Impossible d'ajouter ce widget, réessaie.")}
    end
  end

  defp assign_rate(socket, rate) do
    case parse_rate(rate) do
      {:ok, rate} -> assign(socket, refresh_rate: rate, rate_error: nil)
      {:error, message} -> assign(socket, refresh_rate: rate, rate_error: message)
    end
  end

  defp parse_rate(rate) when is_integer(rate) do
    range = WidgetInstance.refresh_rate_range()

    if rate in range do
      {:ok, rate}
    else
      {:error,
       "Choisis une valeur entre #{format_rate(range.first)} et #{format_rate(range.last)}."}
    end
  end

  defp parse_rate(rate) when is_binary(rate) do
    case Integer.parse(String.trim(rate)) do
      {rate, ""} -> parse_rate(rate)
      _ -> {:error, "Indique un nombre de secondes."}
    end
  end

  defp changed(old, new), do: Map.reject(new, fn {key, value} -> Map.get(old, key) == value end)

  defp previous_step(step) do
    keys = Keyword.keys(@steps)
    index = Enum.find_index(keys, &(&1 == step))
    Enum.at(keys, max(index - 1, 0))
  end

  defp step_index(step), do: Enum.find_index(Keyword.keys(@steps), &(&1 == step))

  defp widget_label(name) do
    case Map.get(@widget_labels, name) do
      {label, _icon} -> label
      nil -> name |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp widget_icon(name) do
    case Map.get(@widget_labels, name) do
      {_label, icon} -> icon
      nil -> "hero-squares-2x2"
    end
  end

  defp param_label(name) do
    case Map.get(@param_labels, name) do
      {label, _placeholder} -> label
      nil -> name |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp param_placeholder(name) do
    case Map.get(@param_labels, name) do
      {_label, placeholder} -> placeholder
      nil -> nil
    end
  end

  defp error_message("can't be blank"), do: "Ce champ est requis."
  defp error_message("must be an integer"), do: "Doit être un nombre entier."
  defp error_message("is too long"), do: "Valeur trop longue."
  defp error_message(message), do: message

  @doc """
  Formats a refresh rate in seconds for humans (`90` -> `"90 s"`, `300` -> `"5 min"`).
  """
  def format_rate(seconds) when is_integer(seconds) do
    cond do
      seconds >= 3600 and rem(seconds, 3600) == 0 -> "#{div(seconds, 3600)} h"
      seconds >= 60 and rem(seconds, 60) == 0 -> "#{div(seconds, 60)} min"
      true -> "#{seconds} s"
    end
  end

  def format_rate(_seconds), do: "—"

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        steps: @steps,
        rate_presets: @rate_presets,
        rate_range: WidgetInstance.refresh_rate_range()
      )

    ~H"""
    <div id={@id} class="space-y-8">
      <div class="space-y-2 pr-8">
        <h2 class="glass-title text-3xl">Ajouter un widget</h2>
        <p class="glass-muted capitalize">{@service}</p>
      </div>

      <.stepper steps={@steps} current={@step} />

      <div :if={@step == :type} class="space-y-4">
        <p class="glass-muted">Quel type de widget veux-tu ajouter ?</p>

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
            <span class="glass-muted text-sm font-normal">{widget_type.description}</span>
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
          Configure ton widget <span class="font-semibold">{widget_label(@widget_type.name)}</span>.
        </p>

        <div :for={param <- @widget_type.params} class="space-y-2">
          <label for={"config_#{param.name}"} class="block text-sm font-medium">
            {param_label(param.name)}
          </label>
          <input
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

        <.nav_buttons myself={@myself} submit_label="Suivant" />
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
        <p class="glass-muted">À quelle fréquence le widget doit-il se mettre à jour ?</p>

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

        <div class="space-y-2">
          <label for="refresh_rate" class="block text-sm font-medium">
            Ou une valeur personnalisée (en secondes)
          </label>
          <input
            id="refresh_rate"
            name="refresh_rate"
            type="number"
            min={@rate_range.first}
            max={@rate_range.last}
            value={@refresh_rate}
            phx-debounce="200"
            class={["glass-input", @rate_error && "ring-2 ring-error/60"]}
          />
          <p :if={@rate_error} class="text-sm text-error flex gap-1 items-center">
            <.icon name="hero-exclamation-circle" class="size-4" />
            {@rate_error}
          </p>
        </div>

        <.nav_buttons myself={@myself} submit_label="Suivant" />
      </.form>

      <div :if={@step == :confirm} class="space-y-6">
        <p class="glass-muted">Vérifie les informations avant d'ajouter le widget.</p>

        <dl class="glass-panel rounded-2xl divide-y divide-(color:--glass-border)">
          <.summary_row label="Sport" value={@service} />
          <.summary_row label="Widget" value={widget_label(@widget_type.name)} />
          <.summary_row
            :for={param <- @widget_type.params}
            label={param_label(param.name)}
            value={Map.get(@config, param.name)}
          />
          <.summary_row label="Rafraîchissement" value={"Toutes les #{format_rate(@refresh_rate)}"} />
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
            <.icon name="hero-arrow-left" class="size-4 mr-2" /> Retour
          </button>
          <button
            type="button"
            phx-click="confirm"
            phx-target={@myself}
            phx-disable-with="Ajout…"
            class="glass-button cursor-pointer text-primary font-semibold"
          >
            <.icon name="hero-check" class="size-4 mr-2" /> Ajouter le widget
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
        <.icon name="hero-arrow-left" class="size-4 mr-2" /> Retour
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
