defmodule Backend.Schemas.User do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :phone, :string
    field :role, :string, default: "customer"
    field :is_worker, :boolean, default: false
    field :is_provider, :boolean, default: false
    field :is_customer, :boolean, default: true
    field :is_seller, :boolean, default: false
    field :is_employer, :boolean, default: false
    field :is_broker, :boolean, default: false
    field :is_staff, :boolean, default: false
    field :staff_role, :string
    field :status, :string, default: "active"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [
        :phone,
        :role,
        :is_worker,
        :is_provider,
        :is_customer,
        :is_seller,
        :is_employer,
        :is_broker,
        :is_staff,
        :staff_role,
        :status
      ])
      |> validate_required([:phone])
      |> unique_constraint(:phone)
end

defmodule Backend.Schemas.OtpCode do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "otp_codes" do
    field :phone, :string
    field :code_hash, :string
    field :expires_at, :utc_datetime
    field :attempts, :integer, default: 0
    field :used_at, :utc_datetime
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:phone, :code_hash, :expires_at, :attempts, :used_at])
      |> validate_required([:phone, :code_hash, :expires_at])
end

defmodule Backend.Schemas.Profile do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "profiles" do
    field :user_id, :binary_id
    field :display_name, :string
    field :skills, {:array, :string}, default: []
    field :service_areas, {:array, :string}, default: []
    field :availability, :string
    field :bio, :string
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:user_id, :display_name, :skills, :service_areas, :availability, :bio])
      |> validate_required([:user_id])
end

defmodule Backend.Schemas.Category do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "categories" do
    field :key, :string
    field :name, :string
    field :kind, :string
    field :pilot_enabled, :boolean, default: false
    field :gate_status, :string, default: "open"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:key, :name, :kind, :pilot_enabled, :gate_status])
      |> validate_required([:key])
      |> unique_constraint(:key)
end

defmodule Backend.Schemas.Listing do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "listings" do
    field :owner_id, :binary_id
    field :category_id, :binary_id
    field :title, :string
    field :description, :string
    field :kind, :string, default: "work"
    field :pay_amount_minor, :integer
    field :pay_basis, :string
    field :currency, :string, default: "UGX"
    field :location_text, :string
    field :coarse_location, :string
    field :status, :string, default: "draft"
    field :version, :integer, default: 1
    field :commission_type, :string
    field :commission_value_minor, :integer
    field :commission_bps, :integer
    field :commission_currency, :string, default: "UGX"
    field :commission_version, :integer, default: 1
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [
        :owner_id,
        :category_id,
        :title,
        :description,
        :kind,
        :pay_amount_minor,
        :pay_basis,
        :currency,
        :location_text,
        :coarse_location,
        :status,
        :version,
        :commission_type,
        :commission_value_minor,
        :commission_bps,
        :commission_currency,
        :commission_version
      ])
      |> validate_required([:owner_id, :category_id, :title, :kind])
      |> validate_inclusion(:kind, ["work", "service", "deal"])
      |> validate_inclusion(:status, [
        "draft",
        "review",
        "published",
        "paused",
        "closed",
        "rejected"
      ])
end

defmodule Backend.Schemas.ListingVersion do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "listing_versions" do
    field :listing_id, :binary_id
    field :version, :integer
    field :snapshot, :map
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:listing_id, :version, :snapshot])
      |> validate_required([:listing_id, :version])
end

defmodule Backend.Schemas.Application do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "applications" do
    field :listing_id, :binary_id
    field :applicant_id, :binary_id
    field :cover_note, :string
    field :status, :string, default: "submitted"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:listing_id, :applicant_id, :cover_note, :status])
      |> validate_required([:listing_id, :applicant_id])
end

defmodule Backend.Schemas.Offer do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "offers" do
    field :application_id, :binary_id
    field :version, :integer, default: 1
    field :pay_minor, :integer
    field :scope_text, :string
    field :status, :string, default: "proposed"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:application_id, :version, :pay_minor, :scope_text, :status])
      |> validate_required([:application_id])
end

defmodule Backend.Schemas.Booking do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "bookings" do
    field :offer_id, :binary_id
    field :listing_id, :binary_id
    field :customer_id, :binary_id
    field :provider_id, :binary_id
    field :status, :string, default: "requested"
    field :outcome_notes, :string
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:offer_id, :listing_id, :customer_id, :provider_id, :status, :outcome_notes])
      |> validate_required([:listing_id, :customer_id, :provider_id])
end

defmodule Backend.Schemas.Quote do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "quotes" do
    field :listing_id, :binary_id
    field :requester_id, :binary_id
    field :amount_minor, :integer
    field :currency, :string, default: "UGX"
    field :notes, :string
    field :status, :string, default: "requested"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:listing_id, :requester_id, :amount_minor, :currency, :notes, :status])
      |> validate_required([:listing_id, :requester_id])
end

defmodule Backend.Schemas.BrokerRequest do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "broker_requests" do
    field :listing_id, :binary_id
    field :broker_id, :binary_id
    field :status, :string, default: "pending"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:listing_id, :broker_id, :status])
      |> validate_required([:listing_id, :broker_id])
end

defmodule Backend.Schemas.BrokerageAgreement do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "brokerage_agreements" do
    field :listing_id, :binary_id
    field :broker_id, :binary_id
    field :principal_id, :binary_id
    field :version, :integer, default: 1
    field :terms_snapshot, :map
    field :status, :string, default: "pending"
    field :broker_accepted_at, :utc_datetime
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [
        :listing_id,
        :broker_id,
        :principal_id,
        :version,
        :terms_snapshot,
        :status,
        :broker_accepted_at
      ])
      |> validate_required([:listing_id, :broker_id, :principal_id])
