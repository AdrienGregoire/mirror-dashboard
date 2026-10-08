#
## EPITECH PROJECT, 2026
## basket_stats_widget_test.exs
## File description:
## ExUnit for the basketball team stats card of DashboardWeb.DashboardLive
#

defmodule DashboardWeb.BasketStatsWidgetTest do
  use DashboardWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Req.Test, only: [set_req_test_to_shared: 1]

  alias Dashboard.{Accounts, Widgets}
  alias Dashboard.Services.Basket

  setup :set_req_test_to_shared

  setup do
    System.put_env("BASKET_API", "test-key")
    on_exit(fn -> System.delete_env("BASKET_API") end)

    {:ok, user} =
      Accounts.register_user(
        %{email: "stats@epitech.eu", password: "supersecret123"},
        fn token -> "http://localhost/users/confirm/#{token}" end
      )

    {:ok, user} = Accounts.confirm_user(user)
    {:ok, user} = Accounts.set_preferred_services(user, ["basket"])

    {:ok, _widget} =
      Widgets.add_widget(user, %{
        service: "basket",
        widget: "stats",
        config: %{"league" => "nba", "season" => 2024, "team" => "145"},
        refresh_rate: 60
      })

    %{user: user}
  end

  test "shows the statistics of the team", %{conn: conn, user: user} do
    lakers = %{"id" => 145, "name" => "Los Angeles Lakers", "logo" => "https://logo/145.png"}

    Req.Test.stub(Basket, fn conn ->
      response =
        case conn.request_path do
          "/statistics" ->
            %{
              "league" => %{"name" => "NBA"},
              "team" => lakers,
              "games" => %{
                "played" => %{"all" => 82},
                "wins" => %{
                  "home" => %{"total" => 30},
                  "away" => %{"total" => 20},
                  "all" => %{"total" => 50}
                },
                "loses" => %{
                  "home" => %{"total" => 11},
                  "away" => %{"total" => 21},
                  "all" => %{"total" => 32}
                }
              },
              "points" => %{
                "for" => %{"average" => %{"all" => "114.2"}},
                "against" => %{"average" => %{"all" => "110.5"}}
              }
            }
        end

      Req.Test.json(conn, %{"errors" => [], "response" => response})
    end)

    {:ok, _view, html} = conn |> init_test_session(user_id: user.id) |> live(~p"/dashboard")

    assert html =~ "Los Angeles Lakers"
    assert html =~ ~s(src="https://logo/145.png")
    assert html =~ "NBA"
    assert html =~ "114.2"
    assert html =~ "110.5"
    assert html =~ "30-11"
    assert html =~ "20-21"
    assert html =~ ".610"
  end

  test "shows the error when the API has no statistics", %{conn: conn, user: user} do
    Req.Test.stub(Basket, fn conn ->
      Req.Test.json(conn, %{"errors" => [], "response" => []})
    end)

    {:ok, _view, html} = conn |> init_test_session(user_id: user.id) |> live(~p"/dashboard")

    assert html =~ "pas disponibles"
  end
end
