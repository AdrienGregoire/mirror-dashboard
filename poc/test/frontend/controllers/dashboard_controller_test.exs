#
## EPITECH PROJECT, 2026
## dashboard_controller_test.exs
## File description:
## ExUnit for dashboard_controller
#

defmodule PocWeb.DashboardControllerTest do
  use PocWeb.ConnCase, async: true

  setup do
    System.put_env("FOOT_API", "test_key")
    on_exit(fn -> System.delete_env("FOOT_API") end)
    :ok
  end

  test "redirects to /register if user is not logged in", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")
    assert redirected_to(conn) == ~p"/register"
  end

  test "renders dashboard with team info when logged in", %{conn: conn} do
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

    conn =
      conn
      |> init_test_session(current_user: "test@example.com")
      |> get(~p"/dashboard")

    assert html_response(conn, 200) =~ "Paris Saint Germain"
    assert html_response(conn, 200) =~ "https://media.api-sports.io/football/teams/85.png"
  end

  test "renders dashboard with fallback message when API fails", %{conn: conn} do
    Req.Test.stub(Poc.Foot, fn conn ->
      Req.Test.json(conn, %{"errors" => %{"rate_limit" => "Quota exceeded"}})
    end)

    conn =
      conn
      |> init_test_session(current_user: "test@example.com")
      |> get(~p"/dashboard")

    assert html_response(conn, 200) =~ "Impossible de charger les données football."
  end
end
