#
## EPITECH PROJECT, 2026
## accounts.ex
## File description:
## Context module for user account management and authentication
#

defmodule Dashboard.Accounts do
  require Logger

  alias Dashboard.Repo
  alias Dashboard.Accounts.User
  alias Dashboard.Accounts.UserIdentity
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
        deliver_confirmation_async(user, confirmation_url_fun.(token))

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

  def set_preferred_services(%User{} = user, service_names) when is_list(service_names) do
    user
    |> User.preferred_services_changeset(%{preferred_services: service_names})
    |> Repo.update()
  end

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

  def get_or_create_user_from_oauth(auth) do
    provider = to_string(auth.provider)
    uid = to_string(auth.uid)
    email = auth.info.email && auth.info.email |> String.trim() |> String.downcase()

    case get_user_identity(provider, uid) do
      %UserIdentity{user: user} ->
        {:ok, user}

      nil ->
        create_or_link_user(provider, uid, email)
    end
  end

  def list_users do
    Repo.all(User)
  end

  def update_user_role(%User{} = user, attrs) do
    user
    |> User.role_changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def update_user_email(%User{} = user, attrs, confirmation_url_fun) do
    changeset = User.email_changeset(user, attrs)

    if changeset.valid? && changeset.changes[:email] do
      token = generate_token()

      changeset =
        changeset
        |> Ecto.Changeset.put_change(:confirmation_token, token)
        |> Ecto.Changeset.put_change(
          :confirmation_sent_at,
          DateTime.utc_now() |> DateTime.truncate(:second)
        )

      case Repo.update(changeset) do
        {:ok, updated_user} ->
          deliver_confirmation_async(updated_user, confirmation_url_fun.(token))

          {:ok, updated_user}

        error ->
          error
      end
    else
      Repo.update(changeset)
    end
  end

  def update_user_password(%User{} = user, password, attrs) do
    if user.hashed_password && !User.valid_password?(user, password) do
      {:error,
       Ecto.Changeset.add_error(Ecto.Changeset.change(user), :current_password, "is not valid")}
    else
      user
      |> User.password_changeset(attrs)
      |> Repo.update()
    end
  end

  # Sends the confirmation email without blocking the request (an SMTP server can
  # be slow), and logs the failure instead of silently dropping it.
  defp deliver_confirmation_async(%User{} = user, confirmation_url) do
    Task.Supervisor.start_child(Dashboard.TaskSupervisor, fn ->
      case Dashboard.Accounts.UserNotifier.deliver_confirmation_instructions(
             user,
             confirmation_url
           ) do
        {:ok, _email} ->
          :ok

        {:error, reason} ->
          Logger.error("Could not send the confirmation email: #{inspect(reason)}")
      end
    end)
  end

  defp get_user_identity(provider, uid) do
    UserIdentity
    |> Repo.get_by(provider: provider, uid: uid)
    |> case do
      nil -> nil
      identity -> Repo.preload(identity, :user)
    end
  end

  defp create_or_link_user(_provider, _uid, nil), do: {:error, :no_email_from_provider}

  defp create_or_link_user(provider, uid, email) do
    Repo.transaction(fn ->
      user =
        case get_user_by_email(email) do
          %User{} = existing_user -> existing_user
          nil -> insert_oauth_user!(email)
        end

      case link_identity(user, provider, uid) do
        {:ok, _identity} -> user
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp insert_oauth_user!(email) do
    case %User{} |> User.oauth_registration_changeset(%{email: email}) |> Repo.insert() do
      {:ok, user} -> user
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp link_identity(user, provider, uid) do
    %UserIdentity{}
    |> UserIdentity.changeset(%{provider: provider, uid: uid, user_id: user.id})
    |> Repo.insert()
  end

  defp generate_token do
    @confirmation_token_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
