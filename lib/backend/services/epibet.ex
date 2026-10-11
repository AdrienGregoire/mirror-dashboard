#
## EPITECH PROJECT, 2026
## epibet.ex
## File description:
## Odds API provider fetches bet data for the "epibet" service
#

defmodule Dashboard.Services.EpiBet do
  @behaviour Dashboard.Services.Provider
  use Gettext, backend: DashboardWeb.Gettext

  @base_url "https://api.the-odds-api.com/v4/sports"

  @impl true
  def fetch("next_match_odds", %{"sport" => sport, "team" => team}, _credentials) do
    with {:ok, api_key} <- api_key(),
         {:ok, events} <- get_odds(sport, api_key) do
      case parse_next_match(events, team) do
        {:ok, match} ->
          {:ok, %{match: match}}

        {:error, :not_found} ->
          {:error, gettext("No upcoming match found for %{team}.", team: team)}
      end
    end
  end

  def fetch(_widget, _config, _credentials), do: {:error, gettext("Unknown widget.")}

  def team_options(%{"sport" => sport}) do
    with {:ok, api_key} <- api_key(),
         {:ok, events} <- get_odds(sport, api_key) do
      teams =
        events
        |> Enum.flat_map(fn e -> [e["home_team"], e["away_team"]] end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.map(&{&1, &1})

      if teams == [] do
        {:error, gettext("No teams found for this sport.")}
      else
        {:ok, teams}
      end
    end
  end

  def team_options(_config), do: {:error, gettext("Please select a sport first.")}

  defp api_key do
    case System.get_env("ODDS_API_KEY") do
      key when key in [nil, ""] ->
        {:error, gettext("ODDS_API_KEY environment variable is not set.")}

      key ->
        {:ok, key}
    end
  end

  defp get_odds(sport, api_key) do
    url = "#{@base_url}/#{sport}/odds"

    params = [
      apiKey: api_key,
      regions: "eu",
      markets: "h2h"
    ]

    case Req.get(url: url, params: params) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, gettext("API returned HTTP %{status}", status: status)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp parse_next_match(events, team) do
    match =
      Enum.find(events, fn e ->
        e["home_team"] == team or e["away_team"] == team
      end)

    case match do
      nil ->
        {:error, :not_found}

      e ->
        bookmakers = e["bookmakers"] || []

        bookmaker =
          Enum.find(bookmakers, &(&1["key"] == "betclic")) ||
            Enum.find(bookmakers, &(&1["key"] == "unibet_eu")) ||
            List.first(bookmakers)

        h2h_market = Enum.find(get_in(bookmaker, ["markets"]) || [], &(&1["key"] == "h2h"))
        outcomes = if h2h_market, do: h2h_market["outcomes"] || [], else: []

        home_outcome =
          Enum.find(outcomes, &(&1["name"] == e["home_team"])) ||
            Enum.at(outcomes, 0)

        away_outcome =
          Enum.find(outcomes, &(&1["name"] == e["away_team"])) ||
            Enum.at(outcomes, -1)

        draw_outcome = Enum.find(outcomes, &(&1["name"] == "Draw"))

        {:ok,
         %{
           home_team: e["home_team"],
           away_team: e["away_team"],
           commence_time: e["commence_time"],
           odds: %{
             home: if(home_outcome, do: home_outcome["price"], else: "-"),
             draw: if(draw_outcome, do: draw_outcome["price"], else: nil),
             away: if(away_outcome, do: away_outcome["price"], else: "-")
           }
         }}
    end
  end
end