end

defmodule Backend.Schemas.Referral do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "referrals" do
    field :agreement_id, :binary_id
    field :listing_id, :binary_id
    field :buyer_consent_at, :utc_datetime
    field :consent_ref, :string
    field :contact_key, :string
    field :attribution, :string, default: "pending"
    field :evidence, :string
    field :expires_at, :utc_datetime
    field :contest_deadline, :utc_datetime
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [
        :agreement_id,
        :listing_id,
        :buyer_consent_at,
        :consent_ref,
        :contact_key,
        :attribution,
        :evidence,
        :expires_at,
        :contest_deadline
      ])
      |> validate_required([:agreement_id, :listing_id, :contact_key])
end

defmodule Backend.Schemas.DealEvent do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "deal_events" do
    field :referral_id, :binary_id
    field :actor_id, :binary_id
    field :milestone, :string
    field :evidence_refs, {:array, :string}, default: []
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:referral_id, :actor_id, :milestone, :evidence_refs])
      |> validate_required([:referral_id, :milestone])
end

defmodule Backend.Schemas.CommissionClaim do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "commission_claims" do
    field :referral_id, :binary_id
    field :trigger_key, :string
    field :amount_minor, :integer
    field :currency, :string
    field :status, :string, default: "expected"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:referral_id, :trigger_key, :amount_minor, :currency, :status])
      |> validate_required([:referral_id, :trigger_key, :amount_minor, :currency])
      |> unique_constraint(:trigger_key)
end

defmodule Backend.Schemas.PaymentRecord do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "payment_records" do
    field :claim_id, :binary_id
    field :reported_by, :binary_id
    field :acknowledged_by, :binary_id
    field :amount_minor, :integer
    field :reported_at, :utc_datetime
    field :acknowledged_at, :utc_datetime
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [
        :claim_id,
        :reported_by,
        :acknowledged_by,
        :amount_minor,
        :reported_at,
        :acknowledged_at
      ])
      |> validate_required([:claim_id])
end

defmodule Backend.Schemas.Conversation do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "conversations" do
    field :subject_type, :string
    field :subject_id, :string
    field :participant_ids, {:array, :string}, default: []
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:subject_type, :subject_id, :participant_ids])
      |> validate_required([:participant_ids])
end

defmodule Backend.Schemas.Message do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "messages" do
    field :conversation_id, :binary_id
    field :sender_id, :binary_id
    field :body, :string
    field :attachment_ref, :string
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:conversation_id, :sender_id, :body, :attachment_ref])
      |> validate_required([:conversation_id, :sender_id])
end

defmodule Backend.Schemas.Report do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "reports" do
    field :reporter_id, :binary_id
    field :target_type, :string
    field :target_id, :string
    field :reason, :string
    field :status, :string, default: "open"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:reporter_id, :target_type, :target_id, :reason, :status])
      |> validate_required([:target_type, :target_id, :reason])
end

defmodule Backend.Schemas.Dispute do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "disputes" do
    field :reporter_id, :binary_id
    field :booking_id, :binary_id
    field :referral_id, :binary_id
    field :claim_id, :binary_id
    field :reason, :string
    field :evidence_refs, {:array, :string}, default: []
    field :status, :string, default: "open"
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [
        :reporter_id,
        :booking_id,
        :referral_id,
        :claim_id,
        :reason,
        :evidence_refs,
        :status
      ])
      |> validate_required([:reason])
end

defmodule Backend.Schemas.AuditEvent do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "audit_events" do
    field :actor_id, :binary_id
    field :action, :string
    field :entity, :string
    field :entity_id, :string
    field :metadata, :map
    timestamps(updated_at: false)
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:actor_id, :action, :entity, :entity_id, :metadata])
      |> validate_required([:action])
end

defmodule Backend.Schemas.Notification do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "notifications" do
    field :user_id, :binary_id
    field :kind, :string
    field :payload, :map
    field :dedupe_key, :string
    field :delivered_at, :utc_datetime
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:user_id, :kind, :payload, :dedupe_key, :delivered_at])
      |> validate_required([:user_id, :kind])
      |> unique_constraint(:dedupe_key)
end

defmodule Backend.Schemas.Review do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "reviews" do
    field :reviewer_id, :binary_id
    field :reviewee_id, :binary_id
    field :listing_id, :binary_id
    field :rating, :integer
    field :body, :string
    timestamps()
  end

  def changeset(u, a) do
    u
    |> cast(a, [:reviewer_id, :reviewee_id, :listing_id, :rating, :body])
    |> validate_required([:reviewer_id, :reviewee_id, :rating])
    |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
  end
end

defmodule Backend.Schemas.IdempotencyKey do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "idempotency_keys" do
    field :key, :string
    field :user_id, :binary_id
    field :response, :map
    timestamps()
  end

  def changeset(u, a), do: u |> cast(a, [:key, :user_id, :response]) |> validate_required([:key])
end

defmodule Backend.Schemas.Upload do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "uploads" do
    field :uploader_id, :binary_id
    field :filename, :string
    field :content_type, :string
    field :size, :integer
    field :ref, :string
    field :private, :boolean, default: true
    timestamps()
  end

  def changeset(u, a),
    do:
      u
      |> cast(a, [:uploader_id, :filename, :content_type, :size, :ref, :private])
      |> validate_required([:filename, :content_type, :size, :ref])
end
