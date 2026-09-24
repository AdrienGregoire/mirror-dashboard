defmodule Dashboard.Repo.Migrations.CreateWidgetInstances do
  use Ecto.Migration

  def change do
    create table(:widget_instances) do
      add :service, :string, null: false
      add :widget, :string, null: false
      add :config, :map, null: false, default: %{}
      add :refresh_rate, :integer, null: false
      add :position, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:widget_instances, [:user_id, :position])
  end
end
