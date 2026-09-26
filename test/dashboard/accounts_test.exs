#
## EPITECH PROJECT, 2026
## accounts_test.exs
## File description:
## ExUnit for Dashboard.Accounts
#

defmodule Dashboard.AccountsTest do
  use Dashboard.DataCase, async: true
  alias Dashboard.Accounts
  alias Dashboard.Accounts.User
  import Swoosh.TestAssertions

  @valid_attrs %{email: "adrien.gregoire@epitech.eu", password: "supersecret123"}

  defp confirmation_url_fun, do: fn token -> "http://localhost/users/confirm/#{token}" end

  describe "register_user/2" do
    test "creates a user with a hashed password and a confirmation token" do
      assert {:ok, %User{} = user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert user.email == "adrien.gregoire@epitech.eu"
      assert user.hashed_password != nil
      assert user.hashed_password != @valid_attrs.password
      assert user.confirmation_token != nil
      assert user.confirmation_sent_at != nil
      assert user.confirmed_at == nil
    end

    test "downcases and trims the email" do
      attrs = %{@valid_attrs | email: "  Adrien.gregoire@Epitech.EU  "}
      assert {:ok, user} = Accounts.register_user(attrs, confirmation_url_fun())
      assert user.email == "adrien.gregoire@epitech.eu"
    end

    test "sends a confirmation email on success" do
      assert {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
        assert email.subject =~ "Confirm"
      end)
    end

    test "rejects duplicate emails" do
      assert {:ok, _user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert {:error, changeset} = Accounts.register_user(@valid_attrs, confirmation_url_fun())
      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects duplicate emails case-insensitively" do
      assert {:ok, _user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      attrs = %{@valid_attrs | email: "ADRIEN.gregoire@epitech.eu"}
      assert {:error, changeset} = Accounts.register_user(attrs, confirmation_url_fun())
      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects a password that is too short" do
      attrs = %{@valid_attrs | password: "short"}
      assert {:error, changeset} = Accounts.register_user(attrs, confirmation_url_fun())
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "rejects a missing email" do
      attrs = Map.delete(@valid_attrs, :email)
      assert {:error, changeset} = Accounts.register_user(attrs, confirmation_url_fun())
      assert "can't be blank" in errors_on(changeset).email
    end

    test "does not send an email when registration fails" do
      attrs = %{@valid_attrs | password: "short"}
      assert {:error, _changeset} = Accounts.register_user(attrs, confirmation_url_fun())

      refute_email_sent()
    end
  end

  describe "get_user_by_confirmation_token/1" do
    test "returns the user when the token matches" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert %User{id: id} = Accounts.get_user_by_confirmation_token(user.confirmation_token)
      assert id == user.id
    end

    test "returns nil for an unknown token" do
      assert Accounts.get_user_by_confirmation_token("does-not-exist") == nil
    end
  end

  describe "confirm_user/1" do
    test "sets confirmed_at and clears the confirmation token" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert {:ok, confirmed_user} = Accounts.confirm_user(user)
      assert confirmed_user.confirmed_at != nil
      assert confirmed_user.confirmation_token == nil
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "returns the user for a confirmed account with the right password" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())
      {:ok, confirmed_user} = Accounts.confirm_user(user)

      assert %User{id: id} =
               Accounts.get_user_by_email_and_password(user.email, @valid_attrs.password)

      assert id == confirmed_user.id
    end

    test "returns nil for the right password on an unconfirmed account" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert Accounts.get_user_by_email_and_password(user.email, @valid_attrs.password) == nil
    end

    test "returns nil for a wrong password" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())
      {:ok, _confirmed_user} = Accounts.confirm_user(user)

      assert Accounts.get_user_by_email_and_password(user.email, "wrong-password") == nil
    end

    test "returns nil for an unknown email" do
      assert Accounts.get_user_by_email_and_password("nobody@epitech.eu", "whatever123") == nil
    end
  end

  describe "get_user/1" do
    test "returns the user by id" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())
      assert %User{id: id} = Accounts.get_user(user.id)
      assert id == user.id
    end

    test "returns nil for an unknown id" do
      assert Accounts.get_user(-1) == nil
    end
  end

  describe "get_user_by_email/1" do
    test "finds the user regardless of case" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert %User{id: id} = Accounts.get_user_by_email("ADRIEN.gregoire@epitech.eu")
      assert id == user.id
    end

    test "returns nil when no user matches" do
      assert Accounts.get_user_by_email("nobody@epitech.eu") == nil
    end
  end

  describe "get_or_create_user_from_oauth/1" do
    defp oauth_auth(uid, email), do: %{provider: :github, uid: uid, info: %{email: email}}

    test "creates a new, pre-confirmed user with no password on first login" do
      assert {:ok, user} =
               Accounts.get_or_create_user_from_oauth(oauth_auth("111", "new@epitech.eu"))

      assert user.email == "new@epitech.eu"
      assert user.confirmed_at != nil
      assert user.hashed_password == nil
    end

    test "links the identity to an existing account with the same email" do
      {:ok, existing_user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert {:ok, user} =
               Accounts.get_or_create_user_from_oauth(oauth_auth("222", existing_user.email))

      assert user.id == existing_user.id
      # still a single account for that email — no duplicate created
      assert Accounts.get_user_by_email(existing_user.email).id == existing_user.id
    end

    test "returns the same user on a second login with the same identity" do
      {:ok, first_user} =
        Accounts.get_or_create_user_from_oauth(oauth_auth("333", "again@epitech.eu"))

      assert {:ok, second_user} =
               Accounts.get_or_create_user_from_oauth(oauth_auth("333", "again@epitech.eu"))

      assert second_user.id == first_user.id
    end

    test "returns an error when the provider gives no email" do
      assert Accounts.get_or_create_user_from_oauth(oauth_auth("444", nil)) ==
               {:error, :no_email_from_provider}
    end

    test "an OAuth-only account cannot log in with a password" do
      {:ok, user} = Accounts.get_or_create_user_from_oauth(oauth_auth("555", "nopass@epitech.eu"))

      assert Accounts.get_user_by_email_and_password(user.email, "whatever123") == nil
    end
  end

  describe "preferred_services_changeset/2" do
    test "accepts an empty list" do
      changeset = User.preferred_services_changeset(%User{}, %{preferred_services: []})
      assert changeset.valid?
    end

    test "accepts known service names" do
      changeset =
        User.preferred_services_changeset(%User{}, %{preferred_services: ["foot", "basket"]})

      assert changeset.valid?
    end

    test "rejects an unknown service name" do
      changeset = User.preferred_services_changeset(%User{}, %{preferred_services: ["rugby"]})

      refute changeset.valid?
      assert "unknown service rugby" in errors_on(changeset).preferred_services
    end
  end

  describe "set_preferred_services/2" do
    test "persists the chosen services" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert {:ok, updated} = Accounts.set_preferred_services(user, ["foot", "tennis"])
      assert updated.preferred_services == ["foot", "tennis"]
      assert Accounts.get_user(user.id).preferred_services == ["foot", "tennis"]
    end

    test "rejects an unknown service and keeps the previous value" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())
      {:ok, user} = Accounts.set_preferred_services(user, ["foot"])

      assert {:error, changeset} = Accounts.set_preferred_services(user, ["not-a-service"])
      assert "unknown service not-a-service" in errors_on(changeset).preferred_services
      assert Accounts.get_user(user.id).preferred_services == ["foot"]
    end
  end
end
