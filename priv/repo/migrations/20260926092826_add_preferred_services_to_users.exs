defmodule Dashboard.Repo.Migrations.AddPreferredServicesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :preferred_services, {:array, :string}, null: false, default: []
    end
  end
end
