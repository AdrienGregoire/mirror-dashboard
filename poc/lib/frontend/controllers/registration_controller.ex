defmodule PocWeb.RegistrationController do
  use PocWeb, :controller

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Poc.UserStore.create(email, password) do
      {:ok, _email} ->
        conn
        |> put_session(:current_user, email)
        |> redirect(to: ~p"/dashboard")

      {:error, :already_exists} ->
        render(conn, :new, error: "Cet email est déjà utilisé.")
    end
  end
end
