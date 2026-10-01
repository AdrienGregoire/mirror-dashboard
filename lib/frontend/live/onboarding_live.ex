#
## EPITECH PROJECT, 2026
## onboarding_live.ex
## File description:
## First connection screen: pick the sports you want to follow
#

defmodule DashboardWeb.OnboardingLive do
  use DashboardWeb, :live_view

  alias Dashboard.{Accounts, Services}

  def mount(_params, _session, socket) do
    services = Services.list_services()
    selected = MapSet.new(socket.assigns.current_user.preferred_services)

    {:ok, assign(socket, services: services, selected: selected)}
  end

  def handle_event("toggle", %{"service" => name}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected, name) do
        MapSet.delete(socket.assigns.selected, name)
      else
        MapSet.put(socket.assigns.selected, name)
      end

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("save", _params, socket) do
    names = MapSet.to_list(socket.assigns.selected)

    case Accounts.set_preferred_services(socket.assigns.current_user, names) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_user: user)
         |> put_flash(:info, "Services enregistrés !")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Choisis au moins un service valide.")}
    end
  end

  def render(assigns) do
    ~H"""
    <.glass_page flash={@flash} max_w="max-w-2xl">
      <div class="glass-card p-10 sm:p-12 space-y-8">
        <div class="text-center space-y-2">
          <h1 class="glass-title text-4xl">Choisis tes sports</h1>
          <p class="glass-muted">Tu pourras changer ça à tout moment depuis ton compte.</p>
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
          <button
            :for={service <- @services}
            type="button"
            phx-click="toggle"
            phx-value-service={service.name}
            class={[
              "glass-button flex-col h-24 text-base capitalize",
              MapSet.member?(@selected, service.name) && "ring-2 ring-primary"
            ]}
          >
            {service.name}
          </button>
        </div>

        <button
          type="button"
          phx-click="save"
          disabled={MapSet.size(@selected) == 0}
          class="glass-button w-full text-primary font-semibold text-lg py-3 disabled:opacity-40"
        >
          Continuer
        </button>
      </div>
    </.glass_page>
    """
  end
end
