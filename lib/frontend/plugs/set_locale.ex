#
## EPITECH PROJECT, 2026
## set_locale.ex
## File description:
## Plug assigning the locale to Gettext
#

defmodule DashboardWeb.Plugs.SetLocale do
  import Plug.Conn

  @supported_locales ~w(en fr)
  @default_locale "en"

  def init(default), do: default

  def call(conn, _default) do
    locale = fetch_locale(conn)

    Gettext.put_locale(DashboardWeb.Gettext, locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end

  defp fetch_locale(conn) do
    param_locale = conn.params["locale"]
    session_locale = get_session(conn, :locale)

    cond do
      param_locale in @supported_locales -> param_locale
      session_locale in @supported_locales -> session_locale
      true -> @default_locale
    end
  end
end
