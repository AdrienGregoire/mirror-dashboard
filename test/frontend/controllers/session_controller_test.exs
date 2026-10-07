#
## EPITECH PROJECT, 2026
## session_controller_test.exs
## File description:
## ExUnit for session_controller
#

defmodule DashboardWeb.SessionControllerTest do
  use DashboardWeb.ConnCase
  alias Dashboard.Accounts

  @valid_attrs %{email: "kyle@example.com", password: "supersecret123"}

  defp confirmation_url_fun, do: fn token -> "http://localhost/users/confirm/#{token}" end

  defp register_and_confirm_user do
    {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())
    {:ok, user} = Accounts.confirm_user(user)
    user
  end

  describe "GET /login" do
    test "renders the login form", %{conn: conn} do
      conn = get(conn, ~p"/login")
      response = html_response(conn, 200)

      assert response =~ "Log in"
      assert response =~ "login-form"
    end

    test "renders the glass card with the GitHub button and the sign up link", %{conn: conn} do
      response = conn |> get(~p"/login") |> html_response(200)

      assert response =~ "glass-card"
      assert response =~ ~s(href="/auth/github")
      assert response =~ "Continue with GitHub"
      assert response =~ ~s(href="/register")
      assert response =~ ~s(autocomplete="current-password")
    end

    test "still shows the form to a user who already has a session", %{conn: conn} do
      user = register_and_confirm_user()

      conn =
        conn
        |> post(~p"/login", user: %{"email" => user.email, "password" => @valid_attrs.password})
        |> recycle()
        |> get(~p"/login")

      assert html_response(conn, 200) =~ "Continue with GitHub"
    end
  end

  describe "POST /login" do
    test "logs in with valid credentials and redirects", %{conn: conn} do
      user = register_and_confirm_user()

      conn =
        post(conn, ~p"/login",
          user: %{"email" => user.email, "password" => @valid_attrs.password}
        )

      assert redirected_to(conn) == ~p"/onboarding"
      assert get_session(conn, :user_id) == user.id
    end

    test "rejects a wrong password", %{conn: conn} do
      user = register_and_confirm_user()

      conn =
        post(conn, ~p"/login", user: %{"email" => user.email, "password" => "wrong-password"})

      response = html_response(conn, 200)
      assert response =~ "Invalid email or password"
      assert get_session(conn, :user_id) == nil
    end

    test "keeps the email but never echoes the password after a failed login", %{conn: conn} do
      user = register_and_confirm_user()

      conn =
        post(conn, ~p"/login", user: %{"email" => user.email, "password" => "wrong-password"})

      response = html_response(conn, 200)
      assert response =~ ~s(value="#{user.email}")
      refute response =~ "wrong-password"
    end

    test "rejects an unknown email", %{conn: conn} do
      conn =
        post(conn, ~p"/login",
          user: %{"email" => "nobody@example.com", "password" => "whatever123"}
        )

      response = html_response(conn, 200)
      assert response =~ "Invalid email or password"
    end

    test "rejects an unconfirmed account", %{conn: conn} do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      conn =
        post(conn, ~p"/login",
          user: %{"email" => user.email, "password" => @valid_attrs.password}
        )

      response = html_response(conn, 200)
      assert response =~ "Invalid email or password"
      assert get_session(conn, :user_id) == nil
    end
  end

  describe "DELETE /logout" do
    test "clears the session and redirects to /", %{conn: conn} do
      user = register_and_confirm_user()

      conn =
        conn
        |> post(~p"/login", user: %{"email" => user.email, "password" => @valid_attrs.password})
        |> recycle()
        |> delete(~p"/logout")

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_id) == nil
    end
  end
end
