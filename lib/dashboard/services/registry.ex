#
## EPITECH PROJECT, 2026
## registry.ex
## File description:
## Static catalog of the services and widget types supported by Dashboard
#

defmodule Dashboard.Services.Registry do
  alias Dashboard.Services.{Service, WidgetType}

  @services [
    %Service{
      name: "foot",
      description: "Football data powered by FotMob",
      auth: :none,
      widgets: [
        %WidgetType{
          name: "standings",
          description: "Classement d'un championnat",
          params: [%{name: "league", type: "string"}]
        },
        %WidgetType{
          name: "news",
          description: "Dernières actus d'une équipe ou d'un championnat",
          params: [
            %{name: "league", type: "string"},
            %{name: "number", type: "integer"}
          ]
        },
        %WidgetType{
          name: "stats",
          description: "Statistiques d'une équipe",
          params: [%{name: "team", type: "string"}]
        },
        %WidgetType{
          name: "next_match",
          description: "Prochain match d'une équipe",
          params: [%{name: "team", type: "string"}]
        }
      ]
    },
    %Service{
      name: "basket",
      description: "Basketball data powered by API-Sports",
      auth: :none,
      widgets: [
        %WidgetType{
          name: "standings",
          description: "Classement d'un championnat",
          params: [%{name: "league", type: "string"}]
        },
        %WidgetType{
          name: "news",
          description: "Dernières actus d'une équipe ou d'un championnat",
          params: [
            %{name: "league", type: "string"},
            %{name: "number", type: "integer"}
          ]
        },
        %WidgetType{
          name: "stats",
          description: "Statistiques d'une équipe",
          params: [%{name: "team", type: "string"}]
        },
        %WidgetType{
          name: "next_match",
          description: "Prochain match d'une équipe",
          params: [%{name: "team", type: "string"}]
        }
      ]
    },
    %Service{
      name: "tennis",
      description: "Tennis data powered by API-Sports",
      auth: :none,
      widgets: [
        %WidgetType{
          name: "standings",
          description: "Classement ATP/WTA",
          params: [%{name: "league", type: "string"}]
        },
        %WidgetType{
          name: "news",
          description: "Dernières actus d'un joueur ou d'un tournoi",
          params: [
            %{name: "league", type: "string"},
            %{name: "number", type: "integer"}
          ]
        },
        %WidgetType{
          name: "stats",
          description: "Statistiques d'un joueur",
          params: [%{name: "team", type: "string"}]
        },
        %WidgetType{
          name: "next_match",
          description: "Prochain match d'un joueur",
          params: [%{name: "team", type: "string"}]
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
