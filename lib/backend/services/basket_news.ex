#
## EPITECH PROJECT, 2026
## basket_news.ex
## File description:
## GNews client - fetches the news of a basketball league for the "basket" service
#

defmodule Dashboard.Services.BasketNews do
  @moduledoc """
  News of the basketball leagues, backed by the GNews search API.

  The API key is read from the `BASKET_NEWS_API` environment variable. Extra `Req`
  options (e.g. `plug:` to stub the HTTP layer in tests) can be set with
  `config :dashboard, :basket_news_req_options, [...]`.

  Every league has its own search query, and the articles returned are filtered
  again on the league name, so a widget only shows news about its league.
  """

  use Gettext, backend: DashboardWeb.Gettext

  @base_url "https://gnews.io/api/v4/search"
  @max_articles 8
  @cache_ttl :timer.minutes(10)

  @leagues %{
    "nba" => %{query: ~s("NBA"), terms: ["nba"], lang: "en"},
    "wnba" => %{query: ~s("WNBA"), terms: ["wnba"], lang: "en"},
    "euroleague" => %{
      query: ~s("EuroLeague" AND basketball),
      terms: ["euroleague", "euro league"],
      lang: "en"
    },
    "lnb-pro-a" => %{
      query: ~s("Betclic Élite" OR "Betclic Elite" OR "LNB Pro A"),
      terms: ["betclic élite", "betclic elite", "lnb pro a", "lnb"],
      lang: "fr"
    },
    "acb" => %{
      query: ~s("Liga Endesa" OR "Liga ACB"),
      terms: ["liga endesa", "liga acb"],
      lang: "es"
    }
  }

  @spec fetch(String.t()) :: {:ok, map()} | {:error, String.t()}
  def fetch(league) do
    with {:ok, config} <- resolve_league(league),
         {:ok, api_key} <- api_key() do
      Dashboard.Cache.fetch({:basket_news, league}, @cache_ttl, fn ->
        load(league, config, api_key)
      end)
    end
  end

  defp resolve_league(league) do
    case Map.fetch(@leagues, league) do
      {:ok, config} -> {:ok, config}
      :error -> {:error, gettext("Unknown league: %{league}", league: league)}
    end
  end

  defp api_key do
    case System.get_env("BASKET_NEWS_API") do
      key when key in [nil, ""] ->
        {:error,
         gettext("%{variable} environment variable is not set", variable: "BASKET_NEWS_API")}

      key ->
        {:ok, key}
    end
  end

  defp load(league, config, api_key) do
    case get(config, api_key) do
      {:ok, %{status: 200, body: %{"articles" => articles}}} when is_list(articles) ->
        articles
        |> Enum.flat_map(&article(&1, config.terms))
        |> Enum.uniq_by(& &1.title)
        |> Enum.take(@max_articles)
        |> case do
          [] -> {:error, gettext("No recent news found for this league.")}
          articles -> {:ok, %{league: league, articles: articles}}
        end

      {:ok, %{status: 401}} ->
        {:error, gettext("Invalid news API key.")}

      {:ok, %{status: 403}} ->
        {:error, gettext("Daily news API quota reached, try again tomorrow.")}

      {:ok, %{status: 429}} ->
        {:error, gettext("Too many news requests, try again in a moment.")}

      {:ok, %{status: status}} ->
        {:error, gettext("News API returned HTTP %{status}", status: status)}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp get(config, api_key) do
    options =
      [
        url: @base_url,
        params: [
          q: config.query,
          lang: config.lang,
          max: 10,
          sortby: "publishedAt",
          apikey: api_key
        ]
      ] ++ Application.get_env(:dashboard, :basket_news_req_options, [])

    Req.get(options)
  end

  defp article(%{"title" => title, "url" => url} = article, terms)
       when is_binary(title) and is_binary(url) do
    text = title <> " " <> (article["description"] || "")

    if web_url?(url) and about_league?(text, terms) do
      [
        %{
          title: title,
          url: url,
          image: article["image"] |> web_url(),
          source: get_in(article, ["source", "name"]),
          published_at: parse_date(article["publishedAt"])
        }
      ]
    else
      []
    end
  end

  defp article(_article, _terms), do: []

  defp about_league?(text, terms) do
    text = String.downcase(text)

    Enum.any?(terms, fn term ->
      Regex.match?(~r/(?<![\p{L}\p{N}])#{Regex.escape(term)}(?![\p{L}\p{N}])/u, text)
    end)
  end

  defp web_url?(url), do: String.starts_with?(url, ["https://", "http://"])

  defp web_url(url) when is_binary(url), do: if(web_url?(url), do: url)
  defp web_url(_url), do: nil

  defp parse_date(date) when is_binary(date) do
    case DateTime.from_iso8601(date) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_date(_date), do: nil
end
