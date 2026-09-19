#
## EPITECH PROJECT, 2026
## user_notifier_test.exs
## File description:
## ExUnit for Dashboard.Accounts.UserNotifier
#

defmodule Dashboard.Accounts.UserNotifierTest do
  use Dashboard.DataCase, async: true

  alias Dashboard.Accounts.User
  alias Dashboard.Accounts.UserNotifier

  import Swoosh.TestAssertions

  @user %User{email: "adrien.gregoire@epitech.eu"}
  @confirmation_url "http://localhost/users/confirm/some-token"

  test "deliver_confirmation_instructions/2 sends an email to the user" do
    {:ok, email} = UserNotifier.deliver_confirmation_instructions(@user, @confirmation_url)

    assert email.to == [{"", @user.email}]
    assert email.subject =~ "Confirm"
    assert email.text_body =~ @confirmation_url

    assert_email_sent(email)
  end

  test "the email body includes the confirmation link" do
    UserNotifier.deliver_confirmation_instructions(@user, @confirmation_url)

    assert_email_sent(fn email ->
      assert email.text_body =~ @confirmation_url
      assert email.text_body =~ @user.email
    end)
  end
end
