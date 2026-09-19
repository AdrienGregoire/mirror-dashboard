#
## EPITECH PROJECT, 2026
## accounts.ex
## File description:
## Handle accounts creation
#

defmodule Dashboard.Accounts do
  alias Dashboard.Repo
  alias Dashboard.Accounts.User
  @confirmation_token_bytes 32
  @dummy_hashed_password "#{Base.encode64(:binary.copy(<<0>>, 16))}$#{Base.encode64(:binary.copy(<<0>>, 32))}"

  def register_user(attrs, confirmation_url_fun) do
    token = generate_token()

    %User{}
    |> User.registration_changeset(attrs)
    |> Ecto.Changeset.put_change(:confirmation_token, token)
    |> Ecto.Changeset.put_change(
      :confirmation_sent_at,
      DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        Dashboard.Accounts.UserNotifier.deliver_confirmation_instructions(
          user,
          confirmation_url_fun.(token)
        )

        {:ok, user}

      error ->
        error
    end
  end

  def get_user_by_confirmation_token(token) when is_binary(token) do
    Repo.get_by(User, confirmation_token: token)
  end

  def confirm_user(%User{} = user) do
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(String.trim(email)))
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    case get_user_by_email(email) do
      nil ->
        User.valid_password?(%User{hashed_password: @dummy_hashed_password}, password)
        nil

      %User{confirmed_at: nil} = user ->
        User.valid_password?(user, password)
        nil

      %User{} = user ->
        if User.valid_password?(user, password), do: user, else: nil
    end
  end

  defp generate_token do
    @confirmation_token_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
