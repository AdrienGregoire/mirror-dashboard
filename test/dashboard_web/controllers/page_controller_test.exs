defmodule DashboardWeb.PageControllerTest do
  use DashboardWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Welcome to Dashboard"
  end
end
