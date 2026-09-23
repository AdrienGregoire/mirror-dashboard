defmodule Dashboard.Repo.Migrations.CreateServiceSubscriptions do
  use Ecto.Migration

  def change do
    create table(:service_subscriptions) do
      add :service, :string, null: false
      add :credentials, :binary, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:service_subscriptions, [:user_id, :service])
  end
end
