#
## EPITECH PROJECT, 2026
## user_registration_controller_test.exs
## File description:
## ExUnit for user_registration_controller
#

defmodule DashboardWeb.UserRegistrationControllerTest do
  use DashboardWeb.ConnCase

  alias Dashboard.Accounts
  alias Dashboard.Repo

  import Swoosh.TestAssertions

  @valid_attrs %{"email" => "adrien.gregoire@epitech.eu", "password" => "azerty123"}

  describe "GET /register" do
    test "renders the registration form", %{conn: conn} do
      conn = get(conn, ~p"/register")
      response = html_response(conn, 200)

      assert response =~ "Create your account"
      assert response =~ "registration-form"
    end
  end

  describe "POST /register" do
    test "creates a user, sends a confirmation email and redirects", %{conn: conn} do
      conn = post(conn, ~p"/register", user: @valid_attrs)

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Check your email"

      user = Accounts.get_user_by_email(@valid_attrs["email"])
      assert user != nil
      assert user.confirmed_at == nil

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
      end)
    end

    test "re-renders the form with errors on invalid params", %{conn: conn} do
      conn = post(conn, ~p"/register", user: %{"email" => "not-an-email", "password" => "short"})

      response = html_response(conn, 200)
      assert response =~ "Create your account"

      refute_email_sent()
      assert Accounts.get_user_by_email("not-an-email") == nil
    end

    test "does not allow registering the same email twice", %{conn: conn} do
      conn1 = post(conn, ~p"/register", user: @valid_attrs)
      assert redirected_to(conn1) == ~p"/"

      conn2 = post(build_conn(), ~p"/register", user: @valid_attrs)
      response = html_response(conn2, 200)
      assert response =~ "Create your account"

      assert length(Repo.all(Dashboard.Accounts.User)) == 1
    end
  end
end
