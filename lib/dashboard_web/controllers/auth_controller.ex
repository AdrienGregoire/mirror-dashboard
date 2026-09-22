#
## EPITECH PROJECT, 2026
## auth_controller.ex
## File description:
## Generic OAuth entry point (Ueberauth): request phase + callback
#

defmodule DashboardWeb.AuthController do
  use DashboardWeb, :controller
  plug Ueberauth
  alias Dashboard.Accounts
  alias DashboardWeb.UserAuth

  def request(conn, _params), do: conn

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed, please try again.")
    |> redirect(to: ~p"/login")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.get_or_create_user_from_oauth(auth) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome!")
        |> UserAuth.log_in_user(user)
        |> redirect(to: ~p"/")

      {:error, :no_email_from_provider} ->
        conn
        |> put_flash(
          :error,
          "Your GitHub account has no public email address. Make one visible on GitHub and try again."
        )
        |> redirect(to: ~p"/login")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Something went wrong, please try again.")
        |> redirect(to: ~p"/login")
    end
  end
end
