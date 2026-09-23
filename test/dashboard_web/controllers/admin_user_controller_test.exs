#
## EPITECH PROJECT, 2026
## auth_controller_test.exs
## File description:
## ExUnit for admin_user_controller
#

defmodule DashboardWeb.AdminUserControllerTest do
  use DashboardWeb.ConnCase
  alias Dashboard.Accounts

  @user_attrs %{email: "user@example.com", password: "supersecret123"}
  @admin_attrs %{email: "admin@example.com", password: "supersecret123"}

  defp confirmation_url_fun, do: fn token -> "http://localhost/users/confirm/#{token}" end

  defp setup_users do
    {:ok, normal_user} = Accounts.register_user(@user_attrs, confirmation_url_fun())
    {:ok, admin_user} = Accounts.register_user(@admin_attrs, confirmation_url_fun())
    {:ok, normal_user} = Accounts.confirm_user(normal_user)
    {:ok, admin_user} = Accounts.confirm_user(admin_user)
    {:ok, admin_user} = Accounts.update_user_role(admin_user, %{role: "admin"})
    %{normal_user: normal_user, admin_user: admin_user}
  end

  defp log_in(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end

  describe "Admin Authorization" do
    test "redirects guests to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/users")
      assert redirected_to(conn) == ~p"/login"
    end

    test "redirects non-admin users to home", %{conn: conn} do
      %{normal_user: user} = setup_users()

      conn =
        conn
        |> log_in(user)
        |> get(~p"/admin/users")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "permission"
    end
  end

  describe "Admin Actions" do
    test "lists all users", %{conn: conn} do
      %{admin_user: admin} = setup_users()

      conn =
        conn
        |> log_in(admin)
        |> get(~p"/admin/users")

      response = html_response(conn, 200)
      assert response =~ "Admin - Gestion des Utilisateurs"
      assert response =~ "user@example.com"
      assert response =~ "admin@example.com"
    end

    test "promotes a user to admin", %{conn: conn} do
      %{admin_user: admin, normal_user: user} = setup_users()

      conn =
        conn
        |> log_in(admin)
        |> patch(~p"/admin/users/#{user.id}/promote")

      assert redirected_to(conn) == ~p"/admin/users"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "promoted"
      updated_user = Accounts.get_user(user.id)
      assert updated_user.role == "admin"
    end

    test "deletes a user", %{conn: conn} do
      %{admin_user: admin, normal_user: user} = setup_users()

      conn =
        conn
        |> log_in(admin)
        |> delete(~p"/admin/users/#{user.id}")

      assert redirected_to(conn) == ~p"/admin/users"
      Phoenix.Flash.get(conn.assigns.flash, :info) =~ "deleted"
      assert Accounts.get_user(user.id) == nil
    end
  end
end
