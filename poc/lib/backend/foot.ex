#
## EPITECH PROJECT, 2026
## foot.ex
## File description:
## Module for fetching football data from API-Football
#

defmodule Poc.Foot do
  @base_url "https://v3.football.api-sports.io"

  def fetch_team(id) do
    api_key = System.get_env("FOOT_API")

    if is_nil(api_key) or api_key == "" do
      {:error, :missing_api_key}
    else
      req_options = Application.get_env(:poc, :foot_req_options, [])

      req =
        Req.new(
          base_url: @base_url,
          headers: [{"x-apisports-key", api_key}]
        )
        |> Req.merge(req_options)

      case Req.get(req, url: "/teams", params: [id: id]) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          parse_response(body)

        {:ok, %Req.Response{status: status}} ->
          {:error, "HTTP #{status}"}

        {:error, exception} ->
          {:error, Exception.message(exception)}
      end
    end
  end

  defp parse_response(%{"errors" => errors}) when map_size(errors) > 0 do
    {:error, errors}
  end

  defp parse_response(%{"response" => []}) do
    {:error, :not_found}
  end

  defp parse_response(%{"response" => [%{"team" => %{"name" => name, "logo" => logo}} | _]}) do
    {:ok, %{name: name, logo: logo}}
  end

  defp parse_response(_other) do
    {:error, :unexpected_response}
  end
end
