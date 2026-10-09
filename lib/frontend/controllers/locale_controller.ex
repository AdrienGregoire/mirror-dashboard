#
## EPITECH PROJECT, 2026
## locale_controller.ex
## File description:
## locale controller
#

defmodule DashboardWeb.LocaleController do
  use DashboardWeb, :controller

  @supported_locales ~w(en fr)

  def set_locale(conn, %{"locale" => locale}) when locale in @supported_locales do
    redirect_path = get_req_header(conn, "referer") |> List.first() || ~p"/dashboard"

    conn
    |> put_session(:locale, locale)
    |> redirect(external: redirect_path)
  end

  def set_locale(conn, _params) do
    redirect(conn, to: ~p"/dashboard")
  end
end
