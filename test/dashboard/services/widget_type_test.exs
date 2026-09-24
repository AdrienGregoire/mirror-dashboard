#
## EPITECH PROJECT, 2026
## widget_type_test.exs
## File description:
## ExUnit for Dashboard.Services.WidgetType
#

defmodule Dashboard.Services.WidgetTypeTest do
  use ExUnit.Case, async: true
  alias Dashboard.Services.WidgetType

  @widget_type %WidgetType{
    name: "article_list",
    description: "Displaying the list of the last articles",
    params: [%{name: "link", type: "string"}, %{name: "number", type: "integer"}]
  }

  describe "cast_config/2" do
    test "accepts a valid config and drops unknown keys" do
      assert WidgetType.cast_config(@widget_type, %{
               "link" => " https://example.com/rss ",
               "number" => 5,
               "unknown" => "dropped"
             }) == {:ok, %{"link" => "https://example.com/rss", "number" => 5}}
    end

    test "accepts atom keys and integers given as strings" do
      assert WidgetType.cast_config(@widget_type, %{link: "https://example.com", number: "10"}) ==
               {:ok, %{"link" => "https://example.com", "number" => 10}}
    end

    test "requires every param" do
      assert WidgetType.cast_config(@widget_type, %{"link" => "   "}) ==
               {:error, [{"link", "can't be blank"}, {"number", "can't be blank"}]}
    end

    test "rejects values of the wrong type" do
      assert WidgetType.cast_config(@widget_type, %{"link" => 42, "number" => "ten"}) ==
               {:error, [{"link", "is invalid"}, {"number", "must be an integer"}]}
    end

    test "rejects too long strings" do
      config = %{"link" => String.duplicate("a", 2049), "number" => 1}
      assert WidgetType.cast_config(@widget_type, config) == {:error, [{"link", "is too long"}]}
    end

    test "rejects a config that is not a map" do
      assert {:error, _} = WidgetType.cast_config(@widget_type, "not a map")
    end
  end
end
