#
## EPITECH PROJECT, 2026
## foot.ex
## File description:
## API-Football provider — fetches football data for the "foot" service
#

defmodule Dashboard.Services.Foot do
  @behaviour Dashboard.Services.Provider

  @base_url "https://v3.football.api-sports.io"
  @max_scorers 10

  @leagues %{
    "premier-league" => 39,
    "ligue-1" => 61,
    "liga" => 140,
    "bundesliga" => 78,
    "serie-a" => 135
  }

  def leagues, do: @leagues

  @impl true
  def fetch("standings", %{"league" => league, "season" => season}, _credentials) do
    api_key = System.get_env("FOOT_API") || raise "FOOT_API environment variable is not set"
    league_id = Map.get(@leagues, league, league)
    url = "#{@base_url}/standings?league=#{league_id}&season=#{season}"

    case Req.get(url, headers: [{"x-apisports-key", api_key}]) do
      {:ok, %{status: 200, body: %{"response" => [response | _]}}} ->
        rows =
          response
          |> get_in(["league", "standings"])
          |> List.first()
          |> Enum.map(fn team ->
            %{
              position: team["rank"],
              name: get_in(team, ["team", "name"]),
              played: get_in(team, ["all", "played"]),
              wins: get_in(team, ["all", "win"]),
              draws: get_in(team, ["all", "draw"]),
              losses: get_in(team, ["all", "lose"]),
              goals_for: get_in(team, ["all", "goals", "for"]),
              goals_against: get_in(team, ["all", "goals", "against"]),
              points: team["points"]
            }
          end)

        {:ok, %{league: league, season: season, rows: rows}}

      {:ok, %{status: 200, body: %{"response" => []}}} ->
        {:error, "Le classement pour la saison #{season} n'est pas encore disponible sur l'API."}

      {:ok, %{status: status}} ->
        {:error, "API returned HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch("top_scorers", %{"league" => league, "season" => season}, _credentials) do
    league_id = Map.get(@leagues, league, league)

    case get("/players/topscorers", league: league_id, season: season) do
      {:ok, %{status: 200, body: %{"errors" => errors}}}
      when is_map(errors) and map_size(errors) > 0 ->
        {:error, errors |> Map.values() |> Enum.map_join(" ", &to_string/1)}

      {:ok, %{status: 200, body: %{"response" => [_ | _] = players}}} ->
        {:ok, %{league: league, season: season, rows: parse_top_scorers(players)}}

      {:ok, %{status: 200, body: %{"response" => []}}} ->
        {:error, "Les buteurs de la saison #{season} ne sont pas encore disponibles sur l'API."}

      {:ok, %{status: status}} ->
        {:error, "API returned HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch(_widget, _config, _credentials), do: {:error, :unknown_widget}

  def parse_top_scorers(players) do
    players
    |> Enum.take(@max_scorers)
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, rank} ->
      stats = entry |> Map.get("statistics", []) |> List.first(%{})

      %{
        position: rank,
        name: get_in(entry, ["player", "name"]),
        team: get_in(stats, ["team", "name"]),
        played: get_in(stats, ["games", "appearences"]),
        goals: get_in(stats, ["goals", "total"]),
        assists: get_in(stats, ["goals", "assists"])
      }
    end)
  end

  defp get(path, params) do
    api_key = System.get_env("FOOT_API") || raise "FOOT_API environment variable is not set"

    Req.get(
      @base_url <> path,
      [params: params, headers: [{"x-apisports-key", api_key}]] ++ req_options()
    )
  end

  defp req_options, do: Application.get_env(:dashboard, :foot_req_options, [])
end
