#
## EPITECH PROJECT, 2026
## dashboard_live.ex
## File description:
## The dashboard grid: widgets filtered by service
#

defmodule DashboardWeb.DashboardLive do
  use DashboardWeb, :live_view
  alias Dashboard.Widgets

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

  @spec mount(any(), any(), any()) :: {:ok, any()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    widgets = Widgets.list_widgets(user)

    socket =
      assign(socket,
        widgets: widgets,
        services: user.preferred_services,
        active_service: List.first(user.preferred_services),
        adding_widget: false,
        editing_widget: nil,
        widget_data: %{},
        refreshing: MapSet.new()
      )

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Dashboard.PubSub, "dashboard:user:#{user.id}")
      {:ok, load_widgets(socket, widgets)}
    else
      {:ok, socket}
    end
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

  def handle_event("edit_widget", %{"id" => id}, socket) do
    case Widgets.get_widget(socket.assigns.current_user, id) do
      nil -> {:noreply, socket}
      widget -> {:noreply, assign(socket, editing_widget: widget)}
    end
  end

  def handle_event("close_edit_widget", _params, socket) do
    {:noreply, assign(socket, editing_widget: nil)}
  end

  def handle_event("delete_widget", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    with widget when not is_nil(widget) <- Widgets.get_widget(user, id),
         {:ok, deleted} <- Widgets.delete_widget(widget) do
      {:noreply,
       socket
       |> cancel_async({:widget, deleted.id})
       |> assign(
         widgets: Widgets.list_widgets(user),
         widget_data: Map.delete(socket.assigns.widget_data, deleted.id),
         refreshing: MapSet.delete(socket.assigns.refreshing, deleted.id)
       )
       |> put_flash(:info, gettext("Widget deleted."))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("refresh_widget", %{"id" => id}, socket) do
    case Widgets.get_widget(socket.assigns.current_user, id) do
      nil -> {:noreply, socket}
      widget -> {:noreply, load_widgets(socket, [widget], fresh: true)}
    end
  end

  def handle_event("move_widget", %{"id" => id, "new_position" => new_position}, socket) do
    user = socket.assigns.current_user

    with widget when not is_nil(widget) <- Widgets.get_widget(user, id),
         {position, ""} <- Integer.parse(to_string(new_position)),
         {:ok, _updated} <- Widgets.move_widget(widget, position) do
      {:noreply, assign(socket, widgets: Widgets.list_widgets(user))}
    else
      _ -> {:noreply, socket}
    end
  end

  # Replies with the size actually stored so the client can drop its live preview.
  def handle_event("resize_widget", %{"id" => id} = params, socket) do
    user = socket.assigns.current_user

    with widget when not is_nil(widget) <- Widgets.get_widget(user, id),
         {:ok, updated} <-
           Widgets.resize_widget(widget, Map.take(params, ["col_span", "height"])) do
      {:reply, size_reply(updated), assign(socket, widgets: Widgets.list_widgets(user))}
    else
      nil -> {:reply, %{}, socket}
      {:error, _changeset} -> {:reply, size_reply(Widgets.get_widget(user, id)), socket}
    end
  end

  def handle_info({DashboardWeb.AddWidgetComponent, {:added, widget}}, socket) do
    widgets = Widgets.list_widgets(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(widgets: widgets, adding_widget: false)
     |> load_widgets([widget])
     |> put_flash(:info, gettext("Widget added !"))}
  end

  def handle_info({DashboardWeb.AddWidgetComponent, {:updated, widget}}, socket) do
    {:noreply,
     socket
     |> assign(
       widgets: Widgets.list_widgets(socket.assigns.current_user),
       editing_widget: nil,
       widget_data: Map.delete(socket.assigns.widget_data, widget.id)
     )
     |> load_widgets([widget])
     |> put_flash(:info, gettext("Widget updated."))}
  end

  # Sent by `Dashboard.Timer` when the refresh rate of a widget elapsed.
  def handle_info({:refresh_widget, id}, socket) do
    case Enum.find(socket.assigns.widgets, &(&1.id == id)) do
      nil -> {:noreply, socket}
      widget -> {:noreply, load_widgets(socket, [widget])}
    end
  end

  def handle_async({:widget, id}, {:ok, result}, socket) do
    {:noreply, store_widget_data(socket, id, result)}
  end

  def handle_async({:widget, id}, {:exit, reason}, socket) do
    {:noreply, store_widget_data(socket, id, {:error, inspect(reason)})}
  end

  # A result may land after its widget was deleted.
  defp store_widget_data(socket, id, result) do
    if Enum.any?(socket.assigns.widgets, &(&1.id == id)) do
      assign(socket,
        widget_data: Map.put(socket.assigns.widget_data, id, result),
        refreshing: MapSet.delete(socket.assigns.refreshing, id)
      )
    else
      socket
    end
  end

  defp size_reply(widget), do: %{col_span: widget.col_span, height: widget.height}

  defp load_widgets(socket, widgets, opts \\ []) do
    locale = Gettext.get_locale(DashboardWeb.Gettext)

    Enum.reduce(widgets, socket, fn widget, socket ->
      socket
      |> assign(refreshing: MapSet.put(socket.assigns.refreshing, widget.id))
      |> start_async({:widget, widget.id}, fn ->
        Gettext.put_locale(DashboardWeb.Gettext, locale)
        safe_fetch(widget, opts)
      end)
    end)
  end

  defp safe_fetch(widget, opts) do
    Widgets.fetch_data(widget, opts)
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp span_class(2), do: "sm:col-span-2 lg:col-span-2"
  defp span_class(3), do: "sm:col-span-2 lg:col-span-3"
  defp span_class(_), do: nil

  defp widgets_for(widgets, service), do: Enum.filter(widgets, &(&1.service == service))

  defp stat_tiles(stats) do
    [
      {"Matchs", stats.played},
      {"Wins", stats.wins},
      {"Losses", stats.losses},
      {"% Wins", format_pct(stats.win_pct)},
      {"Pts scored", format_avg(stats.points_for_avg)},
      {"Pts allowed", format_avg(stats.points_against_avg)},
      {"Home", "#{stats.home_wins}-#{stats.home_losses}"},
      {"Away", "#{stats.away_wins}-#{stats.away_losses}"}
    ]
  end

  defp format_avg(nil), do: "-"
  defp format_avg(avg), do: :erlang.float_to_binary(avg, decimals: 1)

  defp format_pct(pct),
    do: pct |> :erlang.float_to_binary(decimals: 3) |> String.trim_leading("0")

  defp article_meta(article) do
    date = if article.published_at, do: Calendar.strftime(article.published_at, "%d/%m/%Y")
    [article.source, date] |> Enum.reject(&is_nil/1) |> Enum.join(" - ")
  end

  defp match_time(%{live: true}), do: "In progress"

  defp match_time(%{start_time: start_time, time_confirmed: confirmed}) do
    case DateTime.from_iso8601(start_time || "") do
      {:ok, datetime, _offset} when confirmed ->
        Calendar.strftime(datetime, "%d/%m/%Y   %H:%M UTC")

      {:ok, datetime, _offset} ->
        Calendar.strftime(datetime, "%d/%m/%Y   time to be confirmed")

      _ ->
        "Date to be confirmed"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="relative flex flex-col min-h-screen overflow-hidden bg-(color:--glass-bg-page)">
      <div class="glass-blob top-10 -left-10 bg-(color:--glass-blob-1)"></div>
      <div class="glass-blob top-20 -right-10 bg-(color:--glass-blob-2)"></div>
      <div class="glass-blob -bottom-10 left-1/3 bg-(color:--glass-blob-3)"></div>

      <div class="relative z-10 flex-1 flex flex-col w-full max-w-6xl mx-auto p-4 sm:p-8">
        <div class="space-y-8">
          <div :if={@services == []} class="glass-card p-10 text-center space-y-4">
            <p class="glass-muted">{gettext("You haven't chosen any sports to follow yet.")}</p>
            <.link href={~p"/onboarding"} class="glass-button text-primary">
              {gettext("Choose my sports")}
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
              <.icon name="hero-plus" class="size-4 mr-2" /> {gettext("Add a widget")}
            </button>
          </div>

          <div
            :if={@services != []}
            id="widget-grid"
            phx-hook=".DragGrid"
            class="grid sm:grid-cols-2 lg:grid-cols-3 gap-6"
          >
            <div
              :for={widget <- widgets_for(@widgets, @active_service)}
              id={"widget-#{widget.id}"}
              data-widget-id={widget.id}
              data-position={widget.position}
              data-col-span={widget.col_span}
              style={widget.height && "height: #{widget.height}px"}
              class={["glass-card relative flex flex-col", span_class(widget.col_span)]}
            >
              <div class="flex items-center gap-2 px-6 pt-5 pb-3">
                <div
                  data-drag-handle
                  title={gettext("Drag to move")}
                  class="flex flex-1 min-w-0 items-center gap-2 cursor-grab active:cursor-grabbing select-none"
                >
                  <.icon name="hero-bars-2" class="size-4 glass-muted shrink-0" />
                  <p class="glass-title text-lg capitalize font-semibold truncate">
                    {widget_label(widget.widget)}
                  </p>
                </div>
                <button
                  id={"refresh-widget-#{widget.id}"}
                  type="button"
                  phx-click="refresh_widget"
                  phx-value-id={widget.id}
                  aria-label={gettext("Refresh")}
                  title={gettext("Refresh")}
                  class="cursor-pointer glass-muted hover:text-primary transition-colors"
                >
                  <.icon
                    name="hero-arrow-path"
                    class={["size-4", MapSet.member?(@refreshing, widget.id) && "animate-spin"]}
                  />
                </button>
                <button
                  id={"edit-widget-#{widget.id}"}
                  type="button"
                  phx-click="edit_widget"
                  phx-value-id={widget.id}
                  aria-label={gettext("Edit")}
                  title={gettext("Edit")}
                  class="cursor-pointer glass-muted hover:text-primary transition-colors"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                </button>
                <button
                  id={"delete-widget-#{widget.id}"}
                  type="button"
                  phx-click="delete_widget"
                  phx-value-id={widget.id}
                  data-confirm={gettext("Delete this widget ?")}
                  aria-label={gettext("Delete")}
                  title={gettext("Delete")}
                  class="cursor-pointer glass-muted hover:text-error transition-colors"
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </div>

              <div class="flex-1 min-h-0 overflow-auto px-6 pb-6">
                <.widget_content
                  widget={widget}
                  data={Map.get(@widget_data, widget.id)}
                />
              </div>

              <div
                data-resize-handle
                title={gettext("Drag to resize, double-click to reset")}
                class="absolute bottom-1 right-1 size-5 cursor-nwse-resize touch-none glass-muted hover:text-primary"
              >
                <svg
                  viewBox="0 0 20 20"
                  class="size-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  stroke-linecap="round"
                >
                  <path d="M17 7 7 17M17 12l-5 5" />
                </svg>
              </div>
            </div>

            <button
              :if={widgets_for(@widgets, @active_service) == []}
              type="button"
              phx-click="open_add_widget"
              class="glass-card cursor-pointer p-6 min-h-32 flex flex-col items-center justify-center gap-2 glass-muted border-dashed! hover:-translate-y-0.5 transition-all duration-300"
            >
              <.icon name="hero-plus-circle" class="size-8" />
              <span>{gettext("No widgets yet. Add your first one !")}</span>
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
        on_cancel={Phoenix.LiveView.JS.push("close_add_widget")}
      >
        <.live_component
          module={DashboardWeb.AddWidgetComponent}
          id="add-widget"
          user={@current_user}
          service={@active_service}
        />
      </.glass_modal>

      <.glass_modal
        :if={@editing_widget}
        id="edit-widget-modal"
        on_cancel={Phoenix.LiveView.JS.push("close_edit_widget")}
      >
        <.live_component
          module={DashboardWeb.AddWidgetComponent}
          id="edit-widget"
          user={@current_user}
          service={@editing_widget.service}
          widget={@editing_widget}
        />
      </.glass_modal>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".DragGrid">
        const MIN_HEIGHT = 120
        const MAX_HEIGHT = 1200
        const clamp = (value, min, max) => Math.min(Math.max(value, min), max)

        export default {
          mounted() {
            this.dragged = null
            this.over = null

            const cardOf = (node) => node && node.closest ? node.closest("[data-widget-id]") : null

            this.onPointerDown = (event) => {
              const resize = event.target.closest("[data-resize-handle]")
              if (resize) return this.startResize(event, resize)

              // a card is only draggable from its title: its content stays selectable
              const handle = event.target.closest("[data-drag-handle]")
              const card = handle && cardOf(handle)
              if (card) card.draggable = true
            }

            this.onPointerUp = () => this.resetDraggable()

            this.onDragStart = (event) => {
              const card = cardOf(event.target)
              if (!card || event.target !== card) return

              this.dragged = card
              event.dataTransfer.effectAllowed = "move"
              event.dataTransfer.setData("text/plain", card.dataset.widgetId)
              card.classList.add("opacity-50")
            }

            this.onDragOver = (event) => {
              if (!this.dragged) return
              event.preventDefault()
              event.dataTransfer.dropEffect = "move"

              const target = cardOf(event.target)
              if (target === this.over) return
              this.clearOver()
              if (target && target !== this.dragged) {
                this.over = target
                target.classList.add("ring-2", "ring-primary")
              }
            }

            this.onDrop = (event) => {
              if (!this.dragged) return
              event.preventDefault()

              const target = cardOf(event.target)
              if (target && target !== this.dragged) {
                this.pushEvent("move_widget", {
                  id: this.dragged.dataset.widgetId,
                  new_position: target.dataset.position
                })
              }
            }

            this.onDragEnd = () => {
              if (this.dragged) this.dragged.classList.remove("opacity-50")
              this.dragged = null
              this.clearOver()
              this.resetDraggable()
            }

            this.onDoubleClick = (event) => {
              const resize = event.target.closest("[data-resize-handle]")
              const card = resize && cardOf(resize)
              if (card) this.pushSize(card, 1, null)
            }

            this.el.addEventListener("pointerdown", this.onPointerDown)
            this.el.addEventListener("dragstart", this.onDragStart)
            this.el.addEventListener("dragover", this.onDragOver)
            this.el.addEventListener("drop", this.onDrop)
            this.el.addEventListener("dragend", this.onDragEnd)
            this.el.addEventListener("dblclick", this.onDoubleClick)
            window.addEventListener("pointerup", this.onPointerUp)
          },

          destroyed() {
            window.removeEventListener("pointerup", this.onPointerUp)
          },

          clearOver() {
            if (this.over) this.over.classList.remove("ring-2", "ring-primary")
            this.over = null
          },

          resetDraggable() {
            this.el.querySelectorAll("[data-widget-id][draggable=true]").forEach((card) => {
              card.draggable = false
            })
          },

          // Stretching: the pointer position gives the number of columns spanned
          // (snapped to the grid) and the height in pixels.
          startResize(event, handle) {
            event.preventDefault()
            event.stopPropagation()

            const card = handle.closest("[data-widget-id]")
            const rect = card.getBoundingClientRect()
            const grid = getComputedStyle(this.el)
            const columns = grid.gridTemplateColumns.split(" ").length
            const gap = parseFloat(grid.columnGap) || 0
            const columnWidth = (this.el.clientWidth - gap * (columns - 1)) / columns

            let span = parseInt(card.dataset.colSpan, 10) || 1
            let height = null

            handle.setPointerCapture(event.pointerId)

            const onMove = (move) => {
              if (columns > 1) {
                const wanted = Math.round((move.clientX - rect.left + gap) / (columnWidth + gap))
                span = clamp(wanted, 1, columns)
                card.style.gridColumn = `span ${span}`
              }

              height = clamp(Math.round(move.clientY - rect.top), MIN_HEIGHT, MAX_HEIGHT)
              card.style.height = `${height}px`
            }

            const onUp = () => {
              handle.removeEventListener("pointermove", onMove)
              handle.removeEventListener("pointerup", onUp)
              handle.removeEventListener("pointercancel", onUp)

              if (height !== null) this.pushSize(card, span, height)
            }

            handle.addEventListener("pointermove", onMove)
            handle.addEventListener("pointerup", onUp)
            handle.addEventListener("pointercancel", onUp)
          },

          // The server answers with the size it stored: it replaces the live preview.
          pushSize(card, span, height) {
            this.pushEvent(
              "resize_widget",
              {id: card.dataset.widgetId, col_span: span, height: height},
              (reply) => {
                card.style.gridColumn = ""
                card.style.height = reply.height ? `${reply.height}px` : ""
              }
            )
          }
        }
      </script>

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  attr :widget, :map, required: true
  attr :data, :any, default: nil

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

  defp widget_content(%{data: {:ok, %{win_pct: _} = stats}, widget: %{widget: "stats"}} = assigns) do
    assigns = assign(assigns, :stats, stats)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center gap-3">
        <img
          :if={@stats.logo}
          src={@stats.logo}
          alt={@stats.team}
          class="size-10 object-contain shrink-0"
        />
        <div class="min-w-0">
          <p class="font-semibold truncate">{@stats.team}</p>
          <p class="glass-muted text-xs truncate">{@stats.league} {@stats.season}</p>
        </div>
      </div>

      <dl class="grid grid-cols-3 gap-3 text-center">
        <div :for={{label, value} <- stat_tiles(@stats)}>
          <dd class="text-lg font-bold text-primary">{value}</dd>
          <dt class="glass-muted text-xs">{label}</dt>
        </div>
      </dl>
    </div>
    """
  end

  defp widget_content(
         %{data: {:ok, %{opponent: _} = match}, widget: %{widget: "next_match"}} = assigns
       ) do
    assigns = assign(assigns, :match, match)

    ~H"""
    <div class="space-y-3 text-center">
      <p :if={@match.live} class="text-xs font-semibold text-error animate-pulse">EN DIRECT</p>
      <div class="flex items-center justify-center gap-3">
        <div class="min-w-0">
          <p class="font-semibold truncate">{@match.player}</p>
          <p :if={@match.player_country} class="glass-muted text-xs truncate">
            {@match.player_country}
          </p>
        </div>
        <span class="glass-muted text-sm">vs</span>
        <div class="min-w-0">
          <p class="font-semibold truncate">{@match.opponent}</p>
          <p :if={@match.opponent_country} class="glass-muted text-xs truncate">
            {@match.opponent_country}
          </p>
        </div>
      </div>
      <p class="text-lg font-bold text-primary">{match_time(@match)}</p>
      <p :if={@match.competition} class="glass-muted text-xs truncate">
        {@match.competition}<span :if={@match.round}>{@match.round}</span>
      </p>
      <p :if={@match.venue} class="glass-muted text-xs truncate">
        {@match.venue}<span :if={@match.city}>, {@match.city}</span>
      </p>
    </div>
    """
  end

  defp widget_content(
         %{data: {:ok, %{events: events}}, widget: %{widget: "current_events"}} = assigns
       ) do
    assigns = assign(assigns, :events, events)

    ~H"""
    <div class="space-y-3">
      <div
        :for={event <- @events}
        class="flex items-center justify-between p-2.5 rounded-xl bg-white/5 border border-(color:--glass-border)"
      >
        <div class="min-w-0 pr-2">
          <p class="font-medium text-sm truncate">{event.name}</p>
        </div>
        <span
          :if={event.type}
          class="glass-muted text-xs capitalize shrink-0 px-2 py-0.5 rounded-md bg-white/5"
        >
          {event.type}
        </span>
      </div>
    </div>
    """
  end

  defp widget_content(%{data: {:ok, %{articles: articles}}, widget: %{widget: "news"}} = assigns) do
    assigns = assign(assigns, :articles, articles)

    ~H"""
    <ul class="space-y-3">
      <li
        :for={article <- @articles}
        class="flex gap-3 p-2.5 rounded-xl bg-white/5 border border-(color:--glass-border)"
      >
        <img
          :if={article.image}
          src={article.image}
          alt={article.title}
          loading="lazy"
          class="size-14 rounded-lg object-cover shrink-0"
        />
        <div class="min-w-0">
          <a
            href={article.url}
            target="_blank"
            rel="noopener noreferrer"
            class="font-medium text-sm line-clamp-2 hover:text-primary transition-colors"
          >
            {article.title}
          </a>
          <p class="glass-muted text-xs truncate">{article_meta(article)}</p>
        </div>
      </li>
    </ul>
    """
  end

  defp widget_content(%{data: {:error, reason}} = assigns) do
    assigns = assign(assigns, :reason, if(is_binary(reason), do: reason, else: inspect(reason)))

    ~H"""
    <p class="text-sm text-error flex gap-2 items-center">
      <.icon name="hero-exclamation-circle" class="size-4 shrink-0" /> {gettext("Error:")} {@reason}
    </p>
    """
  end

  defp widget_content(assigns) do
    ~H"""
    <p class="glass-muted text-sm animate-pulse">{gettext("Loading...")}</p>
    """
  end
end
