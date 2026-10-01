#
## EPITECH PROJECT, 2026
## user_notifier.ex
## File description:
## Email delivery module for account notifications
#

defmodule Dashboard.Accounts.UserNotifier do
  import Swoosh.Email
  alias Dashboard.Mailer

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Dashboard", "no-reply@dashboard.local"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_confirmation_instructions(user, confirmation_url) do
    deliver(user.email, "Confirm your account", """
    Hi #{user.email},

    Click the link below to confirm your account:

    #{confirmation_url}

    If you didn't create an account, ignore this email.
    """)
  end
end
