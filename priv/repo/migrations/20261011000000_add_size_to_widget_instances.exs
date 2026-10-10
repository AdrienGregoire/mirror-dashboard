defmodule Dashboard.Repo.Migrations.AddSizeToWidgetInstances do
  use Ecto.Migration

  def change do
    alter table(:widget_instances) do
      add :col_span, :integer, null: false, default: 1
      add :height, :integer
    end
  end
end
