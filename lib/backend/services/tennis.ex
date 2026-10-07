#
## EPITECH PROJECT, 2026
## tennis.ex
## File description:
## API-Tennis provider - fetches tennis data for the "tennis" service
#

defmodule Dashboard.Services.Tennis do
  @behaviour Dashboard.Services.Provider

  @base_url "https://api.sportradar.com/tennis/trial/v3/en"
  @max_players 10

  @impl true
  def fetch("player_ranking", %{"circuit" => circuit}, _credentials) do
    case get("/rankings.json") do
      {:ok, %{status: 200, body: %{"rankings" => rankings}} = _response} when is_list(rankings) ->
        circuit_data =
          Enum.find(rankings, fn r ->
            String.downcase(r["name"]) == String.downcase(circuit)
          end)

        if circuit_data do
          rows = parse_rankings(circuit_data["competitor_rankings"] || [])
          {:ok, %{circuit: circuit, rows: rows}}
        else
          {:error, "Le classement pour le circuit #{circuit} n'est pas disponible."}
        end

      {:ok, %{status: 403}} ->
        {:error, "Clé API Sportradar invalide ou non autorisée (403 Forbidden)."}

      {:ok, %{status: 404}} ->
        {:error, "Endpoint Sportradar introuvable (404 Not Found)."}

      {:ok, %{status: status}} ->
        {:error, "API returned HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  def fetch(_widget, _config, _credentials), do: {:error, :unknown_widget}

  def parse_rankings(competitor_rankings) do
    competitor_rankings
    |> Enum.take(@max_players)
    |> Enum.map(fn entry ->
      movement_val = entry["movement"] || 0

      movement_str =
        cond do
          movement_val > 0 -> "up"
          movement_val < 0 -> "down"
          true -> "same"
        end

      %{
        position: entry["rank"],
        name: get_in(entry, ["competitor", "name"]),
        points: entry["points"],
        movement: movement_str
      }
    end)
  end

  defp get(path) do
    api_key =
      System.get_env("TENNIS_API") ||
        raise "TENNIS_API environment variable is not set"

    Req.get(
      @base_url <> path,
      params: [api_key: api_key]
    )
  end
end
