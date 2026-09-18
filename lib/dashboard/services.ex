#
## EPITECH PROJECT, 2026
## services.ex
## File description:
## The content of services json
#

defmodule Dashboard.Services do
  @moduledoc """
  The services context.
  """
  @doc """
  Returns the list of available services on Dashboard
  """

  def list_services do
    [
      %{
        name: "weather",
        widgets: [
          %{
            name: "city_temperature",
            description: "Display temperature for a city",
            params: [
              %{name: "city", type: "string"}
            ]
          }
        ]
      },
      %{
        name: "rss",
        widgets: [
          %{
            name: "article_list",
            description: "Displaying the list of the last articles",
            params: [
              %{name: "link", type: "string"},
              %{name: "number", type: "integer"}
            ]
          }
        ]
      }
    ]
  end
end
