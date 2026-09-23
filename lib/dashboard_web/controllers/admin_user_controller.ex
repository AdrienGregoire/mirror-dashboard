#
## EPITECH PROJECT, 2026
## admin_user_controller.ex
## File description:
## Controller managing admin actions for user
#

defmodule DashboardWeb.AdminUserController do
  use DashboardWeb, :controller
  alias Dashboard.Accounts

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, :index, users: users)
  end

  def promote(conn, %{"id" => id}) do
    user = Accounts.get_user(id)

    case Accounts.update_user_role(user, %{role: "admin"}) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User promoted to admin successfully.")
        |> redirect(to: ~p"/admin/users")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not promote user.")
        |> redirect(to: ~p"/admin/users")
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user(id)

    case Accounts.delete_user(user) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User deleted successfully.")
        |> redirect(to: ~p"/admin/users")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not delete user.")
        |> redirect(to: ~p"/admin/users")
    end
  end
end
