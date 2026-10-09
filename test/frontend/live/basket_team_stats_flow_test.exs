#
## EPITECH PROJECT, 2026
## basket_team_stats_flow_test.exs
## File description:
## ExUnit for the league / season / team choice of the basketball stats widget
#

defmodule DashboardWeb.BasketTeamStatsFlowTest do
  use DashboardWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Req.Test, only: [set_req_test_to_shared: 1]

  alias Dashboard.{Accounts, Widgets}
  alias Dashboard.Services.Basket

  setup :set_req_test_to_shared

  setup %{conn: conn} do
    System.put_env("BASKET_API", "test-key")
    on_exit(fn -> System.delete_env("BASKET_API") end)

    test_pid = self()

    Req.Test.stub(Basket, fn conn ->
      send(test_pid, {:request, conn.request_path, conn.params})

      response =
        case {conn.request_path, conn.params["league"]} do
          {"/teams", "12"} ->
            [%{"id" => 145, "name" => "Los Angeles Lakers"}, %{"id" => 133, "name" => "Boston"}]

          {"/teams", "120"} ->
            [%{"id" => 7, "name" => "Real Madrid"}]

          {"/teams", _league} ->
            []

          {"/statistics", _league} ->
            %{"league" => %{"name" => "NBA"}, "team" => %{"id" => 145, "name" => "Lakers"}}
        end

      Req.Test.json(conn, %{"errors" => [], "response" => response})
    end)

    {:ok, user} =
      Accounts.register_user(
        %{email: "flow@epitech.eu", password: "supersecret123"},
        fn token -> "http://localhost/users/confirm/#{token}" end
      )

    {:ok, user} = Accounts.confirm_user(user)
    {:ok, user} = Accounts.set_preferred_services(user, ["basket"])

    {:ok, view, _html} = conn |> init_test_session(user_id: user.id) |> live(~p"/dashboard")
    view |> element("#open-add-widget") |> render_click()

    html = view |> element("#add-widget button[phx-value-widget='stats']") |> render_click()

    %{user: user, view: view, html: html}
  end

  defp change(view, config) do
    view |> form("#add-widget-config", config: config) |> render_change()
    render_async(view)
  end

  test "asks for the league and the season before listing the teams", %{html: html} do
    assert html =~ "League"
    assert html =~ "Season"
    assert html =~ "Renseigne d&#39;abord le championnat et la saison."
    refute_received {:request, "/teams", _}
  end

  test "the selects do not send partial changes", %{view: view} do
    refute has_element?(view, "#config_league[phx-change]")
    refute has_element?(view, "#config_team[phx-change]")
    assert has_element?(view, "#add-widget-config[phx-change]")
  end

  test "lists the teams of the chosen league and season", %{view: view} do
    html = change(view, %{league: "nba", season: "2024"})

    assert html =~ "Los Angeles Lakers"
    assert html =~ ~s(value="145")
    assert html =~ "Boston"
    refute html =~ "Real Madrid"

    assert_received {:request, "/teams", %{"league" => "12", "season" => "2024-2025"}}
  end

  test "does not call the API until the season is complete", %{view: view} do
    html = change(view, %{league: "nba", season: "20"})

    assert html =~ "Saison invalide."
    refute_received {:request, "/teams", _}
  end

  test "changing the league reloads the teams and forgets the chosen one", %{view: view} do
    change(view, %{league: "nba", season: "2024"})
    change(view, %{league: "nba", season: "2024", team: "145"})

    html = change(view, %{league: "euroleague", season: "2024"})

    assert html =~ "Real Madrid"
    refute html =~ "Los Angeles Lakers"
    refute html =~ ~s(value="145" selected)

    html = view |> form("#add-widget-config") |> render_submit()
    assert html =~ "Ce champ est requis."

    view |> form("#add-widget-config", config: %{team: "7"}) |> render_submit()
    assert has_element?(view, "#add-widget-refresh")
  end

  test "reports a league without teams", %{view: view} do
    html = change(view, %{league: "acb", season: "2024"})

    assert html =~ "Aucune équipe trouvée pour cette saison."
  end

  test "requires a team", %{view: view} do
    change(view, %{league: "nba", season: "2024"})

    html = view |> form("#add-widget-config", config: %{team: ""}) |> render_submit()

    assert html =~ "Ce champ est requis."
    assert has_element?(view, "#add-widget-config")
  end

  test "adds the widget with the id of the chosen team", %{user: user, view: view} do
    change(view, %{league: "nba", season: "2024"})

    view |> form("#add-widget-config", config: %{team: "145"}) |> render_submit()

    html = view |> element("#add-widget-refresh button", "Back") |> render_click()
    assert html =~ ~s(value="145" selected)

    view |> form("#add-widget-config", config: %{team: "145"}) |> render_submit()
    html = view |> form("#add-widget-refresh") |> render_submit()

    assert html =~ "Los Angeles Lakers"

    view |> element("#add-widget button", "Add the widget") |> render_click()

    assert [widget] = Widgets.list_widgets(user)
    assert widget.service == "basket"
    assert widget.widget == "stats"
    assert widget.config == %{"league" => "nba", "season" => 2024, "team" => "145"}
  end
end
