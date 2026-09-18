defmodule Dashboard.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :role, :string, default: "user", null: false
      add :confirmed_at, :utc_datetime
      add :confirmation_token, :string
      add :confirmation_sent_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:confirmation_token])
  end
end
