#
## EPITECH PROJECT, 2026
## dashboard_live.ex
## File description:
## The dashboard grid: widgets filtered by service
#

defmodule DashboardWeb.DashboardLive do
  use DashboardWeb, :live_view

  alias Dashboard.Widgets

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    widgets = Widgets.list_widgets(user)

    {:ok,
     assign(socket,
       widgets: widgets,
       services: user.preferred_services,
       active_service: List.first(user.preferred_services),
       adding_widget: false
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

  def handle_info({DashboardWeb.AddWidgetComponent, {:added, _widget}}, socket) do
    {:noreply,
     socket
     |> assign(widgets: Widgets.list_widgets(socket.assigns.current_user), adding_widget: false)
     |> put_flash(:info, "Widget ajouté !")}
  end

  defp widgets_for(widgets, service), do: Enum.filter(widgets, &(&1.service == service))

  def render(assigns) do
    ~H"""
    <div class="relative min-h-screen overflow-hidden bg-(color:--glass-bg-page)">
      <div class="glass-blob top-10 -left-10 bg-(color:--glass-blob-1)"></div>
      <div class="glass-blob top-20 -right-10 bg-(color:--glass-blob-2)"></div>
      <div class="glass-blob -bottom-10 left-1/3 bg-(color:--glass-blob-3)"></div>

      <div class="relative z-10 max-w-6xl mx-auto p-4 sm:p-8 space-y-8">
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
            class="glass-card p-6 cursor-grab active:cursor-grabbing space-y-2"
          >
            <p class="glass-title text-lg capitalize">{widget.widget}</p>
            <p class="glass-muted text-sm">{inspect(widget.config)}</p>
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
end
