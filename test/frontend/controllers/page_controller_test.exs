#
## EPITECH PROJECT, 2026
## page_controller_test.exs
## File description:
## ExUnit for page_controller
#

defmodule DashboardWeb.PageControllerTest do
  use DashboardWeb.ConnCase

  test "GET / shows the home page with login and register links", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "Welcome to Dashboard"
    assert html =~ ~s(href="/login")
    assert html =~ ~s(href="/register")
  end

  test "GET / labels the two entry points Log in and Sign up", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "Log in"
    assert html =~ "Sign up"
  end
end
