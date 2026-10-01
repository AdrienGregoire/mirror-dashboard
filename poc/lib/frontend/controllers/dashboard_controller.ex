defmodule PocWeb.DashboardController do
  use PocWeb, :controller

  def index(conn, _params) do
    case get_session(conn, :current_user) do
      nil ->
        redirect(conn, to: ~p"/register")
      email ->
        render(conn, :index, email: email)
    end
  end
end
