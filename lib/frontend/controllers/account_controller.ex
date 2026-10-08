#
## EPITECH PROJECT, 2026
## account_controller.ex
## File description:
## Placeholder for the user account management page
#

defmodule DashboardWeb.AccountController do
  use DashboardWeb, :controller
  alias Dashboard.Accounts
  alias DashboardWeb.UserAuth

  def show(conn, _params) do
    user = conn.assigns.current_user

    render(conn, :show,
      email_changeset: to_form(Accounts.User.email_changeset(user, %{})),
      password_changeset: to_form(Accounts.User.password_changeset(user, %{}))
    )
  end

  def update_email(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user

    case Accounts.update_user_email(user, user_params, &url(~p"/users/confirm/#{&1}")) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Un email de confirmation a été envoyé à ta nouvelle adresse.")
        |> redirect(to: ~p"/account")

      {:error, changeset} ->
        password_changeset = Accounts.User.password_changeset(user, %{})

        render(conn, :show,
          email_changeset: to_form(changeset),
          password_changeset: to_form(password_changeset)
        )
    end
  end

  def update_password(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user
    current_password = user_params["current_password"] || ""

    case Accounts.update_user_password(user, current_password, user_params) do
      {:ok, updated_user} ->
        conn
        |> put_flash(:info, "Mot de passe mis à jour avec succès.")
        # Renouvelle la session
        |> UserAuth.log_in_user(updated_user)
        |> redirect(to: ~p"/account")

      {:error, changeset} ->
        conn =
          if changeset.errors[:current_password] do
            put_flash(conn, :error, "Le mot de passe actuel est incorrect.")
          else
            conn
          end

        email_changeset = Accounts.User.email_changeset(user, %{})

        render(conn, :show,
          email_changeset: to_form(email_changeset),
          password_changeset: to_form(changeset)
        )
    end
  end

  def delete(conn, _params) do
    user = conn.assigns.current_user
    {:ok, _} = Accounts.delete_user(user)

    conn
    |> put_flash(:info, "Ton compte a été supprimé.")
    |> UserAuth.log_out_user()
  end
end
