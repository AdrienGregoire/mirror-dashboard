#
## EPITECH PROJECT, 2026
## services_test.exs
## File description:
## ExUnit for Dashboard.Services
#

defmodule Dashboard.ServicesTest do
  use Dashboard.DataCase, async: true
  alias Dashboard.{Accounts, Services}
  alias Dashboard.Services.{Service, Subscription, WidgetType}

  @token %{"access_token" => "gho_super_secret_token"}

  setup do
    {:ok, user} =
      Accounts.register_user(
        %{email: "subscriber@epitech.eu", password: "supersecret123"},
        fn token -> "http://localhost/users/confirm/#{token}" end
      )

    %{user: user}
  end

  describe "registry" do
    test "every widget type has a name, a description and typed params" do
      for %Service{widgets: widgets} <- Services.list_services(),
          %WidgetType{} = widget <- widgets do
        assert is_binary(widget.name)
        assert is_binary(widget.description)
        assert widget.params != []
        assert Enum.all?(widget.params, &(&1.type in WidgetType.param_types()))
      end
    end

    test "get_service/1 and get_widget_type/2" do
      assert %Service{name: "rss", auth: :none} = Services.get_service("rss")
      assert Services.get_service("unknown") == nil

      assert %WidgetType{name: "article_list"} = Services.get_widget_type("rss", "article_list")
      assert Services.get_widget_type("rss", "unknown") == nil
      assert Services.get_widget_type("unknown", "article_list") == nil
    end
  end

  describe "subscribe/3" do
    test "stores the credentials encrypted", %{user: user} do
      assert {:ok, %Subscription{service: "github"}} = Services.subscribe(user, "github", @token)

      [raw] = Repo.query!("SELECT credentials FROM service_subscriptions").rows |> List.flatten()
      refute raw =~ "gho_super_secret_token"

      assert Services.get_credentials(user, "github") == {:ok, @token}
    end

    test "accepts atom keys", %{user: user} do
      assert {:ok, _} = Services.subscribe(user, "github", %{access_token: "abc"})
      assert Services.get_credentials(user, "github") == {:ok, %{"access_token" => "abc"}}
    end

    test "replaces the credentials when already subscribed", %{user: user} do
      {:ok, _} = Services.subscribe(user, "github", @token)
      {:ok, _} = Services.subscribe(user, "github", %{"access_token" => "new_token"})

      assert [_single] = Services.list_subscriptions(user)
      assert Services.get_credentials(user, "github") == {:ok, %{"access_token" => "new_token"}}
    end

    test "rejects an unknown service", %{user: user} do
      assert {:error, changeset} = Services.subscribe(user, "unknown", @token)
      assert "does not exist" in errors_on(changeset).service
    end

    test "rejects a service that needs no account", %{user: user} do
      assert {:error, changeset} = Services.subscribe(user, "weather", @token)
      assert "does not require a subscription" in errors_on(changeset).service
    end

    test "rejects missing credentials", %{user: user} do
      assert {:error, changeset} = Services.subscribe(user, "github", %{"access_token" => ""})
      assert "missing access_token" in errors_on(changeset).credentials
    end

    test "never shows the credentials when inspected", %{user: user} do
      {:ok, subscription} = Services.subscribe(user, "github", @token)
      refute inspect(subscription) =~ "gho_super_secret_token"
    end
  end

  describe "availability" do
    test "services without account are available by default", %{user: user} do
      names = user |> Services.available_services() |> Enum.map(& &1.name)

      assert "weather" in names
      assert "rss" in names
      refute "github" in names
      assert Services.subscribed?(user, "weather")
      refute Services.subscribed?(user, "github")
      refute Services.subscribed?(user, "unknown")
    end

    test "a subscribed service becomes available", %{user: user} do
      {:ok, _} = Services.subscribe(user, "github", @token)

      assert "github" in Enum.map(Services.available_services(user), & &1.name)
      assert Services.subscribed?(user, "github")
    end
  end

  describe "unsubscribe/2" do
    test "removes the subscription and its credentials", %{user: user} do
      {:ok, _} = Services.subscribe(user, "github", @token)

      assert Services.unsubscribe(user, "github") == :ok
      assert Services.get_credentials(user, "github") == {:error, :not_subscribed}
      assert Services.unsubscribe(user, "github") == {:error, :not_subscribed}
    end
  end
end
