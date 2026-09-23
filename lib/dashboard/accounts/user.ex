#
## EPITECH PROJECT, 2026
## user.ex
## File description:
## Ecto Schema and changesets for user account management
#

defmodule Dashboard.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  @min_char_pw 8
  @max_char_pw 72
  @iteration_nb 100_000
  @byte_size 16
  @key_len 32

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :hashed_password, :string
    field :role, :string, default: "user"
    field :confirmed_at, :utc_datetime
    field :confirmation_token, :string
    field :confirmation_sent_at, :utc_datetime
    has_many :identities, Dashboard.Accounts.UserIdentity
    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email()
    |> validate_password()
  end

  def oauth_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> put_change(:confirmed_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def confirm_changeset(user) do
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    change(user, %{
      confirmed_at: now,
      confirmation_token: nil
    })
  end

  def role_changeset(user, attrs) do
    user
      |> cast(attrs, [:role])
      |> validate_required([:role])
      |> validate_inclusion(:role, ["user", "admin"])
  end

  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and is_binary(password) do
    case String.split(hashed_password, "$") do
      [salt_b64, hash_b64] ->
        with {:ok, salt} <- Base.decode64(salt_b64),
             {:ok, expected_hash} <- Base.decode64(hash_b64) do
          hash = :crypto.pbkdf2_hmac(:sha256, password, salt, @iteration_nb, @key_len)
          Plug.Crypto.secure_compare(hash, expected_hash)
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  def valid_password?(_, _), do: false

  defp validate_email(changeset) do
    changeset
    |> update_change(:email, fn
      email when is_binary(email) -> email |> String.trim() |> String.downcase()
      other -> other
    end)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: @min_char_pw, max: @max_char_pw)
    |> hash_password()
  end

  defp hash_password(changeset) do
    case get_field(changeset, :password) do
      nil ->
        changeset

      password ->
        salt = :crypto.strong_rand_bytes(@byte_size)
        hash = :crypto.pbkdf2_hmac(:sha256, password, salt, @iteration_nb, @key_len)
        hashed_password = "#{Base.encode64(salt)}$#{Base.encode64(hash)}"
        put_change(changeset, :hashed_password, hashed_password)
    end
  end
end
