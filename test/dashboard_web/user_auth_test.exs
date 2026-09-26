#
## EPITECH PROJECT, 2026
## user_auth_test.exs
## File description:
## ExUnit for DashboardWeb.UserAuth
#

defmodule DashboardWeb.UserAuthTest do
  use DashboardWeb.ConnCase, async: true
  alias Dashboard.Accounts
  alias DashboardWeb.UserAuth

  @valid_attrs %{email: "adrien.gregoire@epitech.eu", password: "azerty123"}

  defp confirmation_url_fun, do: fn token -> "http://localhost/users/confirm/#{token}" end

  setup %{conn: conn} do
    {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())
    {:ok, user} = Accounts.confirm_user(user)

    %{conn: init_test_session(conn, %{}), user: user}
  end

  describe "log_in_user/2" do
    test "stores the user id in the session", %{conn: conn, user: user} do
      conn = UserAuth.log_in_user(conn, user)
      assert get_session(conn, :user_id) == user.id
    end

    test "renews the session id to protect against session fixation", %{conn: conn, user: user} do
      conn = put_session(conn, :some_previous_data, "should be wiped")
      conn = UserAuth.log_in_user(conn, user)

      refute get_session(conn, :some_previous_data)
      assert get_session(conn, :user_id) == user.id
    end
  end

  describe "log_out_user/1" do
    test "clears the session", %{conn: conn, user: user} do
      conn =
        conn
        |> UserAuth.log_in_user(user)
        |> UserAuth.log_out_user()

      assert get_session(conn, :user_id) == nil
    end
  end

  describe "fetch_current_user/2" do
    test "assigns current_user when the session holds a valid user id", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> put_session(:user_id, user.id)
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
    end

    test "assigns nil when the session has no user id", %{conn: conn} do
      conn = UserAuth.fetch_current_user(conn, [])
      assert conn.assigns.current_user == nil
    end

    test "assigns nil when the session's user id doesn't match anyone", %{conn: conn} do
      conn =
        conn
        |> put_session(:user_id, -1)
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user == nil
    end
  end

  describe "require_authenticated_user/2" do
    test "halts and redirects to /login when there is no current user", %{conn: conn} do
      conn =
        conn
        |> Phoenix.Controller.fetch_flash([])
        |> assign(:current_user, nil)
        |> UserAuth.require_authenticated_user([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/login"
    end

    test "lets the request through when there is a current user", %{conn: conn, user: user} do
      conn =
        conn
        |> Phoenix.Controller.fetch_flash([])
        |> assign(:current_user, user)
        |> UserAuth.require_authenticated_user([])

      refute conn.halted
    end
  end

  describe "redirect_if_user_is_authenticated/2" do
    test "halts and redirects to / when there is a current user", %{conn: conn, user: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> UserAuth.redirect_if_user_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "lets the request through when there is no current user", %{conn: conn} do
      conn =
        conn
        |> assign(:current_user, nil)
        |> UserAuth.redirect_if_user_is_authenticated([])

      refute conn.halted
    end
  end

  describe "post_login_path/1" do
    test "sends a user with no preferred service to onboarding", %{user: user} do
      assert UserAuth.post_login_path(user) == ~p"/onboarding"
    end

    test "sends a user with preferred services to the dashboard", %{user: user} do
      {:ok, user} = Accounts.set_preferred_services(user, ["foot"])
      assert UserAuth.post_login_path(user) == ~p"/dashboard"
    end
  end
end
