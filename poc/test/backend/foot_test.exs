#
## EPITECH PROJECT, 2026
## foot_test.exs
## File description:
## ExUnit for PocFoot
#

defmodule Poc.FootTest do
  use ExUnit.Case, async: true

  setup do
    System.put_env("FOOT_API", "test_key")
    on_exit(fn -> System.delete_env("FOOT_API") end)
    :ok
  end

  test "returns team info on successful response" do
    Req.Test.stub(Poc.Foot, fn conn ->
      Req.Test.json(conn, %{
        "response" => [
          %{
            "team" => %{
              "name" => "Paris Saint Germain",
              "logo" => "https://media.api-sports.io/football/teams/85.png"
            }
          }
        ]
      })
    end)

    assert {:ok,
            %{
              name: "Paris Saint Germain",
              logo: "https://media.api-sports.io/football/teams/85.png"
            }} =
             Poc.Foot.fetch_team(85)
  end

  test "returns error when API response contains errors (even on HTTP 200)" do
    Req.Test.stub(Poc.Foot, fn conn ->
      Req.Test.json(conn, %{
        "errors" => %{"token" => "Invalid API key"}
      })
    end)

    assert {:error, %{"token" => "Invalid API key"}} = Poc.Foot.fetch_team(85)
  end

  test "returns error when response list is empty" do
    Req.Test.stub(Poc.Foot, fn conn ->
      Req.Test.json(conn, %{"response" => []})
    end)

    assert {:error, :not_found} = Poc.Foot.fetch_team(999_999)
  end

  test "returns error when FOOT_API is missing" do
    System.delete_env("FOOT_API")
    assert {:error, :missing_api_key} = Poc.Foot.fetch_team(85)
  end
end
