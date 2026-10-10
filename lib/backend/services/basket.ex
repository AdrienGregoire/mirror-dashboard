#
## EPITECH PROJECT, 2026
## basket.ex
## File description:
## API-Basketball provider — fetches basketball data for the "basket" service
#

defmodule Dashboard.Services.Basket do
  @moduledoc """
  Provider of the "basket" service, backed by API-Sports (API-Basketball).

  The API key is read from the `BASKET_API` environment variable. Extra `Req`
  options (e.g. `plug:` to stub the HTTP layer in tests) can be set with
  `config :dashboard, :basket_req_options, [...]`.
  """

  @behaviour Dashboard.Services.Provider

  @base_url "https://v1.basketball.api-sports.io"

  @leagues %{
    "nba" => %{id: 12, split_season: true},
    "wnba" => %{id: 13, split_season: false},
    "euroleague" => %{id: 120, split_season: true},
    "lnb-pro-a" => %{id: 2, split_season: true},
    "acb" => %{id: 117, split_season: true}
  }

  def leagues, do: @leagues

  @impl true
  def fetch("standings", %{"league" => league, "season" => season}, _credentials) do
    with {:ok, api_key} <- api_key(),
         {:ok, %{id: id, split_season: split?}} <- resolve_league(league),
         {:ok, response} <-
           get("/standings", api_key, league: id, season: season_param(season, split?)) do
      {:ok, %{league: league, season: season, rows: rows(response)}}
    else
      {:error, :empty} ->
        {:error, "Le classement pour la saison #{season} n'est pas encore disponible sur l'API."}

      {:error, _reason} = error ->
        error
    end
  end

  def fetch("stats", %{"league" => league, "season" => season, "team" => team}, _credentials) do
    with {:ok, api_key} <- api_key(),
         {:ok, %{id: id, split_season: split?}} <- resolve_league(league),
         api_season = season_param(season, split?),
         {:ok, response} <-
           get("/statistics", api_key, league: id, season: api_season, team: team) do
      {:ok, stats(response, api_season)}
    else
      {:error, :empty} ->
        {:error, "Les statistiques de cette équipe ne sont pas disponibles sur l'API."}

      {:error, _reason} = error ->
        error
    end
  end

  def fetch("news", %{"league" => league}, _credentials),
    do: Dashboard.Services.BasketNews.fetch(league)

  def fetch(_widget, _config, _credentials), do: {:error, :unknown_widget}

  @doc """
  Teams of a league for a season, as `{name, id}` options sorted by name.

  Feeds the team select of the `stats` widget. `config` holds the raw values
  of the `"league"` and `"season"` params, as typed in the form.
  """
  @spec team_options(%{optional(String.t()) => String.t() | integer()}) ::
          {:ok, [{String.t(), String.t()}]} | {:error, String.t()}
  def team_options(%{"league" => league, "season" => season}) do
    with {:ok, season} <- parse_season(season),
         {:ok, api_key} <- api_key(),
         {:ok, %{id: id, split_season: split?}} <- resolve_league(league),
         {:ok, teams} <- get("/teams", api_key, league: id, season: season_param(season, split?)) do
      options =
        teams
        |> Enum.uniq_by(& &1["id"])
        |> Enum.sort_by(&String.downcase(&1["name"] || ""))
        |> Enum.map(&{&1["name"], to_string(&1["id"])})

      {:ok, options}
    else
      {:error, :empty} -> {:error, "Aucune équipe trouvée pour cette saison."}
      {:error, _reason} = error -> error
    end
  end

  def team_options(_config), do: {:error, "Choisis un championnat et une saison."}

  defp parse_season(season) when is_integer(season), do: check_season(season)

  defp parse_season(season) when is_binary(season) do
    case Integer.parse(String.trim(season)) do
      {season, ""} -> check_season(season)
      _ -> {:error, "Saison invalide."}
    end
  end

  defp parse_season(_season), do: {:error, "Saison invalide."}

  defp check_season(season) when season in 1990..2100, do: {:ok, season}
  defp check_season(_season), do: {:error, "Saison invalide."}

  defp api_key do
    case System.get_env("BASKET_API") do
      key when key in [nil, ""] -> {:error, "BASKET_API environment variable is not set"}
      key -> {:ok, key}
    end
  end

  defp resolve_league(league) do
    case Map.fetch(@leagues, league) do
      {:ok, info} ->
        {:ok, info}

      :error ->
        case Integer.parse(league) do
          {id, ""} -> {:ok, %{id: id, split_season: true}}
          _ -> {:error, "Championnat inconnu : #{league}"}
        end
    end
  end

  defp stats(response, season) do
    wins = get_in(response, ["games", "wins", "all", "total"]) || 0
    losses = get_in(response, ["games", "loses", "all", "total"]) || 0
    played = get_in(response, ["games", "played", "all"]) || wins + losses

    %{
      team: get_in(response, ["team", "name"]),
      logo: get_in(response, ["team", "logo"]),
      league: get_in(response, ["league", "name"]),
      season: season,
      played: played,
      wins: wins,
      losses: losses,
      win_pct: if(played > 0, do: wins / played, else: 0.0),
      points_for_avg: to_float(get_in(response, ["points", "for", "average", "all"])),
      points_against_avg: to_float(get_in(response, ["points", "against", "average", "all"])),
      home_wins: get_in(response, ["games", "wins", "home", "total"]) || 0,
      home_losses: get_in(response, ["games", "loses", "home", "total"]) || 0,
      away_wins: get_in(response, ["games", "wins", "away", "total"]) || 0,
      away_losses: get_in(response, ["games", "loses", "away", "total"]) || 0
    }
  end

  defp to_float(value) when is_number(value), do: value * 1.0

  defp to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rest} -> float
      :error -> nil
    end
  end

  defp to_float(_value), do: nil

  defp season_param(season, true), do: "#{season}-#{season + 1}"
  defp season_param(season, false), do: "#{season}"

  defp get(path, api_key, params) do
    options =
      [url: @base_url <> path, params: params, headers: [{"x-apisports-key", api_key}]] ++
        Application.get_env(:dashboard, :basket_req_options, [])

    case Req.get(options) do
      {:ok, %{status: 200, body: %{"errors" => errors}}} when is_map(errors) and errors != %{} ->
        {:error, errors |> Map.values() |> Enum.join(", ")}

      {:ok, %{status: 200, body: %{"response" => []}}} ->
        {:error, :empty}

      {:ok, %{status: 200, body: %{"response" => response}}} ->
        {:ok, response}

      {:ok, %{status: status}} ->
        {:error, "API returned HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp rows(response) do
    entries = List.flatten(response)

    groups = entries |> Enum.map(&get_in(&1, ["group", "name"])) |> Enum.uniq()

    entries
    |> Enum.uniq_by(&get_in(&1, ["team", "id"]))
    |> Enum.map(&to_row/1)
    |> rank(length(groups) > 1)
  end

  defp to_row(entry) do
    played = get_in(entry, ["games", "played"]) || 0
    wins = get_in(entry, ["games", "win", "total"]) || 0

    %{
      position: entry["position"],
      name: get_in(entry, ["team", "name"]),
      logo: get_in(entry, ["team", "logo"]),
      played: played,
      wins: wins,
      losses: get_in(entry, ["games", "lose", "total"]) || 0,
      win_pct: if(played > 0, do: wins / played, else: 0.0),
      points_for: get_in(entry, ["points", "for"]),
      points_against: get_in(entry, ["points", "against"])
    }
  end

  defp rank(rows, false), do: Enum.sort_by(rows, & &1.position)

  defp rank(rows, true) do
    rows
    |> Enum.sort_by(&{-&1.win_pct, -&1.wins})
    |> Enum.with_index(1)
    |> Enum.map(fn {row, position} -> %{row | position: position} end)
  end
end
