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

  # `split_season: true` leagues are played over two years ("2024-2025"),
  # the others over a single one ("2024").
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

  def fetch(_widget, _config, _credentials), do: {:error, :unknown_widget}

  defp api_key do
    case System.get_env("BASKET_API") do
      key when key in [nil, ""] -> {:error, "BASKET_API environment variable is not set"}
      key -> {:ok, key}
    end
  end

  # Known slugs, or a raw API-Sports league id typed by the user.
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

  # The API answers `[[team, ...]]`. Leagues split in conferences / divisions
  # (NBA) list every team once per group: we keep one entry per team and rank
  # them over the whole league.
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
