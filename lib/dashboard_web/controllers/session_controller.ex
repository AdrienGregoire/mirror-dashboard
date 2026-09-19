#
## EPITECH PROJECT, 2026
## session_controller.ex
## File description:
## session creation (login) and deletion (logout)
#

defmodule DashboardWeb.SessionController do
  use DashboardWeb, :controller

  alias Dashboard.Accounts
  alias DashboardWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, form: to_form(%{"email" => nil}, as: "user"))
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %Accounts.User{} = user ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user)
        |> redirect(to: ~p"/")

      nil ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:new, form: to_form(%{"email" => email}, as: "user"))
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
    |> redirect(to: ~p"/")
  end
end
