#
## EPITECH PROJECT, 2026
## about_controller_test.exs
## File description:
## ExUnit for about_controller
#

defmodule DashboardWeb.AboutControllerTest do
  use DashboardWeb.ConnCase

  test "GET /about.json returns client host and server current_time", %{conn: conn} do
    conn = get(conn, ~p"/about.json")
    response = json_response(conn, 200)

    assert %{
             "client" => %{"host" => host},
             "server" => %{
               "current_time" => current_time,
               "services" => services
             }
           } = response

    assert is_binary(host)
    assert host != ""
    assert is_integer(current_time)
    assert current_time > 0
    assert is_list(services)
  end
end
