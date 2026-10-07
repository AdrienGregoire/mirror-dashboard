#
## EPITECH PROJECT, 2026
## dashboard_live_test.exs
## File description:
## ExUnit for DashboardWeb.DashboardLive
#
defmodule DashboardWeb.DashboardLiveTest do
  use DashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Dashboard.{Accounts, Widgets}

  defp confirmation_url_fun, do: fn token -> "http://localhost/users/confirm/#{token}" end

  defp user_fixture(preferred_services \\ []) do
    email = "user#{System.unique_integer([:positive])}@epitech.eu"

    {:ok, user} =
      Accounts.register_user(%{email: email, password: "supersecret123"}, confirmation_url_fun())

    {:ok, user} = Accounts.confirm_user(user)
    {:ok, user} = Accounts.set_preferred_services(user, preferred_services)

    user
  end

  defp log_in(conn, user), do: init_test_session(conn, user_id: user.id)

  defp add_widget!(user, service, widget, config) do
    {:ok, w} =
      Widgets.add_widget(user, %{
        service: service,
        widget: widget,
        config: config,
        refresh_rate: 60
      })

    w
  end

  test "redirects a guest to /login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
  end

  test "invites a user with no preferred service to the onboarding", %{conn: conn} do
    user = user_fixture()
    {:ok, _view, html} = conn |> log_in(user) |> live(~p"/dashboard")

    assert html =~ "aucun sport"
    assert html =~ "/onboarding"
  end

  test "shows the widgets of the active tab only", %{conn: conn} do
    user = user_fixture(["foot", "basket"])
    add_widget!(user, "foot", "top_scorers", %{"league" => "ligue-1", "season" => 2025})
    add_widget!(user, "basket", "stats", %{"team" => "lakers"})

    {:ok, _view, html} = conn |> log_in(user) |> live(~p"/dashboard")
    assert html =~ "Top buteurs"
    refute html =~ "Statistiques"
  end

  test "select_tab switches the displayed widgets", %{conn: conn} do
    user = user_fixture(["foot", "basket"])
    add_widget!(user, "foot", "top_scorers", %{"league" => "ligue-1", "season" => 2025})
    add_widget!(user, "basket", "stats", %{"team" => "lakers"})

    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/dashboard")
    html = view |> element("button[phx-value-service='basket']") |> render_click()

    assert html =~ "Statistiques"
    refute html =~ "Top buteurs"
  end

  test "move_widget updates the position when the widget belongs to the user", %{conn: conn} do
    user = user_fixture(["foot"])
    first = add_widget!(user, "foot", "standings", %{"league" => "ligue-1", "season" => 2025})
    add_widget!(user, "foot", "top_scorers", %{"league" => "ligue-1", "season" => 2025})

    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/dashboard")
    render_hook(view, "move_widget", %{"id" => to_string(first.id), "new_position" => "1"})

    assert Widgets.get_widget(user, first.id).position == 1
  end

  test "move_widget is a no-op for a widget that doesn't belong to the user", %{conn: conn} do
    user = user_fixture(["foot"])
    other_user = user_fixture()

    other_widget =
      add_widget!(other_user, "foot", "standings", %{"league" => "ligue-1", "season" => 2025})

    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/dashboard")

    render_hook(view, "move_widget", %{"id" => to_string(other_widget.id), "new_position" => "0"})

    assert Widgets.get_widget(other_user, other_widget.id).position == 0
  end

  describe "add widget flow" do
    setup %{conn: conn} do
      user = user_fixture(["basket", "foot", "tennis"])
      {:ok, view, _html} = conn |> log_in(user) |> live(~p"/dashboard")
      %{user: user, view: view}
    end

    defp open_modal(view), do: view |> element("#open-add-widget") |> render_click()

    defp pick_type(view, widget) do
      view |> element("#add-widget button[phx-value-widget='#{widget}']") |> render_click()
    end

    test "adds a configured widget to the active service", %{user: user, view: view} do
      assert open_modal(view) =~ "Classement"
      assert pick_type(view, "news") =~ "Nombre d&#39;éléments"

      view
      |> form("#add-widget-config", config: %{league: "nba", number: "5"})
      |> render_submit()

      view |> element("#add-widget button[phx-value-rate='900']") |> render_click()
      html = view |> form("#add-widget-refresh") |> render_submit()
      assert html =~ "Toutes les 15 min"
      assert html =~ "nba"

      view |> element("#add-widget button", "Ajouter le widget") |> render_click()

      assert render(view) =~ "Widget ajouté"
      refute has_element?(view, "#add-widget-modal")

      assert [widget] = Widgets.list_widgets(user)
      assert widget.service == "basket"
      assert widget.widget == "news"
      assert widget.config == %{"league" => "nba", "number" => 5}
      assert widget.refresh_rate == 900
    end

    test "uses the active tab as service", %{user: user, view: view} do
      view |> element("button[phx-value-service='foot']") |> render_click()
      open_modal(view)
      pick_type(view, "top_scorers")

      view
      |> form("#add-widget-config", config: %{league: "ligue-1", season: "2025"})
      |> render_submit()

      view
      |> form("#add-widget-refresh", rate: %{hours: "0", minutes: "2", seconds: "0"})
      |> render_submit()

      view |> element("#add-widget button", "Ajouter le widget") |> render_click()

      assert [%{service: "foot", refresh_rate: 120}] = Widgets.list_widgets(user)
    end

    test "shows the config errors and stays on the step", %{view: view} do
      open_modal(view)
      pick_type(view, "news")

      html =
        view
        |> form("#add-widget-config", config: %{league: "", number: "abc"})
        |> render_submit()

      assert html =~ "Ce champ est requis."
      assert html =~ "Doit être un nombre entier."
      assert has_element?(view, "#add-widget-config")
    end

    test "rejects an out of range refresh rate", %{view: view} do
      open_modal(view)
      pick_type(view, "standings")

      view |> form("#add-widget-config", config: %{league: "nba"}) |> render_submit()

      html =
        view
        |> form("#add-widget-refresh", rate: %{hours: "0", minutes: "0", seconds: "5"})
        |> render_submit()

      assert html =~ "Choisis une valeur entre 10 s et 24 h."
      assert has_element?(view, "#add-widget-refresh")
    end

    test "accepts a custom hours / minutes / seconds rate", %{user: user, view: view} do
      open_modal(view)
      pick_type(view, "standings")

      view |> form("#add-widget-config", config: %{league: "nba"}) |> render_submit()

      html =
        view
        |> form("#add-widget-refresh", rate: %{hours: "1", minutes: "30", seconds: "15"})
        |> render_submit()

      assert html =~ "Toutes les 1 h 30 min 15 s"

      view |> element("#add-widget button", "Ajouter le widget") |> render_click()

      assert [%{refresh_rate: 5415}] = Widgets.list_widgets(user)
    end

    test "foot standings offers a league select and requires a season", %{view: view} do
      view |> element("button[phx-value-service='foot']") |> render_click()
      open_modal(view)
      html = pick_type(view, "standings")

      assert html =~ "Premier League"
      assert html =~ "Saison"

      html =
        view
        |> form("#add-widget-config", config: %{league: "ligue-1", season: ""})
        |> render_submit()

      assert html =~ "Doit être un nombre entier."
      assert has_element?(view, "#add-widget-config")
    end

    test "foot top_scorers offers a league select and requires a season", %{view: view} do
      view |> element("button[phx-value-service='foot']") |> render_click()
      open_modal(view)
      html = pick_type(view, "top_scorers")

      assert html =~ "Premier League"
      assert html =~ "Saison"

      html =
        view
        |> form("#add-widget-config", config: %{league: "ligue-1", season: ""})
        |> render_submit()

      assert html =~ "Doit être un nombre entier."
      assert has_element?(view, "#add-widget-config")
    end

    test "basket standings offers a league select and requires a season", %{view: view} do
      open_modal(view)

      html = pick_type(view, "standings")
      assert html =~ "NBA"
      assert html =~ "Season"

      html =
        view
        |> form("#add-widget-config", config: %{league: "nba", season: ""})
        |> render_submit()

      assert html =~ "Doit être un nombre entier."
      assert has_element?(view, "#add-widget-config")
    end

    test "back keeps the entered config", %{view: view} do
      open_modal(view)
      pick_type(view, "standings")

      view |> form("#add-widget-config", config: %{league: "nba"}) |> render_submit()

      html = view |> element("#add-widget-refresh button", "Retour") |> render_click()
      assert html =~ ~s(value="nba")
    end

    test "closing the modal adds nothing", %{user: user, view: view} do
      open_modal(view)
      pick_type(view, "standings")

      render_click(view, "close_add_widget")

      refute has_element?(view, "#add-widget-modal")
      assert Widgets.list_widgets(user) == []
    end
  end
end
