#
## EPITECH PROJECT, 2026
## user_registration_controller.ex
## File description:
## create the user registration controller
#

defmodule DashboardWeb.UserRegistrationController do
  use DashboardWeb, :controller

  alias Dashboard.Accounts
  alias Dashboard.Accounts.User

  def new(conn, _params) do
    form = to_form(User.registration_changeset(%User{}, %{}))
    render(conn, :new, form: form)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params, &url(~p"/users/confirm/#{&1}")) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account created! Check your email to confirm your account.")
        |> redirect(to: ~p"/")

      {:error, changeset} ->
        form = to_form(changeset)
        render(conn, :new, form: form)
    end
  end
end
