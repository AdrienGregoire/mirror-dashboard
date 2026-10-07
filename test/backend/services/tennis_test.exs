#
## EPITECH PROJECT, 2026
## tennis_test.exs
## File description:
## ExUnit for Dashboard.Services.Tennis
#

defmodule Dashboard.Services.TennisTest do
  use ExUnit.Case, async: true

  alias Dashboard.Services.Tennis

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

  describe "fetch/3" do
    test "returns an error for an unknown widget" do
      assert {:error, :unknown_widget} = Tennis.fetch("unknown_widget", %{}, %{})
    end
  end
end
