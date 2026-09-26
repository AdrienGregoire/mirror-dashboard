#
## EPITECH PROJECT, 2026
## auth_controller_test.exs
## File description:
## ExUnit for auth_controller
#

defmodule DashboardWeb.AuthControllerTest do
  use DashboardWeb.ConnCase, async: true
  alias Dashboard.Accounts
  alias DashboardWeb.AuthController

  defp conn_with_session(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.Controller.fetch_flash([])
  end

  describe "callback/2 on success" do
    test "logs the user in and redirects to /onboarding", %{conn: conn} do
      auth = %{provider: :github, uid: "999", info: %{email: "octocat@epitech.eu"}}

      conn =
        conn
        |> conn_with_session()
        |> assign(:ueberauth_auth, auth)
        |> AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/onboarding"

      user = Accounts.get_user_by_email("octocat@epitech.eu")
      assert user != nil
      assert get_session(conn, :user_id) == user.id
    end
  end

  describe "callback/2 when the provider has no email" do
    test "redirects to /login with an explanatory flash", %{conn: conn} do
      auth = %{provider: :github, uid: "998", info: %{email: nil}}

      conn =
        conn
        |> conn_with_session()
        |> assign(:ueberauth_auth, auth)
        |> AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "public email"
      assert get_session(conn, :user_id) == nil
    end
  end

  describe "callback/2 on failure" do
    test "redirects to /login with a generic flash error", %{conn: conn} do
      conn =
        conn
        |> conn_with_session()
        |> assign(:ueberauth_failure, %{errors: []})
        |> AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication failed"
    end
  end
end
