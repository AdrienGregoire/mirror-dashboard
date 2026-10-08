#
## EPITECH PROJECT, 2026
## tennis_test.exs
## File description:
## ExUnit for Dashboard.Services.Tennis
#

defmodule Dashboard.Services.TennisTest do
  use ExUnit.Case, async: false

  alias Dashboard.Services.Tennis

  setup do
    System.put_env("TENNIS_API", "test-key")
    on_exit(fn -> System.delete_env("TENNIS_API") end)
  end

  defp player(id, name, country \\ "Italy"),
    do: %{"id" => "sr:competitor:#{id}", "name" => name, "country" => country}

  defp summary(home, away, opts \\ []) do
    %{
      "sport_event" => %{
        "id" => "sr:sport_event:#{:erlang.unique_integer([:positive])}",
        "start_time" => Keyword.get(opts, :start, "2026-10-10T12:00:00+00:00"),
        "start_time_confirmed" => Keyword.get(opts, :confirmed, true),
        "sport_event_context" => %{
          "competition" => %{
            "name" => Keyword.get(opts, :competition, "Paris Masters Men Singles")
          },
          "round" => Keyword.get(opts, :round, %{"name" => "quarterfinal"})
        },
        "venue" => %{"name" => "Court Philippe-Chatrier", "city_name" => "Paris"},
        "competitors" => [Map.put(home, "qualifier", "home"), Map.put(away, "qualifier", "away")]
      },
      "sport_event_status" => %{"status" => Keyword.get(opts, :status, "not_started")}
    }
  end

  defp stub_days(days, test_pid \\ self()) do
    Req.Test.stub(Tennis, fn conn ->
      send(test_pid, {:request, conn})

      summaries =
        Enum.find_value(days, [], fn {offset, list} ->
          date = Date.utc_today() |> Date.add(offset) |> Date.to_iso8601()
          if conn.request_path == "/tennis/trial/v3/en/schedules/#{date}/summaries.json", do: list
        end)

      Req.Test.json(conn, %{"summaries" => summaries})
    end)
  end

  describe "parse_rankings/1" do
    test "extracts position, name, points and converts integer movement" do
      api_response = [
        %{
          "rank" => 1,
          "points" => 11000,
          "movement" => 0,
          "competitor" => %{"id" => "sr:competitor:1", "name" => "Djokovic, Novak"}
        },
        %{
          "rank" => 2,
          "points" => 9000,
          "movement" => 1,
          "competitor" => %{"id" => "sr:competitor:2", "name" => "Alcaraz, Carlos"}
        },
        %{
          "rank" => 3,
          "points" => 8000,
          "movement" => -1,
          "competitor" => %{"id" => "sr:competitor:3", "name" => "Sinner, Jannik"}
        }
      ]

      assert [
               %{position: 1, name: "Djokovic, Novak", points: 11000, movement: "same"},
               %{position: 2, name: "Alcaraz, Carlos", points: 9000, movement: "up"},
               %{position: 3, name: "Sinner, Jannik", points: 8000, movement: "down"}
             ] = Tennis.parse_rankings(api_response)
    end

    test "limits the results to max_players" do
      api_response =
        Enum.map(1..15, fn i ->
          %{
            "rank" => i,
            "points" => 1000,
            "movement" => 0,
            "competitor" => %{"name" => "Player #{i}"}
          }
        end)

      assert length(Tennis.parse_rankings(api_response)) == 10
    end
  end

  describe "fetch/3 next_match" do
    defp next_match(name), do: Tennis.fetch("next_match", %{"player" => name}, %{})

    test "returns the upcoming match of the player" do
      stub_days([
        {0,
         [
           summary(player(1, "Sinner, Jannik"), player(2, "Zverev, Alexander", "Germany"),
             competition: "Paris Masters Men Singles"
           ),
           summary(player(3, "Alcaraz, Carlos", "Spain"), player(4, "Medvedev, Daniil", "Russia"))
         ]}
      ])

      assert {:ok, match} = next_match("Sinner")

      assert %{
               player: "Jannik Sinner",
               player_country: "Italy",
               opponent: "Alexander Zverev",
               opponent_country: "Germany",
               start_time: "2026-10-10T12:00:00+00:00",
               time_confirmed: true,
               live: false,
               competition: "Paris Masters Men Singles",
               round: "Quarterfinal",
               venue: "Court Philippe-Chatrier",
               city: "Paris"
             } = match
    end

    test "puts the searched player first when he is the away competitor" do
      stub_days([
        {0, [summary(player(2, "Zverev, Alexander", "Germany"), player(1, "Sinner, Jannik"))]}
      ])

      assert {:ok, %{player: "Jannik Sinner", opponent: "Alexander Zverev"}} =
               next_match("sinner")
    end

    test "ignores case, accents, commas and word order" do
      stub_days([
        {0, [summary(player(1, "Sinner, Jannik"), player(2, "Švýcar, Jiří", "Czechia"))]}
      ])

      for query <- ["jannik sinner", "SINNER, Jannik", "  sinner  ", "Sinner Jannik"] do
        assert {:ok, %{player: "Jannik Sinner"}} = next_match(query)
      end

      assert {:ok, %{player: "Jiří Švýcar"}} = next_match("svycar jiri")
    end

    test "prefers an exact name over a partial one" do
      stub_days([
        {0,
         [
           summary(player(1, "Sinnerman, Bob"), player(2, "Doe, John"),
             start: "2026-10-10T08:00:00+00:00"
           ),
           summary(player(3, "Sinner, Jannik"), player(4, "Doe, Jane"),
             start: "2026-10-10T18:00:00+00:00"
           )
         ]}
      ])

      assert {:ok, %{player: "Jannik Sinner"}} = next_match("sinner")
    end

    test "returns the earliest match when the player has several" do
      stub_days([
        {0,
         [
           summary(player(1, "Sinner, Jannik"), player(2, "B, B"),
             start: "2026-10-10T18:00:00+00:00"
           ),
           summary(player(1, "Sinner, Jannik"), player(3, "A, A"),
             start: "2026-10-10T09:00:00+00:00"
           )
         ]}
      ])

      assert {:ok, %{opponent: "A A"}} = next_match("sinner")
    end

    test "skips finished matches and looks at the following days" do
      stub_days([
        {0,
         [summary(player(1, "Sinner, Jannik"), player(2, "Zverev, Alexander"), status: "closed")]},
        {2, [summary(player(1, "Sinner, Jannik"), player(3, "Rune, Holger", "Denmark"))]}
      ])

      assert {:ok, %{opponent: "Holger Rune"}} = next_match("sinner")
    end

    test "flags live matches" do
      stub_days([
        {0,
         [summary(player(1, "Sinner, Jannik"), player(2, "Zverev, Alexander"), status: "live")]}
      ])

      assert {:ok, %{live: true}} = next_match("sinner")
    end

    test "flags estimated start times and a missing round" do
      stub_days([
        {0,
         [
           summary(player(1, "Sinner, Jannik"), player(2, "Zverev, Alexander"),
             confirmed: false,
             round: nil
           )
         ]}
      ])

      assert {:ok, %{time_confirmed: false, round: nil}} = next_match("sinner")
    end

    test "uses the round number when the round has no name" do
      stub_days([
        {0,
         [
           summary(player(1, "Sinner, Jannik"), player(2, "Zverev, Alexander"),
             round: %{"number" => 5}
           )
         ]}
      ])

      assert {:ok, %{round: "Tour 5"}} = next_match("sinner")
    end

    test "ignores doubles" do
      doubles = fn name, id ->
        player(id, name) |> Map.put("players", [player(id + 100, "Sinner, Jannik")])
      end

      stub_days([{0, [summary(doubles.("Sinner J / Doe J", 10), doubles.("Foo A / Bar B", 11))]}])

      assert {:error, msg} = next_match("sinner")
      assert msg =~ "Aucun match à venir"
    end

    test "authenticates with the TENNIS_API key" do
      stub_days([{0, [summary(player(1, "Sinner, Jannik"), player(2, "Zverev, Alexander"))]}])

      assert {:ok, _} = next_match("sinner")
      assert_received {:request, conn}
      assert Plug.Conn.get_req_header(conn, "x-api-key") == ["test-key"]
    end

    test "errors when no match is found within the next days" do
      stub_days([])

      assert {:error, msg} = next_match("Sinner")
      assert msg =~ "Aucun match à venir trouvé pour Sinner"
    end

    test "errors on a blank player" do
      assert {:error, "Nom de joueur invalide."} = next_match("  ")
      assert {:error, "Nom de joueur invalide."} = next_match("a")
    end

    test "errors when TENNIS_API is not set" do
      System.delete_env("TENNIS_API")

      assert {:error, "TENNIS_API environment variable is not set"} = next_match("sinner")
    end

    test "maps HTTP errors to messages" do
      for {status, expected} <- [
            {403, "403"},
            {404, "404"},
            {429, "Quota"},
            {500, "HTTP 500"}
          ] do
        Req.Test.stub(Tennis, fn conn -> Plug.Conn.send_resp(conn, status, "") end)

        assert {:error, msg} = next_match("sinner")
        assert msg =~ expected
      end
    end

    test "reports transport errors" do
      Req.Test.stub(Tennis, fn conn -> Req.Test.transport_error(conn, :econnrefused) end)

      assert {:error, msg} = next_match("sinner")
      assert msg =~ "econnrefused"
    end
  end

  describe "fetch/3" do
    test "returns an error for an unknown widget" do
      assert {:error, :unknown_widget} = Tennis.fetch("unknown_widget", %{}, %{})
    end
  end
end
