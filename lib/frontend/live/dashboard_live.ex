#
## EPITECH PROJECT, 2026
## dashboard_live.ex
## File description:
## The dashboard grid: widgets filtered by service
#

defmodule DashboardWeb.DashboardLive do
  use DashboardWeb, :live_view

  alias Dashboard.Widgets
  alias Dashboard.Services.{Registry, Provider}

  @widget_labels %{
    "standings" => "Classement",
    "news" => "Actualités",
    "stats" => "Statistiques",
    "next_match" => "Prochain match",
    "top_scorers" => "Top buteurs",
    "player_ranking" => "Classement Joueurs"
  }

  @spec mount(any(), any(), any()) :: {:ok, any()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    widgets = Widgets.list_widgets(user)

    {:ok,
     assign(socket,
       widgets: widgets,
       services: user.preferred_services,
       active_service: List.first(user.preferred_services),
       adding_widget: false,
       widget_data: fetch_all_data(widgets)
     )}
  end

  def handle_event("select_tab", %{"service" => service}, socket) do
    {:noreply, assign(socket, active_service: service)}
  end

  def handle_event("open_add_widget", _params, socket) do
    {:noreply, assign(socket, adding_widget: socket.assigns.active_service != nil)}
  end

  def handle_event("close_add_widget", _params, socket) do
    {:noreply, assign(socket, adding_widget: false)}
  end

  def handle_event("move_widget", %{"id" => id, "new_position" => new_position}, socket) do
    user = socket.assigns.current_user

    with widget when not is_nil(widget) <- Widgets.get_widget(user, id),
         {position, ""} <- Integer.parse(new_position),
         {:ok, _updated} <- Widgets.move_widget(widget, position) do
      {:noreply, assign(socket, widgets: Widgets.list_widgets(user))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_info({DashboardWeb.AddWidgetComponent, {:added, widget}}, socket) do
    widgets = Widgets.list_widgets(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(
       widgets: widgets,
       adding_widget: false,
       widget_data: Map.put(socket.assigns.widget_data, widget.id, safe_fetch(widget))
     )
     |> put_flash(:info, "Widget ajouté !")}
  end

  defp fetch_all_data(widgets) do
    Map.new(widgets, fn widget -> {widget.id, safe_fetch(widget)} end)
  end

  defp safe_fetch(widget) do
    service = Registry.get(widget.service)
    Provider.fetch(service, widget.widget, widget.config, %{})
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp widgets_for(widgets, service), do: Enum.filter(widgets, &(&1.service == service))

  defp widget_label(name), do: Map.get(@widget_labels, name, name)

  defp format_pct(pct),
    do: pct |> :erlang.float_to_binary(decimals: 3) |> String.trim_leading("0")

  def render(assigns) do
    ~H"""
    <div class="relative flex flex-col min-h-screen overflow-hidden bg-(color:--glass-bg-page)">
      <div class="glass-blob top-10 -left-10 bg-(color:--glass-blob-1)"></div>
      <div class="glass-blob top-20 -right-10 bg-(color:--glass-blob-2)"></div>
      <div class="glass-blob -bottom-10 left-1/3 bg-(color:--glass-blob-3)"></div>

      <div class="relative z-10 flex-1 flex flex-col w-full max-w-6xl mx-auto p-4 sm:p-8">
        <div class="space-y-8">
          <div :if={@services == []} class="glass-card p-10 text-center space-y-4">
            <p class="glass-muted">Tu n'as encore choisi aucun sport à suivre.</p>
            <.link href={~p"/onboarding"} class="glass-button text-primary">
              Choisir mes sports
            </.link>
          </div>

          <div :if={@services != []} class="flex flex-wrap items-center gap-3">
            <button
              :for={service <- @services}
              type="button"
              phx-click="select_tab"
              phx-value-service={service}
              class={[
                "glass-button capitalize",
                service == @active_service && "ring-2 ring-primary"
              ]}
            >
              {service}
            </button>

            <button
              id="open-add-widget"
              type="button"
              phx-click="open_add_widget"
              class="glass-button cursor-pointer text-primary font-semibold ml-auto"
            >
              <.icon name="hero-plus" class="size-4 mr-2" /> Ajouter un widget
            </button>
          </div>

          <div
            :if={@services != []}
            id="widget-grid"
            phx-hook=".DragGrid"
            class="grid sm:grid-cols-2 lg:grid-cols-3 gap-6"
          >
            <script :type={Phoenix.LiveView.ColocatedHook} name=".DragGrid">
              export default {
                mounted() {
                  let dragged = null

                  this.el.addEventListener("dragstart", e => {
                    dragged = e.target.closest("[data-widget-id]")
                    e.dataTransfer.effectAllowed = "move"
                  })

                  this.el.addEventListener("dragover", e => e.preventDefault())

                  this.el.addEventListener("drop", e => {
                    e.preventDefault()
                    const target = e.target.closest("[data-widget-id]")
                    if (!target || !dragged || target === dragged) return

                    const cards = [...this.el.querySelectorAll("[data-widget-id]")]
                    const newPosition = cards.indexOf(target)

                    this.pushEvent("move_widget", {
                      id: dragged.dataset.widgetId,
                      new_position: String(newPosition)
                    })

                    dragged = null
                  })
                }
              }
            </script>

            <div
              :for={widget <- widgets_for(@widgets, @active_service)}
              id={"widget-#{widget.id}"}
              data-widget-id={widget.id}
              draggable="true"
              class="glass-card p-6 cursor-grab active:cursor-grabbing space-y-4"
            >
              <p class="glass-title text-lg capitalize font-semibold">
                {widget_label(widget.widget)}
              </p>
              <.widget_content
                widget={widget}
                data={Map.get(@widget_data, widget.id)}
              />
            </div>

            <button
              :if={widgets_for(@widgets, @active_service) == []}
              type="button"
              phx-click="open_add_widget"
              class="glass-card cursor-pointer p-6 min-h-32 flex flex-col items-center justify-center gap-2 glass-muted border-dashed! hover:-translate-y-0.5 transition-all duration-300"
            >
              <.icon name="hero-plus-circle" class="size-8" />
              <span>Aucun widget pour l'instant. Ajoute ton premier !</span>
            </button>
          </div>
        </div>

        <div class="mt-auto pt-12 pb-4 text-center">
          <.link href={~p"/privacy"} class="glass-muted text-sm hover:text-primary transition-colors">
            Privacy Policy
          </.link>
        </div>
      </div>

      <.glass_modal
        :if={@adding_widget}
        id="add-widget-modal"
        on_cancel={JS.push("close_add_widget")}
      >
        <.live_component
          module={DashboardWeb.AddWidgetComponent}
          id="add-widget"
          user={@current_user}
          service={@active_service}
        />
      </.glass_modal>

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  attr :widget, :map, required: true
  attr :data, :any, default: nil

  # Basketball has no draws: the table shows the win percentage instead.
  defp widget_content(
         %{data: {:ok, %{rows: [%{win_pct: _} | _] = rows}}, widget: %{widget: "standings"}} =
           assigns
       ) do
    assigns = assign(assigns, :rows, rows)

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="glass-muted text-xs border-b border-(color:--glass-border)">
            <th class="text-left py-1 pr-2">#</th>
            <th class="text-left py-1 pr-2">Équipe</th>
            <th class="text-center py-1 px-1">MJ</th>
            <th class="text-center py-1 px-1">V</th>
            <th class="text-center py-1 px-1">D</th>
            <th class="text-center py-1 px-1">%V</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={team <- @rows}
            class="border-b border-(color:--glass-border) last:border-0 hover:bg-white/5"
          >
            <td class="py-1.5 pr-2 glass-muted text-xs">{team.position}</td>
            <td class="py-1.5 pr-2 font-medium truncate max-w-[100px]">
              <div class="flex items-center gap-2">
                <img
                  :if={team.logo}
                  src={team.logo}
                  alt={team.name}
                  class="size-5 object-contain shrink-0"
                />
                {team.name}
              </div>
            </td>
            <td class="py-1.5 px-1 text-center glass-muted">{team.played}</td>
            <td class="py-1.5 px-1 text-center">{team.wins}</td>
            <td class="py-1.5 px-1 text-center glass-muted">{team.losses}</td>
            <td class="py-1.5 px-1 text-center font-bold text-primary">
              {format_pct(team.win_pct)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp widget_content(%{data: {:ok, %{rows: rows}}, widget: %{widget: "standings"}} = assigns) do
    assigns = assign(assigns, :rows, rows)

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="glass-muted text-xs border-b border-(color:--glass-border)">
            <th class="text-left py-1 pr-2">#</th>
            <th class="text-left py-1 pr-2">Équipe</th>
            <th class="text-center py-1 px-1">MJ</th>
            <th class="text-center py-1 px-1">V</th>
            <th class="text-center py-1 px-1">N</th>
            <th class="text-center py-1 px-1">D</th>
            <th class="text-center py-1 px-1">Pts</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={team <- @rows}
            class="border-b border-(color:--glass-border) last:border-0 hover:bg-white/5"
          >
            <td class="py-1.5 pr-2 glass-muted text-xs">{team.position}</td>
            <td class="py-1.5 pr-2 font-medium truncate max-w-[100px]">
              <div class="flex items-center gap-2">
                <img src={team.logo} alt={team.name} class="size-5 object-contain shrink-0" />
                {team.name}
              </div>
            </td>
            <td class="py-1.5 px-1 text-center glass-muted">{team.played}</td>
            <td class="py-1.5 px-1 text-center">{team.wins}</td>
            <td class="py-1.5 px-1 text-center glass-muted">{team.draws}</td>
            <td class="py-1.5 px-1 text-center glass-muted">{team.losses}</td>
            <td class="py-1.5 px-1 text-center font-bold text-primary">{team.points}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp widget_content(%{data: {:ok, %{rows: rows}}, widget: %{widget: "top_scorers"}} = assigns) do
    assigns = assign(assigns, :rows, rows)

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="glass-muted text-xs border-b border-(color:--glass-border)">
            <th class="text-left py-1 pr-2">#</th>
            <th class="text-left py-1 pr-2">Joueur</th>
            <th class="text-left py-1 pr-2">Équipe</th>
            <th class="text-center py-1 px-1">MJ</th>
            <th class="text-center py-1 px-1">Passes</th>
            <th class="text-center py-1 px-1">Buts</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={player <- @rows}
            class="border-b border-(color:--glass-border) last:border-0 hover:bg-white/5"
          >
            <td class="py-1.5 pr-2 glass-muted text-xs">{player.position}</td>
            <td class="py-1.5 pr-2 font-medium truncate max-w-[100px]">
              <div class="flex items-center gap-2">
                <img
                  src={player.photo}
                  alt={player.name}
                  class="size-6 rounded-full object-cover shrink-0"
                />
                {player.name}
              </div>
            </td>
            <td class="py-1.5 pr-2 glass-muted truncate max-w-[80px]">{player.team}</td>
            <td class="py-1.5 px-1 text-center glass-muted">{player.played}</td>
            <td class="py-1.5 px-1 text-center glass-muted">{player.assists}</td>
            <td class="py-1.5 px-1 text-center font-bold text-primary">{player.goals}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp widget_content(
         %{data: {:ok, %{rows: rows}}, widget: %{widget: "player_ranking"}} = assigns
       ) do
    assigns = assign(assigns, :rows, rows)

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="glass-muted text-xs border-b border-(color:--glass-border)">
            <th class="text-left py-1 pr-2">#</th>
            <th class="text-left py-1 pr-2">Joueur</th>
            <th class="text-center py-1 px-1">Mvt</th>
            <th class="text-center py-1 px-1">Points</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={player <- @rows}
            class="border-b border-(color:--glass-border) last:border-0 hover:bg-white/5"
          >
            <td class="py-1.5 pr-2 glass-muted text-xs">{player.position}</td>
            <td class="py-1.5 pr-2 font-medium truncate max-w-[150px]">{player.name}</td>
            <td class="py-1.5 px-1 text-center glass-muted">
              <.icon
                :if={player.movement == "up"}
                name="hero-arrow-trending-up"
                class="size-4 text-success"
              />
              <.icon
                :if={player.movement == "down"}
                name="hero-arrow-trending-down"
                class="size-4 text-error"
              />
              <span :if={player.movement == "same"}>-</span>
            </td>
            <td class="py-1.5 px-1 text-center font-bold text-primary">{player.points}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp widget_content(%{data: {:error, reason}} = assigns) do
    assigns = assign(assigns, :reason, inspect(reason))

    ~H"""
    <p class="text-sm text-error flex gap-2 items-center">
      <.icon name="hero-exclamation-circle" class="size-4 shrink-0" /> Erreur : {@reason}
    </p>
    """
  end

  defp widget_content(assigns) do
    ~H"""
    <p class="glass-muted text-sm animate-pulse">Chargement...</p>
    """
  end
end
