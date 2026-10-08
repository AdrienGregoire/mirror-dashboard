#
## EPITECH PROJECT, 2026
## tennis.ex
## File description:
## Sportradar Tennis provider - fetches tennis data for the "tennis" service
#

defmodule Dashboard.Services.Tennis do
  @moduledoc """
  Tennis provider backed by the Sportradar Tennis API (trial, v3).

  The API key is read from the `TENNIS_API` environment variable. Extra `Req`
  options (used by the tests to plug a stub) come from the `:tennis_req_options`
  application env.
  """

  @behaviour Dashboard.Services.Provider

  @base_url "https://api.sportradar.com/tennis/trial/v3/en"
  @max_players 10
  @days_ahead 6
  @schedule_ttl :timer.minutes(2)
  @upcoming_statuses ["not_started", "live", "delayed", "interrupted", "suspended"]

  @impl true
  def fetch("player_ranking", %{"circuit" => circuit}, _credentials) do
    case get("/rankings.json") do
      {:ok, %{status: 200, body: %{"rankings" => rankings}}} when is_list(rankings) ->
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

      other ->
        http_error(other)
    end
  end

  def fetch("next_match", %{"player" => player}, _credentials) do
    case query_tokens(player) do
      [] -> {:error, "Nom de joueur invalide."}
      tokens -> find_next_match(tokens, player, Date.utc_today(), 0)
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

  defp find_next_match(_tokens, player, _date, offset) when offset > @days_ahead do
    {:error,
     "Aucun match à venir trouvé pour #{player} dans les #{@days_ahead + 1} prochains jours."}
  end

  defp find_next_match(tokens, player, date, offset) do
    day = Date.add(date, offset)

    case day_summaries(day) do
      {:ok, summaries} ->
        case best_match(summaries, tokens) do
          nil -> find_next_match(tokens, player, date, offset + 1)
          match -> {:ok, match}
        end

      {:error, response} ->
        http_error(response)
    end
  end

  # A day of the schedule weighs a few hundred KB and the trial plan is limited to
  # one request per second: every player of the day is searched in the same cached copy.
  defp day_summaries(day) do
    Dashboard.Cache.fetch({:tennis_day, day}, @schedule_ttl, fn ->
      case get("/schedules/#{Date.to_iso8601(day)}/summaries.json") do
        {:ok, %{status: 200, body: %{"summaries" => summaries}}} when is_list(summaries) ->
          {:ok, summaries}

        other ->
          {:error, other}
      end
    end)
  end

  defp best_match(summaries, tokens) do
    summaries
    |> Enum.flat_map(&candidate(&1, tokens))
    |> Enum.sort_by(fn {score, match} -> {-score, match.start_time || ""} end)
    |> case do
      [{_score, match} | _] -> match
      [] -> nil
    end
  end

  defp candidate(%{"sport_event" => event, "sport_event_status" => status}, tokens) do
    competitors = event["competitors"] || []

    with true <- status["status"] in @upcoming_statuses,
         [_, _] <- competitors,
         false <- Enum.any?(competitors, &Map.has_key?(&1, "players")),
         {score, player, opponent} when score > 0 <- pick_player(competitors, tokens) do
      [{score, build_match(event, status, player, opponent)}]
    else
      _ -> []
    end
  end

  defp candidate(_summary, _tokens), do: []

  defp pick_player([first, second], tokens) do
    case {match_score(first, tokens), match_score(second, tokens)} do
      {0, 0} -> nil
      {a, b} when a >= b -> {a, first, second}
      {_, b} -> {b, second, first}
    end
  end

  defp match_score(%{"name" => name}, tokens) when is_binary(name) do
    name_tokens = name_tokens(name)

    if Enum.all?(tokens, fn t -> Enum.any?(name_tokens, &String.starts_with?(&1, t)) end) do
      Enum.count(tokens, &(&1 in name_tokens)) + 1
    else
      0
    end
  end

  defp match_score(_competitor, _tokens), do: 0

  defp build_match(event, status, player, opponent) do
    context = event["sport_event_context"] || %{}
    venue = event["venue"] || %{}

    %{
      player: display_name(player["name"]),
      player_country: player["country"],
      opponent: display_name(opponent["name"]),
      opponent_country: opponent["country"],
      start_time: event["start_time"],
      time_confirmed: event["start_time_confirmed"] == true,
      live: status["status"] == "live",
      competition: get_in(context, ["competition", "name"]),
      round: round_label(context["round"]),
      venue: venue["name"],
      city: venue["city_name"]
    }
  end

  defp round_label(%{"name" => name}) when is_binary(name) do
    name |> String.replace("_", " ") |> String.capitalize()
  end

  defp round_label(%{"number" => number}) when is_integer(number), do: "Tour #{number}"
  defp round_label(_round), do: nil

  defp display_name(name) when is_binary(name) do
    case String.split(name, ",", parts: 2) do
      [last, first] -> String.trim(first) <> " " <> String.trim(last)
      _ -> name
    end
  end

  defp display_name(_name), do: nil

  defp query_tokens(player) when is_binary(player) do
    player |> name_tokens() |> Enum.filter(&(String.length(&1) >= 2))
  end

  defp query_tokens(_player), do: []

  defp name_tokens(name) do
    name
    |> String.downcase()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.split(" ", trim: true)
  end

  defp http_error({:ok, %{status: 403}}),
    do: {:error, "Clé API Sportradar invalide ou non autorisée (403 Forbidden)."}

  defp http_error({:ok, %{status: 404}}),
    do: {:error, "Endpoint Sportradar introuvable (404 Not Found)."}

  defp http_error({:ok, %{status: 429}}),
    do: {:error, "Quota Sportradar dépassé, réessaie dans un instant (429)."}

  defp http_error({:ok, %{status: status}}), do: {:error, "API returned HTTP #{status}"}
  defp http_error({:error, reason}) when is_binary(reason), do: {:error, reason}
  defp http_error({:error, reason}), do: {:error, inspect(reason)}

  defp get(path) do
    case System.get_env("TENNIS_API") do
      key when key in [nil, ""] ->
        {:error, "TENNIS_API environment variable is not set"}

      key ->
        options = Application.get_env(:dashboard, :tennis_req_options, [])

        [url: @base_url <> path, headers: [{"x-api-key", key}]]
        |> Keyword.merge(options)
        |> Req.request()
    end
  end
end
