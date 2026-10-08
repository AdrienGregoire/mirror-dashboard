#
## EPITECH PROJECT, 2026
## widgets_test.exs
## File description:
## ExUnit for Dashboard.Widgets
#

defmodule Dashboard.WidgetsTest do
  use Dashboard.DataCase, async: true
  alias Dashboard.{Accounts, Timer, Widgets}
  alias Dashboard.Widgets.WidgetInstance

  @standings %{
    service: "basket",
    widget: "standings",
    config: %{"league" => "nba", "season" => 5},
    refresh_rate: 60
  }

  defp user_fixture(email) do
    {:ok, user} =
      Accounts.register_user(
        %{email: email, password: "supersecret123"},
        fn token -> "http://localhost/users/confirm/#{token}" end
      )

    user
  end

  defp add_standings!(user, season) do
    {:ok, widget} =
      Widgets.add_widget(user, %{@standings | config: %{"league" => "nba", "season" => season}})

    widget
  end

  defp seasons(user), do: user |> Widgets.list_widgets() |> Enum.map(& &1.config["season"])
  defp positions(user), do: user |> Widgets.list_widgets() |> Enum.map(& &1.position)

  setup do
    %{user: user_fixture("owner@epitech.eu")}
  end

  describe "add_widget/2" do
    test "adds a configured widget at the end of the dashboard", %{user: user} do
      assert {:ok, %WidgetInstance{} = first} = Widgets.add_widget(user, @standings)
      assert first.position == 0
      assert first.user_id == user.id
      assert first.config == %{"league" => "nba", "season" => 5}
      assert first.refresh_rate == 60
      assert Timer.get_refresh_rate(first.id) == 60

      assert {:ok, second} = Widgets.add_widget(user, @standings)
      assert second.position == 1
    end

    test "accepts string keys and casts integer params", %{user: user} do
      attrs = %{
        "service" => "basket",
        "widget" => "standings",
        "config" => %{"league" => "nba", "season" => "3"},
        "refresh_rate" => "30"
      }

      assert {:ok, widget} = Widgets.add_widget(user, attrs)
      assert widget.config["season"] == 3
      assert widget.refresh_rate == 30
    end

    test "ignores user_id and position given by the caller", %{user: user} do
      other = user_fixture("other@epitech.eu")

      assert {:ok, widget} =
               Widgets.add_widget(user, Map.merge(@standings, %{user_id: other.id, position: 42}))

      assert widget.user_id == user.id
      assert widget.position == 0
    end

    test "two instances of the same widget keep their own config", %{user: user} do
      add_standings!(user, 1)
      add_standings!(user, 2)

      assert seasons(user) == [1, 2]
    end

    test "rejects an unknown widget type", %{user: user} do
      assert {:error, changeset} = Widgets.add_widget(user, %{@standings | widget: "unknown"})
      assert "does not exist for this service" in errors_on(changeset).widget
    end

    test "rejects an invalid config", %{user: user} do
      assert {:error, changeset} =
               Widgets.add_widget(user, %{@standings | config: %{"league" => ""}})

      assert "league can't be blank" in errors_on(changeset).config
      assert "season can't be blank" in errors_on(changeset).config
    end

    test "rejects an out of range refresh rate", %{user: user} do
      assert {:error, changeset} = Widgets.add_widget(user, %{@standings | refresh_rate: 1})
      assert "must be greater than or equal to 10" in errors_on(changeset).refresh_rate
    end

    test "foot standings requires a season", %{user: user} do
      attrs = %{
        service: "foot",
        widget: "standings",
        config: %{"league" => "ligue-1"},
        refresh_rate: 60
      }

      assert {:error, changeset} = Widgets.add_widget(user, attrs)
      assert "season can't be blank" in errors_on(changeset).config
    end

    test "foot standings casts the season to an integer", %{user: user} do
      attrs = %{
        service: "foot",
        widget: "standings",
        config: %{"league" => "ligue-1", "season" => "2025"},
        refresh_rate: 60
      }

      assert {:ok, widget} = Widgets.add_widget(user, attrs)
      assert widget.config == %{"league" => "ligue-1", "season" => 2025}
    end
  end

  describe "get_widget/2 and list_widgets/1" do
    test "only returns the widgets of the user", %{user: user} do
      widget = add_standings!(user, 1)
      other = user_fixture("other@epitech.eu")

      assert Widgets.get_widget(user, widget.id).id == widget.id
      assert Widgets.get_widget(user, to_string(widget.id)).id == widget.id
      assert Widgets.get_widget(other, widget.id) == nil
      assert Widgets.get_widget(user, "not-an-id") == nil
      assert Widgets.list_widgets(other) == []
    end
  end

  describe "reconfigure_widget/2" do
    test "updates the config and the refresh rate", %{user: user} do
      widget = add_standings!(user, 1)

      assert {:ok, updated} =
               Widgets.reconfigure_widget(widget, %{
                 config: %{"league" => "euroleague", "season" => 8},
                 refresh_rate: 120
               })

      assert updated.config == %{"league" => "euroleague", "season" => 8}
      assert updated.refresh_rate == 120
      assert Timer.get_refresh_rate(updated.id) == 120
    end

    test "cannot change the widget type nor the position", %{user: user} do
      widget = add_standings!(user, 1)

      assert {:ok, updated} =
               Widgets.reconfigure_widget(widget, %{service: "tennis", position: 9})

      assert updated.service == "basket"
      assert updated.position == 0
    end

    test "rejects an invalid config", %{user: user} do
      widget = add_standings!(user, 1)

      assert {:error, changeset} =
               Widgets.reconfigure_widget(widget, %{config: %{"league" => "euroleague"}})

      assert "season can't be blank" in errors_on(changeset).config
    end
  end

  describe "move_widget/2" do
    setup %{user: user} do
      %{widgets: Enum.map(1..4, &add_standings!(user, &1))}
    end

    test "moves a widget down", %{user: user, widgets: [first | _]} do
      assert {:ok, %WidgetInstance{position: 2}} = Widgets.move_widget(first, 2)
      assert seasons(user) == [2, 3, 1, 4]
      assert positions(user) == [0, 1, 2, 3]
    end

    test "moves a widget up", %{user: user, widgets: widgets} do
      assert {:ok, _} = Widgets.move_widget(List.last(widgets), 0)
      assert seasons(user) == [4, 1, 2, 3]
      assert positions(user) == [0, 1, 2, 3]
    end

    test "clamps out of range positions", %{user: user, widgets: [first, second | _]} do
      assert {:ok, %WidgetInstance{position: 3}} = Widgets.move_widget(first, 99)
      assert {:ok, %WidgetInstance{position: 0}} = Widgets.move_widget(second, -5)
      assert seasons(user) == [2, 3, 4, 1]
    end

    test "works with a stale struct", %{user: user, widgets: [first | _]} do
      {:ok, _} = Widgets.move_widget(first, 3)
      assert {:ok, _} = Widgets.move_widget(first, 1)
      assert seasons(user) == [2, 1, 3, 4]
      assert positions(user) == [0, 1, 2, 3]
    end
  end

  describe "delete_widget/1" do
    test "deletes the widget and closes the gap", %{user: user} do
      [_, second, _] = Enum.map(1..3, &add_standings!(user, &1))

      assert {:ok, deleted} = Widgets.delete_widget(second)
      assert Timer.get_refresh_rate(deleted.id) == nil
      assert seasons(user) == [1, 3]
      assert positions(user) == [0, 1]
    end

    test "returns an error for a widget already deleted", %{user: user} do
      widget = add_standings!(user, 1)
      {:ok, _} = Widgets.delete_widget(widget)

      assert Widgets.delete_widget(widget) == {:error, :not_found}
      assert Widgets.move_widget(widget, 0) == {:error, :not_found}
    end
  end

  describe "fetch_data/1" do
    # test "a service without provider is not implemented yet", %{user: user} do
    #   {:ok, widget} =
    #     Widgets.add_widget(user, %{
    #       service: "tennis",
    #       widget: "news",
    #       config: %{"league" => "atp", "number" => 5},
    #       refresh_rate: 60
    #     })

    #   assert Widgets.fetch_data(widget) == {:error, :not_implemented}
    # end

    test "an unknown service is rejected" do
      assert Widgets.fetch_data(%WidgetInstance{service: "nope", widget: "news"}) ==
               {:error, :unknown_service}
    end
  end
end
