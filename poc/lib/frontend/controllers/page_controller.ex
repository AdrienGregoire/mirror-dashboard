defmodule PocWeb.PageController do
  use PocWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
