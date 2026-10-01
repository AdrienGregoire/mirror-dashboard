#
## EPITECH PROJECT, 2026
## user_confirmation_controller_test.exs
## File description:
## ExUnit for user_confirmation_controller
#

defmodule DashboardWeb.UserConfirmationControllerTest do
  use DashboardWeb.ConnCase

  alias Dashboard.Accounts

  @valid_attrs %{email: "adrien.gregoire@epitech.eu", password: "azerty123"}

  defp confirmation_url_fun, do: fn token -> "http://localhost/users/confirm/#{token}" end

  setup do
    {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())
    %{user: user}
  end

  describe "GET /users/confirm/:token" do
    test "confirms the user with a valid token and redirects", %{conn: conn, user: user} do
      conn = get(conn, ~p"/users/confirm/#{user.confirmation_token}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "confirmed successfully"

      confirmed_user = Accounts.get_user_by_email(user.email)
      assert confirmed_user.confirmed_at != nil
      assert confirmed_user.confirmation_token == nil
    end

    test "cannot be confirmed twice with the same token", %{conn: conn, user: user} do
      get(conn, ~p"/users/confirm/#{user.confirmation_token}")
      conn = get(build_conn(), ~p"/users/confirm/#{user.confirmation_token}")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid"
    end

    test "rejects an invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/confirm/not-a-real-token")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid"
    end
  end
end
