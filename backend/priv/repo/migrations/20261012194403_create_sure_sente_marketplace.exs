defmodule Backend.Repo.Migrations.CreateSureSenteMarketplace do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :phone, :string, null: false
      add :role, :string, default: "customer"
      add :is_worker, :boolean, default: false
      add :is_provider, :boolean, default: false
      add :is_customer, :boolean, default: true
      add :is_seller, :boolean, default: false
      add :is_employer, :boolean, default: false
      add :is_broker, :boolean, default: false
      add :is_staff, :boolean, default: false
      add :staff_role, :string
      add :status, :string, default: "active"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:phone])

    create table(:otp_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :phone, :string, null: false
      add :code_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, default: 0
      add :used_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:otp_codes, [:phone])

    create table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :display_name, :string
      add :skills, {:array, :string}, default: []
      add :service_areas, {:array, :string}, default: []
      add :availability, :string
      add :bio, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:profiles, [:user_id])

    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :name, :string
      add :kind, :string
      add :pilot_enabled, :boolean, default: false
      add :gate_status, :string, default: "open"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:key])

    create table(:listings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_id, references(:users, type: :binary_id), null: false
      add :category_id, references(:categories, type: :binary_id), null: false
      add :title, :string, null: false
      add :description, :string
      add :kind, :string, default: "work"
      add :pay_amount_minor, :integer
      add :pay_basis, :string
      add :currency, :string, default: "UGX"
      add :location_text, :string
      add :coarse_location, :string
      add :status, :string, default: "draft"
      add :version, :integer, default: 1
      add :commission_type, :string
      add :commission_value_minor, :integer
      add :commission_bps, :integer
      add :commission_currency, :string, default: "UGX"
      add :commission_version, :integer, default: 1
      timestamps(type: :utc_datetime)
    end

    create index(:listings, [:status])
    create index(:listings, [:category_id])

    create table(:listing_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :listing_id, references(:listings, type: :binary_id, on_delete: :delete_all),
        null: false

      add :version, :integer, null: false
      add :snapshot, :map
      timestamps(type: :utc_datetime)
    end

    create table(:applications, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :listing_id, references(:listings, type: :binary_id, on_delete: :delete_all),
        null: false

      add :applicant_id, references(:users, type: :binary_id), null: false
      add :cover_note, :string
      add :status, :string, default: "submitted"
      timestamps(type: :utc_datetime)
    end

    create table(:offers, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :application_id, references(:applications, type: :binary_id, on_delete: :delete_all),
        null: false

      add :version, :integer, default: 1
      add :pay_minor, :integer
      add :scope_text, :string
      add :status, :string, default: "proposed"
      timestamps(type: :utc_datetime)
    end

    create table(:bookings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :offer_id, references(:offers, type: :binary_id)
      add :listing_id, references(:listings, type: :binary_id), null: false
      add :customer_id, references(:users, type: :binary_id), null: false
      add :provider_id, references(:users, type: :binary_id), null: false
      add :status, :string, default: "requested"
      add :outcome_notes, :string
      timestamps(type: :utc_datetime)
    end

    create table(:quotes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :listing_id, references(:listings, type: :binary_id, on_delete: :delete_all),
        null: false

      add :requester_id, references(:users, type: :binary_id), null: false
      add :amount_minor, :integer
      add :currency, :string, default: "UGX"
      add :notes, :string
      add :status, :string, default: "requested"
      timestamps(type: :utc_datetime)
    end

    create table(:broker_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :listing_id, references(:listings, type: :binary_id, on_delete: :delete_all),
        null: false

      add :broker_id, references(:users, type: :binary_id), null: false
      add :status, :string, default: "pending"
      timestamps(type: :utc_datetime)
    end

    create table(:brokerage_agreements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :listing_id, references(:listings, type: :binary_id), null: false
      add :broker_id, references(:users, type: :binary_id), null: false
      add :principal_id, references(:users, type: :binary_id), null: false
      add :version, :integer, default: 1
      add :terms_snapshot, :map
      add :status, :string, default: "pending"
      add :broker_accepted_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create table(:referrals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :agreement_id,
          references(:brokerage_agreements, type: :binary_id, on_delete: :delete_all), null: false

      add :listing_id, references(:listings, type: :binary_id), null: false
      add :buyer_consent_at, :utc_datetime
      add :consent_ref, :string
      add :contact_key, :string
      add :attribution, :string, default: "pending"
      add :evidence, :string
      add :expires_at, :utc_datetime
      add :contest_deadline, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:referrals, [:contact_key, :listing_id])

    create table(:deal_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :referral_id, references(:referrals, type: :binary_id, on_delete: :delete_all),
        null: false

      add :actor_id, references(:users, type: :binary_id)
      add :milestone, :string
      add :evidence_refs, {:array, :string}, default: []
      timestamps(type: :utc_datetime)
    end

    create table(:commission_claims, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :referral_id, references(:referrals, type: :binary_id, on_delete: :delete_all),
        null: false

      add :trigger_key, :string, null: false
      add :amount_minor, :integer, null: false
      add :currency, :string, null: false
      add :status, :string, default: "expected"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:commission_claims, [:trigger_key])

    create table(:payment_records, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :claim_id, references(:commission_claims, type: :binary_id, on_delete: :delete_all),
        null: false

      add :reported_by, references(:users, type: :binary_id)
      add :acknowledged_by, references(:users, type: :binary_id)
      add :amount_minor, :integer
      add :reported_at, :utc_datetime
      add :acknowledged_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :subject_type, :string
      add :subject_id, :string
      add :participant_ids, {:array, :string}, default: []
      timestamps(type: :utc_datetime)
    end

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :binary_id), null: false
      add :body, :string
      add :attachment_ref, :string
      timestamps(type: :utc_datetime)
    end

    create table(:reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reporter_id, references(:users, type: :binary_id)
      add :target_type, :string
      add :target_id, :string
      add :reason, :string
      add :status, :string, default: "open"
      timestamps(type: :utc_datetime)
    end

    create table(:disputes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reporter_id, references(:users, type: :binary_id)
      add :booking_id, references(:bookings, type: :binary_id)
      add :referral_id, references(:referrals, type: :binary_id)
      add :claim_id, references(:commission_claims, type: :binary_id)
      add :reason, :string
      add :evidence_refs, {:array, :string}, default: []
      add :status, :string, default: "open"
      timestamps(type: :utc_datetime)
    end

    create table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, :binary_id
      add :action, :string, null: false
      add :entity, :string
      add :entity_id, :string
      add :metadata, :map
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :kind, :string
      add :payload, :map
      add :dedupe_key, :string
      add :delivered_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:notifications, [:dedupe_key])

    create table(:idempotency_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :user_id, :binary_id
      add :response, :map
      timestamps(type: :utc_datetime)
    end

    create unique_index(:idempotency_keys, [:key, :user_id])

    create table(:uploads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uploader_id, references(:users, type: :binary_id)
      add :filename, :string
      add :content_type, :string
      add :size, :integer
      add :ref, :string
      add :private, :boolean, default: true
      timestamps(type: :utc_datetime)
    end
  end
end
