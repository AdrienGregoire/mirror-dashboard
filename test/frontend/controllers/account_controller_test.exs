#
## EPITECH PROJECT, 2026
## account_controller_test.exs
## File description:
## ExUnit for DashboardWeb.AccountController
#

defmodule DashboardWeb.AccountControllerTest do
  use DashboardWeb.ConnCase, async: true

  alias Dashboard.Accounts

  defp confirmation_url_fun, do: fn token -> "http://localhost/users/confirm/#{token}" end

  defp user_fixture do
    email = "user#{System.unique_integer([:positive])}@epitech.eu"

    {:ok, user} =
      Accounts.register_user(%{email: email, password: "supersecret123"}, confirmation_url_fun())

    {:ok, user} = Accounts.confirm_user(user)
    user
  end

  test "redirects a guest to /login", %{conn: conn} do
    conn = get(conn, ~p"/account")
    assert redirected_to(conn) == ~p"/login"
  end

  test "renders the placeholder page for a logged in user", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> init_test_session(user_id: user.id)
      |> get(~p"/account")

    assert html_response(conn, 200) =~ "Mon compte"
  end
end
