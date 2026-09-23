#
## EPITECH PROJECT, 2026
## user_auth.ex
## File description:
## login/logout
#

defmodule DashboardWeb.UserAuth do
  use DashboardWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller
  alias Dashboard.Accounts
  @session_user_id_key :user_id

  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(@session_user_id_key, user.id)
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> delete_session(@session_user_id_key)
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, @session_user_id_key)
    user = user_id && Accounts.get_user(user_id)

    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def require_admin(conn, _opts) do
    user = conn.assigns[:current_user]
    if user && user.role == "admin" do
      conn
    else
      conn
        |> put_flash(:error, "You do not have permission to access this page.")
        |> redirect(to: ~p"/")
        |> halt()
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/")
      |> halt()
    else
      conn
    end
  end
end
