defmodule DashboardWeb.UserConfirmationController do
  use DashboardWeb, :controller

  alias Dashboard.Accounts

  def confirm(conn, %{"token" => token}) do
    case Accounts.get_user_by_confirmation_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Confirmation link is invalid or has already been used.")
        |> redirect(to: ~p"/")

      user ->
        case Accounts.confirm_user(user) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Account confirmed successfully!")
            |> redirect(to: ~p"/")

          {:error, _} ->
            conn
            |> put_flash(:error, "Something went wrong. Please try again.")
            |> redirect(to: ~p"/")
        end
    end
  end
end
