defmodule Backend.Repo.Migrations.AddScanStatusToUploads do
  use Ecto.Migration

  def change do
    alter table(:uploads) do
      add :scan_status, :string, default: "pending", null: false
    end
  end
end
