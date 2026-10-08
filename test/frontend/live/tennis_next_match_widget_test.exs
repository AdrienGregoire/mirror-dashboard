#
## EPITECH PROJECT, 2026
## tennis_next_match_widget_test.exs
## File description:
## ExUnit for the tennis next match card of DashboardWeb.DashboardLive
#

defmodule DashboardWeb.TennisNextMatchWidgetTest do
  use DashboardWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Req.Test, only: [set_req_test_to_shared: 1]

  alias Dashboard.{Accounts, Widgets}
  alias Dashboard.Services.Tennis

  setup :set_req_test_to_shared

  setup do
    System.put_env("TENNIS_API", "test-key")
    on_exit(fn -> System.delete_env("TENNIS_API") end)

    {:ok, user} =
      Accounts.register_user(
        %{email: "tennis@epitech.eu", password: "supersecret123"},
        fn token -> "http://localhost/users/confirm/#{token}" end
      )

    {:ok, user} = Accounts.confirm_user(user)
    {:ok, user} = Accounts.set_preferred_services(user, ["tennis"])

    {:ok, _widget} =
      Widgets.add_widget(user, %{
        service: "tennis",
        widget: "next_match",
        config: %{"player" => "sinner"},
        refresh_rate: 60
      })

    %{user: user}
  end

  defp stub_summaries(summaries) do
    Req.Test.stub(Tennis, fn conn ->
      Req.Test.json(conn, %{"summaries" => summaries})
    end)
  end

  defp match(opts) do
    %{
      "sport_event" => %{
        "start_time" => Keyword.get(opts, :start, "2026-10-10T12:30:00+00:00"),
        "start_time_confirmed" => Keyword.get(opts, :confirmed, true),
        "sport_event_context" => %{
          "competition" => %{"name" => "Paris Masters Men Singles"},
          "round" => %{"name" => "final"}
        },
        "venue" => %{"name" => "Centre Court", "city_name" => "Paris"},
        "competitors" => [
          %{"name" => "Sinner, Jannik", "country" => "Italy", "qualifier" => "home"},
          %{"name" => "Zverev, Alexander", "country" => "Germany", "qualifier" => "away"}
        ]
      },
      "sport_event_status" => %{"status" => Keyword.get(opts, :status, "not_started")}
    }
  end

  test "renders the page before the widget data arrives", %{conn: conn, user: user} do
    test_pid = self()

    Req.Test.stub(Tennis, fn conn ->
      send(test_pid, {:blocked, self()})

      receive do
        :go -> Req.Test.json(conn, %{"summaries" => [match([])]})
      end
    end)

    {:ok, view, html} = conn |> init_test_session(user_id: user.id) |> live(~p"/dashboard")
    assert html =~ "Chargement"
    refute html =~ "Jannik Sinner"

    assert_receive {:blocked, plug_pid}, 1_000
    send(plug_pid, :go)
    assert render_async(view) =~ "Jannik Sinner"
  end

  test "shows the next match of the player", %{conn: conn, user: user} do
    stub_summaries([match([])])

    {:ok, view, _html} = conn |> init_test_session(user_id: user.id) |> live(~p"/dashboard")
    html = render_async(view)

    assert html =~ "Jannik Sinner"
    assert html =~ "Alexander Zverev"
    assert html =~ "10/10/2026 · 12:30 UTC"
    assert html =~ "Paris Masters Men Singles"
    assert html =~ "Final"
    assert html =~ "Centre Court"
    assert html =~ ", Paris"
  end

  test "shows a live match and unconfirmed times", %{conn: conn, user: user} do
    stub_summaries([match(status: "live")])
    {:ok, view, _html} = conn |> init_test_session(user_id: user.id) |> live(~p"/dashboard")
    html = render_async(view)
    assert html =~ "EN DIRECT"
    assert html =~ "En cours"

    stub_summaries([match(confirmed: false)])
    {:ok, view, _html} = conn |> init_test_session(user_id: user.id) |> live(~p"/dashboard")
    html = render_async(view)
    assert html =~ "heure à confirmer"
  end

  test "shows an error when the player has no upcoming match", %{conn: conn, user: user} do
    stub_summaries([])

    {:ok, view, _html} = conn |> init_test_session(user_id: user.id) |> live(~p"/dashboard")
    html = render_async(view)

    assert html =~ "Aucun match à venir"
  end
end
