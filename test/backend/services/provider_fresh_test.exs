#
## EPITECH PROJECT, 2026
## provider_fresh_test.exs
## File description:
## ExUnit for the `fresh: true` option of Dashboard.Services.Provider (manual refresh)
#

defmodule Dashboard.Services.ProviderFreshTest do
  use ExUnit.Case, async: false

  alias Dashboard.Cache
  alias Dashboard.Services.{Provider, Service, WidgetType}

  defmodule CountingProvider do
    @behaviour Dashboard.Services.Provider

    @impl true
    def fetch("count", _config, _credentials) do
      send(self(), :fetched)
      {:ok, :data}
    end
  end

  @service %Service{
    name: "counting",
    description: "Counting service",
    auth: :none,
    provider: CountingProvider,
    widgets: [%WidgetType{name: "count", description: "Count", params: []}]
  }

  setup do
    Application.put_env(:dashboard, Cache, enabled: true)
    Cache.clear()

    on_exit(fn ->
      Application.put_env(:dashboard, Cache, enabled: false)
      Cache.clear()
    end)
  end

  test "a regular fetch is served from the cache" do
    assert {:ok, :data} = Provider.fetch(@service, "count", %{}, %{})
    assert {:ok, :data} = Provider.fetch(@service, "count", %{}, %{})

    assert_received :fetched
    refute_received :fetched
  end

  test "a fresh fetch skips the cache and stores the new result" do
    assert {:ok, :data} = Provider.fetch(@service, "count", %{}, %{})
    assert {:ok, :data} = Provider.fetch(@service, "count", %{}, %{}, fresh: true)
    assert {:ok, :data} = Provider.fetch(@service, "count", %{}, %{})

    assert_received :fetched
    assert_received :fetched
    refute_received :fetched
  end
end
