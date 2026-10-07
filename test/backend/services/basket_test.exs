#
## EPITECH PROJECT, 2026
## basket_test.exs
## File description:
## ExUnit for Dashboard.Services.Basket
#

defmodule Dashboard.Services.BasketTest do
  # Not async: the API key lives in the process-wide environment
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
end
