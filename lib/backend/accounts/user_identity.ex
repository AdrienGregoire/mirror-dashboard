#
## EPITECH PROJECT, 2026
## user_identity.ex
## File description:
## Ecto Schema linking a third-party OAuth account

defmodule Dashboard.Accounts.UserIdentity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_identities" do
    field :provider, :string
    field :uid, :string

    belongs_to :user, Dashboard.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(user_identity, attrs) do
    user_identity
    |> cast(attrs, [:provider, :uid, :user_id])
    |> validate_required([:provider, :uid, :user_id])
    |> unique_constraint([:provider, :uid])
    |> unique_constraint([:user_id, :provider])
    |> foreign_key_constraint(:user_id)
  end
end
