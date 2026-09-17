#
## EPITECH PROJECT, 2026
## about_controller.ex
## File description:
## called request for about.json
#

defmodule DashboardWeb.AboutController do
  use DashboardWeb, :controller

  def show(conn, _params) do
    client_ip = format_ip(conn.remote_ip)
    current_time = System.system_time(:second)
    json(conn, %{
      client: %{
        host: client_ip
    },
    server: %{
      current_time: current_time,
      services: []
    }
    })
  end

  defp format_ip(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end
end
