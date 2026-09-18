defmodule Dashboard.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :hashed_password, :string
    field :role, :string, default: "user"
    field :confirmed_at, :utc_datetime
    field :confirmation_token, :string
    field :confirmation_sent_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email()
    |> validate_password()
  end

  defp validate_email(changeset) do
    IO.puts()
  end

  defp validate_password(changeset) do
    IO.puts()
  end
end
