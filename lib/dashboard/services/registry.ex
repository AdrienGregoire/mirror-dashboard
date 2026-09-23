#
## EPITECH PROJECT, 2026
## registry.ex
## File description:
## Static catalog of the services and widget types supported by Dashboard
#

defmodule Dashboard.Services.Registry do
  @moduledoc """
  Catalog of every service and widget type supported by the server.

  Adding a service or a widget type is done here: it is then automatically
  exposed through `/about.json` and available for subscriptions.
  """

  alias Dashboard.Services.{Service, WidgetType}

  @services [
    %Service{
      name: "weather",
      description: "Current weather conditions",
      auth: :none,
      widgets: [
        %WidgetType{
          name: "city_temperature",
          description: "Display temperature for a city",
          params: [
            %{name: "city", type: "string"}
          ]
        }
      ]
    },
    %Service{
      name: "rss",
      description: "Articles from any RSS feed",
      auth: :none,
      widgets: [
        %WidgetType{
          name: "article_list",
          description: "Displaying the list of the last articles",
          params: [
            %{name: "link", type: "string"},
            %{name: "number", type: "integer"}
          ]
        }
      ]
    },
    %Service{
      name: "github",
      description: "Activity of your GitHub repositories",
      auth: :oauth,
      widgets: [
        %WidgetType{
          name: "recent_commits",
          description: "Display the last commits of a repository",
          params: [
            %{name: "repository", type: "string"},
            %{name: "number", type: "integer"}
          ]
        }
      ]
    }
  ]

  for %Service{name: service, widgets: widgets} <- @services,
      %WidgetType{name: widget, params: params} <- widgets,
      %{type: type} <- params,
      type not in WidgetType.param_types() do
    raise ArgumentError, "invalid param type #{inspect(type)} in #{service}/#{widget}"
  end

  @spec all() :: [Service.t()]
  def all, do: @services

  @spec get(String.t()) :: Service.t() | nil
  def get(name) when is_binary(name), do: Enum.find(@services, &(&1.name == name))
  def get(_), do: nil
end
