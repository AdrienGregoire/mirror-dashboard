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

  describe "get_user_by_email/1" do
    test "finds the user regardless of case" do
      {:ok, user} = Accounts.register_user(@valid_attrs, confirmation_url_fun())

      assert %User{id: id} = Accounts.get_user_by_email("Adrien.gregoire@epitech.eu")
      assert id == user.id
    end

    test "returns nil when no user matches" do
      assert Accounts.get_user_by_email("nobody@epitech.eu") == nil
    end
  end
end
