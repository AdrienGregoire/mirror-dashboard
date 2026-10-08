#
## EPITECH PROJECT, 2026
## provider.ex
## File description:
## Behaviour every service implements to fetch the data of its widgets
#

defmodule Dashboard.Services.Provider do
  @moduledoc """
  Contract a service module implements to feed its widgets with data.

  Plugging a new service is done in two steps:

    1. write a module with `@behaviour Dashboard.Services.Provider`
    2. set it as the `provider` of the service in `Dashboard.Services.Registry`

  Example:

      defmodule Dashboard.Services.Foot do
        @behaviour Dashboard.Services.Provider

        @impl true
        def fetch("standings", %{"league" => league}, _credentials) do
          {:ok, %{league: league, rows: []}}
        end

        def fetch(_widget, _config, _credentials), do: {:error, :unknown_widget}
      end

  `fetch/3` receives the widget type name, the config already validated
  against the widget params (string keys, typed values) and the decrypted
  credentials of the user (`%{}` for services with `auth: :none`).
  """

  alias Dashboard.Services.Service

  # Successful results are reused for a few seconds: reloading the page, switching
  # tabs or several users sharing the same widget do not hit the external API again.
  @cache_ttl :timer.seconds(30)

  @type widget :: String.t()
  @type config :: %{optional(String.t()) => String.t() | integer()}
  @type credentials :: map()
  @type data :: term()

  @callback fetch(widget(), config(), credentials()) :: {:ok, data()} | {:error, term()}

  @doc """
  Dispatches `fetch/3` to the provider of the service. Successful results are
  cached for a short time (see `Dashboard.Cache`).
  """
  @spec fetch(Service.t(), widget(), config(), credentials()) :: {:ok, data()} | {:error, term()}
  def fetch(%Service{provider: nil}, _widget, _config, _credentials),
    do: {:error, :not_implemented}

  def fetch(%Service{provider: provider} = service, widget, config, credentials) do
    if Service.get_widget(service, widget) do
      key = {service.name, widget, config, :erlang.phash2(credentials)}

      Dashboard.Cache.fetch(key, @cache_ttl, fn ->
        provider.fetch(widget, config, credentials)
      end)
    else
      {:error, :unknown_widget}
    end
  end
end
