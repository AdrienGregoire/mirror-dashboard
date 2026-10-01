#
## EPITECH PROJECT, 2026
## page_controller.ex
## File description:
## controller for main page
#

defmodule PocWeb.PageController do
  use PocWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
