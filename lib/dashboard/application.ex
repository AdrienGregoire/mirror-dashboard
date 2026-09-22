#
## EPITECH PROJECT, 2026
## application.ex
## File description:
## Application entry point and supervision tree specification
#

defmodule Dashboard.Application do
  use Application
  @impl true
  def start(_type, _args) do
    children =
      [
        DashboardWeb.Telemetry,
        Dashboard.Repo,
        {DNSCluster, query: Application.get_env(:dashboard, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Dashboard.PubSub}
      ] ++
        mailer_children() ++
        [
          DashboardWeb.Endpoint
        ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp mailer_children do
    case Application.get_env(:dashboard, Dashboard.Mailer)[:adapter] do
      Swoosh.Adapters.Local -> [Dashboard.SwooshLocalStorage]
      _ -> []
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    DashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
