defmodule Backend.Repo.Migrations.AddDppaConsentAndErasure do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :terms_accepted, :boolean, default: false, null: false
      add :terms_accepted_at, :utc_datetime
      add :date_of_birth, :date
      add :dppa_consent_given, :boolean, default: false, null: false
      add :dppa_consent_timestamp, :utc_datetime
      add :dppa_consent_ip, :string
      add :data_retention_until, :date
    end

    create table(:data_erasure_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "pending", null: false
      add :reason, :text
      timestamps()
    end

    create index(:data_erasure_requests, [:user_id])
  end
end
