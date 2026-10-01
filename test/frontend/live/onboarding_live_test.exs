#
## EPITECH PROJECT, 2026
## onboarding_live_test.exs
## File description:
## ExUnit for DashboardWeb.OnboardingLive
#

defmodule DashboardWeb.OnboardingLiveTest do
  use DashboardWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Dashboard.Accounts

  defp confirmation_url_fun, do: fn token -> "http://localhost/users/confirm/#{token}" end

  defp user_fixture do
    email = "user#{System.unique_integer([:positive])}@epitech.eu"

    {:ok, user} =
      Accounts.register_user(%{email: email, password: "supersecret123"}, confirmation_url_fun())

    {:ok, user} = Accounts.confirm_user(user)
    user
  end

  defp log_in(conn, user), do: init_test_session(conn, user_id: user.id)

  test "redirects a guest to /login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/onboarding")
  end

  test "lists the available services", %{conn: conn} do
    user = user_fixture()
    {:ok, view, html} = conn |> log_in(user) |> live(~p"/onboarding")

    assert html =~ "foot"
    assert html =~ "basket"
    assert html =~ "tennis"
    assert has_element?(view, "button[disabled]", "Continuer")
  end

  test "picking a service enables the continue button", %{conn: conn} do
    user = user_fixture()
    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/onboarding")

    view |> element("button[phx-value-service='foot']") |> render_click()

    refute has_element?(view, "button[disabled]", "Continuer")
  end

  test "toggling a service twice clears the selection again", %{conn: conn} do
    user = user_fixture()
    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/onboarding")

    view |> element("button[phx-value-service='foot']") |> render_click()
    view |> element("button[phx-value-service='foot']") |> render_click()

    assert has_element?(view, "button[disabled]", "Continuer")
  end

  test "saving persists the selection and redirects to /dashboard", %{conn: conn} do
    user = user_fixture()
    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/onboarding")

    view |> element("button[phx-value-service='basket']") |> render_click()

    assert {:error, {:live_redirect, %{to: "/dashboard"}}} =
             view |> element("button", "Continuer") |> render_click()

    assert Accounts.get_user(user.id).preferred_services == ["basket"]
  end
end
