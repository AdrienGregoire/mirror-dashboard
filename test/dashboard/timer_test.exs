#
## EPITECH PROJECT, 2026
## timer_test.exs
## File description:
## ExUnit for Dashboard.Timer
#

defmodule Dashboard.TimerTest do
  use Dashboard.DataCase, async: false

  alias Dashboard.Accounts
  alias Dashboard.Timer
  alias Dashboard.Widgets
  alias Dashboard.Widgets.WidgetInstance

  setup do
    name = :"timer_#{System.unique_integer([:positive])}"
    pid = start_supervised!({Timer, name: name, load_instances: false, ms_per_second: 1})
    %{timer: pid}
  end

  test "refreshes an instance when its interval elapses, then schedules the next one", %{
    timer: timer
  } do
    Phoenix.PubSub.subscribe(Dashboard.PubSub, "dashboard:user:3")
    :ok = Timer.register(timer, widget(id: 9, user_id: 3, refresh_rate: 60))

    send_due(timer, 9)
    assert_receive {:refresh_widget, 9}

    send_due(timer, 9)
    assert_receive {:refresh_widget, 9}
  end

  test "each instance follows its own refresh rate", %{timer: timer} do
    Phoenix.PubSub.subscribe(Dashboard.PubSub, "dashboard:user:1")
    :ok = Timer.register(timer, widget(id: 1, user_id: 1, refresh_rate: 30))
    :ok = Timer.register(timer, widget(id: 2, user_id: 1, refresh_rate: 90))

    send_due(timer, 1)
    assert_receive {:refresh_widget, 1}
    refute_received {:refresh_widget, 2}

    send_due(timer, 2)
    assert_receive {:refresh_widget, 2}
  end

  test "a new refresh rate replaces the previous schedule", %{timer: timer} do
    Phoenix.PubSub.subscribe(Dashboard.PubSub, "dashboard:user:4")
    :ok = Timer.register(timer, widget(id: 5, user_id: 4, refresh_rate: 60))
    stale = token(timer, 5)

    :ok = Timer.register(timer, widget(id: 5, user_id: 4, refresh_rate: 120))
    assert Timer.get_refresh_rate(timer, 5) == 120

    send(timer, {:refresh, 5, stale})
    refute_receive {:refresh_widget, 5}

    send_due(timer, 5)
    assert_receive {:refresh_widget, 5}
  end

  test "unregister stops further refreshes", %{timer: timer} do
    Phoenix.PubSub.subscribe(Dashboard.PubSub, "dashboard:user:8")
    :ok = Timer.register(timer, widget(id: 8, user_id: 8, refresh_rate: 10))
    stale = token(timer, 8)

    :ok = Timer.unregister(timer, 8)
    assert Timer.get_refresh_rate(timer, 8) == nil

    send(timer, {:refresh, 8, stale})
    refute_receive {:refresh_widget, 8}
  end

  test "fires on the real interval", %{timer: timer} do
    Phoenix.PubSub.subscribe(Dashboard.PubSub, "dashboard:user:2")
    :ok = Timer.register(timer, widget(id: 4, user_id: 2, refresh_rate: 40))

    assert_receive {:refresh_widget, 4}, 500
  end

  test "loads the instances already stored when it boots", %{timer: timer} do
    user = user_fixture()

    {:ok, widget} =
      Widgets.add_widget(user, %{
        service: "rss",
        widget: "article_list",
        config: %{"link" => "https://example.com/rss", "number" => 5},
        refresh_rate: 45
      })

    Ecto.Adapters.SQL.Sandbox.allow(Dashboard.Repo, self(), timer)
    send(timer, :load_instances)

    assert Timer.get_refresh_rate(timer, widget.id) == 45
  end

  defp widget(attrs) do
    struct!(WidgetInstance, attrs)
  end

  defp token(timer, id) do
    %{entries: %{^id => %{token: token}}} = :sys.get_state(timer)
    token
  end

  defp send_due(timer, id) do
    send(timer, {:refresh, id, token(timer, id)})
  end

  defp user_fixture do
    {:ok, user} =
      Accounts.register_user(
        %{
          email: "timer-#{System.unique_integer([:positive])}@epitech.eu",
          password: "supersecret123"
        },
        fn token -> "http://localhost/users/confirm/#{token}" end
      )

    user
  end
end
