#
## EPITECH PROJECT, 2026
## basket_test.exs
## File description:
## ExUnit for Dashboard.Services.Basket
#

defmodule Dashboard.Services.BasketTest do
  use ExUnit.Case, async: false

  alias Dashboard.Services.Basket

  setup do
    System.put_env("BASKET_API", "test-key")
    on_exit(fn -> System.delete_env("BASKET_API") end)
  end

  defp entry(position, id, name, group, wins, losses) do
    %{
      "position" => position,
      "group" => %{"name" => group},
      "team" => %{
        "id" => id,
        "name" => name,
        "logo" => "https://media.api-sports.io/basketball/teams/#{id}.png"
      },
      "games" => %{
        "played" => wins + losses,
        "win" => %{"total" => wins, "percentage" => "0.000"},
        "lose" => %{"total" => losses, "percentage" => "0.000"}
      },
      "points" => %{"for" => 100 * wins, "against" => 90 * wins}
    }
  end

  defp stub_response(response, test_pid \\ self()) do
    Req.Test.stub(Basket, fn conn ->
      send(test_pid, {:request, conn})
      Req.Test.json(conn, %{"errors" => [], "response" => response})
    end)
  end

  defp standings(league, season),
    do: Basket.fetch("standings", %{"league" => league, "season" => season}, %{})

  test "queries the NBA with a split season and the API key" do
    stub_response([[entry(1, 1, "Celtics", "Eastern Conference", 60, 22)]])

    assert {:ok, %{league: "nba", season: 2024, rows: [row]}} = standings("nba", 2024)

    assert_received {:request, conn}
    assert conn.request_path == "/standings"
    assert conn.params == %{"league" => "12", "season" => "2024-2025"}
    assert Plug.Conn.get_req_header(conn, "x-apisports-key") == ["test-key"]

    assert row.position == 1
    assert row.name == "Celtics"
    assert row.logo == "https://media.api-sports.io/basketball/teams/1.png"
    assert row.played == 82
    assert row.wins == 60
    assert row.losses == 22
    assert_in_delta row.win_pct, 60 / 82, 0.0001
    assert row.points_for == 6000
    assert row.points_against == 5400
  end

  test "WNBA seasons are a single year" do
    stub_response([[entry(1, 1, "Aces", "WNBA", 30, 10)]])

    assert {:ok, _} = standings("wnba", 2024)

    assert_received {:request, conn}
    assert conn.params == %{"league" => "13", "season" => "2024"}
  end

  test "accepts a raw API-Sports league id" do
    stub_response([[entry(1, 1, "Team", "Group", 1, 0)]])

    assert {:ok, _} = standings("120", 2024)

    assert_received {:request, conn}
    assert conn.params["league"] == "120"
  end

  test "rejects an unknown league without calling the API" do
    assert standings("curling", 2024) == {:error, "Championnat inconnu : curling"}
    refute_received {:request, _}
  end

  test "keeps the API order for a league with a single group" do
    stub_response([
      [
        entry(2, 2, "B", "Regular Season", 10, 10),
        entry(1, 1, "A", "Regular Season", 15, 5)
      ]
    ])

    assert {:ok, %{rows: rows}} = standings("euroleague", 2024)
    assert Enum.map(rows, & &1.name) == ["A", "B"]
  end

  test "ranks over the whole league when teams are listed once per group" do
    stub_response([
      [
        entry(1, 1, "East leader", "Eastern Conference", 50, 32),
        entry(1, 2, "West leader", "Western Conference", 60, 22),
        entry(1, 1, "East leader", "Atlantic Division", 50, 32),
        entry(1, 2, "West leader", "Pacific Division", 60, 22)
      ]
    ])

    assert {:ok, %{rows: rows}} = standings("nba", 2024)
    assert Enum.map(rows, &{&1.position, &1.name}) == [{1, "West leader"}, {2, "East leader"}]
  end

  test "an empty response means the season is not available" do
    stub_response([])

    assert {:error, message} = standings("nba", 2030)
    assert message =~ "2030"
  end

  test "surfaces the errors reported by the API" do
    Req.Test.stub(Basket, fn conn ->
      Req.Test.json(conn, %{"errors" => %{"token" => "Error/Missing application key"}})
    end)

    assert standings("nba", 2024) == {:error, "Error/Missing application key"}
  end

  test "returns the HTTP status when the API fails" do
    Req.Test.stub(Basket, fn conn -> Plug.Conn.send_resp(conn, 500, "") end)

    assert standings("nba", 2024) == {:error, "API returned HTTP 500"}
  end

  test "fails without an API key" do
    System.delete_env("BASKET_API")

    assert standings("nba", 2024) == {:error, "BASKET_API environment variable is not set"}
  end

  test "rejects the widgets it does not know" do
    assert Basket.fetch("unknown", %{}, %{}) == {:error, :unknown_widget}
  end

  describe "stats" do
    @lakers %{"id" => 145, "name" => "Los Angeles Lakers", "logo" => "https://logo/145.png"}

    defp statistics(overrides \\ %{}) do
      Map.merge(
        %{
          "league" => %{"name" => "NBA"},
          "team" => @lakers,
          "games" => %{
            "played" => %{"home" => 41, "away" => 41, "all" => 82},
            "wins" => %{
              "home" => %{"total" => 30, "percentage" => "0.732"},
              "away" => %{"total" => 20, "percentage" => "0.488"},
              "all" => %{"total" => 50, "percentage" => "0.610"}
            },
            "loses" => %{
              "home" => %{"total" => 11, "percentage" => "0.268"},
              "away" => %{"total" => 21, "percentage" => "0.512"},
              "all" => %{"total" => 32, "percentage" => "0.390"}
            }
          },
          "points" => %{
            "for" => %{"average" => %{"all" => "114.2"}},
            "against" => %{"average" => %{"all" => "110.5"}}
          }
        },
        overrides
      )
    end

    defp team_stats(league, season, team),
      do: Basket.fetch("stats", %{"league" => league, "season" => season, "team" => team}, %{})

    test "reads the statistics of the team for the league and the season" do
      stub_response(statistics())

      assert {:ok, stats} = team_stats("nba", 2024, "145")

      assert stats.team == "Los Angeles Lakers"
      assert stats.logo == "https://logo/145.png"
      assert stats.league == "NBA"
      assert stats.season == "2024-2025"
      assert stats.played == 82
      assert stats.wins == 50
      assert stats.losses == 32
      assert_in_delta stats.win_pct, 50 / 82, 0.0001
      assert stats.points_for_avg == 114.2
      assert stats.points_against_avg == 110.5
      assert {stats.home_wins, stats.home_losses} == {30, 11}
      assert {stats.away_wins, stats.away_losses} == {20, 21}

      assert_received {:request, conn}
      assert conn.request_path == "/statistics"
      assert conn.params == %{"league" => "12", "season" => "2024-2025", "team" => "145"}
      assert Plug.Conn.get_req_header(conn, "x-apisports-key") == ["test-key"]
    end

    test "WNBA seasons are a single year" do
      stub_response(statistics())

      assert {:ok, %{season: "2024"}} = team_stats("wnba", 2024, "1")

      assert_received {:request, conn}
      assert conn.params["season"] == "2024"
    end

    test "empty statistics are reported" do
      stub_response([])

      assert {:error, message} = team_stats("nba", 2024, "145")
      assert message =~ "pas disponibles"
    end

    test "surfaces the errors reported by the API" do
      Req.Test.stub(Basket, fn conn ->
        Req.Test.json(conn, %{"errors" => %{"plan" => "Free plans do not have access"}})
      end)

      assert team_stats("nba", 2030, "145") == {:error, "Free plans do not have access"}
    end

    test "fails without an API key" do
      System.delete_env("BASKET_API")

      assert team_stats("nba", 2024, "145") ==
               {:error, "BASKET_API environment variable is not set"}
    end

    test "rejects an unknown league without calling the API" do
      assert team_stats("curling", 2024, "145") == {:error, "Championnat inconnu : curling"}
      refute_received {:request, _}
    end
  end

  describe "team_options/1" do
    defp team_options(league, season),
      do: Basket.team_options(%{"league" => league, "season" => season})

    test "lists the teams of the league sorted by name, valued by id" do
      stub_response([
        %{"id" => 2, "name" => "Warriors"},
        %{"id" => 1, "name" => "celtics"},
        %{"id" => 2, "name" => "Warriors"},
        %{"id" => 3, "name" => "Lakers"}
      ])

      assert team_options("nba", "2024") ==
               {:ok, [{"celtics", "1"}, {"Lakers", "3"}, {"Warriors", "2"}]}

      assert_received {:request, conn}
      assert conn.request_path == "/teams"
      assert conn.params == %{"league" => "12", "season" => "2024-2025"}
    end

    test "accepts an integer season" do
      stub_response([%{"id" => 1, "name" => "Celtics"}])

      assert team_options("nba", 2024) == {:ok, [{"Celtics", "1"}]}
    end

    test "reports a league without teams for the season" do
      stub_response([])

      assert team_options("nba", "2024") == {:error, "Aucune équipe trouvée pour cette saison."}
    end

    test "rejects an invalid season without calling the API" do
      for season <- ["", "20", "abc", "3000", nil] do
        assert team_options("nba", season) == {:error, "Saison invalide."}
      end

      refute_received {:request, _}
    end

    test "asks for a league and a season when they are missing" do
      assert Basket.team_options(%{}) == {:error, "Choisis un championnat et une saison."}
    end
  end
end
