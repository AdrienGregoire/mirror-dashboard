#
## EPITECH PROJECT, 2026
## registry.ex
## File description:
## Static catalog of the services and widget types supported by Dashboard
#

defmodule Dashboard.Services.Registry do
  alias Dashboard.Services.{Service, WidgetType}

  @basket_leagues [
    {"NBA", "nba"},
    {"WNBA", "wnba"},
    {"EuroLeague", "euroleague"},
    {"Betclic Élite (LNB)", "lnb-pro-a"},
    {"Liga ACB", "acb"}
  ]

  @services [
    %Service{
      name: "foot",
      description: "Football data powered by API-Football",
      auth: :none,
      provider: Dashboard.Services.Foot,
      widgets: [
        %WidgetType{
          name: "standings",
          description: "Classement d'un championnat",
          params: [
            %{
              name: "league",
              type: "string",
              options: [
                {"Premier League", "premier-league"},
                {"Ligue 1", "ligue-1"},
                {"Liga", "liga"},
                {"Bundesliga", "bundesliga"},
                {"Serie A", "serie-a"}
              ]
            },
            %{name: "season", type: "integer"}
          ]
        },
        %WidgetType{
          name: "top_scorers",
          description: "Meilleurs buteurs d'un championnat",
          params: [
            %{
              name: "league",
              type: "string",
              options: [
                {"Premier League", "premier-league"},
                {"Ligue 1", "ligue-1"},
                {"Liga", "liga"},
                {"Bundesliga", "bundesliga"},
                {"Serie A", "serie-a"}
              ]
            },
            %{name: "season", type: "integer"}
          ]
        }
      ]
    },
    %Service{
      name: "basket",
      description: "Basketball data powered by API-Sports",
      auth: :none,
      provider: Dashboard.Services.Basket,
      widgets: [
        %WidgetType{
          name: "standings",
          description: "Classement d'un championnat",
          params: [
            %{name: "league", type: "string", options: @basket_leagues},
            %{name: "season", type: "integer"}
          ]
        },
        %WidgetType{
          name: "stats",
          description: "Statistiques d'une équipe",
          params: [
            %{name: "league", type: "string", options: @basket_leagues},
            %{name: "season", type: "integer"},
            %{
              name: "team",
              type: "string",
              options_from: {Dashboard.Services.Basket, :team_options},
              depends_on: ["league", "season"]
            }
          ]
        }
      ]
    },
    %Service{
      name: "tennis",
      description: "Tennis data powered by API-Sports",
      auth: :none,
      provider: Dashboard.Services.Tennis,
      widgets: [
        %WidgetType{
          name: "player_ranking",
          description: "Classement des joueurs",
          params: [
            %{
              name: "circuit",
              type: "string",
              options: [{"ATP", "atp"}, {"WTA", "wta"}]
            }
          ]
        },
        %WidgetType{
          name: "standings",
          description: "Classement ATP/WTA",
          params: [%{name: "league", type: "string"}]
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
