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
    add_widget!(user, "foot", "standings", %{"league" => "ligue-1"})
    add_widget!(user, "basket", "stats", %{"team" => "lakers"})

    {:ok, _view, html} = conn |> log_in(user) |> live(~p"/dashboard")

    assert html =~ "standings"
    refute html =~ "stats"
  end

  test "select_tab switches the displayed widgets", %{conn: conn} do
    user = user_fixture(["foot", "basket"])
    add_widget!(user, "foot", "standings", %{"league" => "ligue-1"})
    add_widget!(user, "basket", "stats", %{"team" => "lakers"})

    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/dashboard")

    html = view |> element("button[phx-value-service='basket']") |> render_click()

    assert html =~ "stats"
    refute html =~ "standings"
  end

  test "move_widget updates the position when the widget belongs to the user", %{conn: conn} do
    user = user_fixture(["foot"])
    first = add_widget!(user, "foot", "standings", %{"league" => "ligue-1"})
    add_widget!(user, "foot", "next_match", %{"team" => "psg"})

    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/dashboard")

    render_hook(view, "move_widget", %{"id" => to_string(first.id), "new_position" => "1"})

    assert Widgets.get_widget(user, first.id).position == 1
  end

  test "move_widget is a no-op for a widget that doesn't belong to the user", %{conn: conn} do
    user = user_fixture(["foot"])
    other_user = user_fixture()
    other_widget = add_widget!(other_user, "foot", "standings", %{"league" => "ligue-1"})

    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/dashboard")

    render_hook(view, "move_widget", %{"id" => to_string(other_widget.id), "new_position" => "0"})

    assert Widgets.get_widget(other_user, other_widget.id).position == 0
  end
end
