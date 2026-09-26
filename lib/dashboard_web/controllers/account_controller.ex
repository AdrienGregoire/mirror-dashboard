#
## EPITECH PROJECT, 2026
## account_controller.ex
## File description:
## Placeholder for the user account management page
#

defmodule DashboardWeb.AccountController do
  use DashboardWeb, :controller

  def show(conn, _params) do
    render(conn, :show)
  end
end
