#
## EPITECH PROJECT, 2026
## provider_test.exs
## File description:
## ExUnit for Dashboard.Services.Provider
#

defmodule Dashboard.Services.ProviderTest do
  use ExUnit.Case, async: true

  alias Dashboard.Services.{Provider, Service, WidgetType}

  defmodule FakeProvider do
    @behaviour Dashboard.Services.Provider

    @impl true
    def fetch("echo", config, credentials), do: {:ok, %{config: config, credentials: credentials}}
    def fetch("broken", _config, _credentials), do: {:error, :api_down}
  end

  defp service(provider) do
    %Service{
      name: "fake",
      description: "Fake service",
      auth: :none,
      provider: provider,
      widgets: [
        %WidgetType{name: "echo", description: "Echo", params: [%{name: "q", type: "string"}]},
        %WidgetType{name: "broken", description: "Broken", params: []}
      ]
    }
  end

  test "dispatches to the provider of the service" do
    assert Provider.fetch(service(FakeProvider), "echo", %{"q" => "psg"}, %{"token" => "t"}) ==
             {:ok, %{config: %{"q" => "psg"}, credentials: %{"token" => "t"}}}
  end

  test "returns the provider error as is" do
    assert Provider.fetch(service(FakeProvider), "broken", %{}, %{}) == {:error, :api_down}
  end

  test "rejects a widget the service does not declare" do
    assert Provider.fetch(service(FakeProvider), "unknown", %{}, %{}) ==
             {:error, :unknown_widget}
  end

  test "a service not plugged yet is not implemented" do
    assert Provider.fetch(service(nil), "echo", %{}, %{}) == {:error, :not_implemented}
  end
end
