defmodule Poc.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Poc.UserStore.init()
    children = [
      PocWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:poc, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Poc.PubSub},
      # Start a worker by calling: Poc.Worker.start_link(arg)
      # {Poc.Worker, arg},
      # Start to serve requests, typically the last entry
      PocWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Poc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PocWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
