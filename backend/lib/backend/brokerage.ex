defmodule Backend.Brokerage do
  import Ecto.Query
  alias Backend.Repo

  alias Backend.Schemas.{
    BrokerRequest,
    BrokerageAgreement,
    Referral,
    DealEvent,
    CommissionClaim,
    PaymentRecord,
    Listing
  }

  def contact_key(phone) do
    secret = Application.get_env(:backend, :hmac_secret, "dev-secret")
    norm = phone |> String.replace(~r/[^0-9+]/, "")
    :crypto.mac(:hmac, :sha256, secret, norm) |> Base.encode16()
  end

  def request_access(listing_id, broker_id) do
    # 12-API: eligible broker only — a seller cannot request brokerage on
    # their own listing (Q05: unauthorised actions denied server-side).
    if Repo.get!(Listing, listing_id).owner_id == broker_id,
      do: {:error, :forbidden},
      else:
        %BrokerRequest{}
        |> BrokerRequest.changeset(%{listing_id: listing_id, broker_id: broker_id})
        |> Repo.insert()
  end

  def approve(req, principal_id) do
    listing = Repo.get!(Listing, req.listing_id)
    if listing.owner_id != principal_id, do: {:error, :forbidden}, else: do_approve(req, listing)
  end

  defp do_approve(req, listing) do
    {:ok, req2} = req |> BrokerRequest.changeset(%{status: "approved"}) |> Repo.update()

    terms = %{
      commission_type: listing.commission_type,
      commission_value_minor: listing.commission_value_minor,
      commission_bps: listing.commission_bps,
      commission_currency: listing.commission_currency || "UGX",
      commission_version: listing.commission_version,
      listing_version: listing.version
    }

    {:ok, ag} =
      %BrokerageAgreement{}
      |> BrokerageAgreement.changeset(%{
        listing_id: listing.id,
        broker_id: req.broker_id,
        principal_id: listing.owner_id,
        version: 1,
        terms_snapshot: terms,
        status: "pending"
      })
      |> Repo.insert()

    {:ok, %{request: req2, agreement: ag}}
  end

  def accept_agreement(ag, broker_id) do
    cond do
      ag.broker_id != broker_id ->
        {:error, :forbidden}

      ag.status != "pending" ->
        {:error, :bad_state}

      true ->
        ag
        |> BrokerageAgreement.changeset(%{
          status: "active",
          broker_accepted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()
    end
  end

  def create_referral(ag, listing_id, attrs) do
    cond do
      ag.status != "active" ->
        {:error, :not_authorised}

      ag.principal_id == ag.broker_id ->
        {:error, :forbidden}

      true ->
        do_ref(ag, listing_id, attrs)
    end
  end

  defp do_ref(ag, listing_id, attrs) do
    consent_at = attrs["buyer_consent_at"]
    consent_ref = attrs["consent_ref"] || attrs["buyer_consent_ref"]
    phone = attrs["buyer_phone"]

    if is_nil(consent_at) or is_nil(consent_ref) or consent_ref == "" do
      {:error, :consent_required}
    else
      key = contact_key(phone || "")

      dup =
        Repo.one(
          from r in Referral,
            where:
              r.contact_key == ^key and r.listing_id == ^listing_id and
                r.attribution in ["pending", "accepted"],
            order_by: [asc: r.inserted_at],
            limit: 1
        )

      cond do
        dup ->
          {:ok, %{referral: dup, duplicate: true}}

        true ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          case %Referral{}
               |> Referral.changeset(%{
                 agreement_id: ag.id,
                 listing_id: listing_id,
                 buyer_consent_at: parse_dt(consent_at),
                 consent_ref: consent_ref,
                 contact_key: key,
                 attribution: "pending",
                 evidence: attrs["evidence"],
                 expires_at: DateTime.add(now, 30 * 86400, :second),
                 contest_deadline: DateTime.add(now, 48 * 3600, :second)
               })
               |> Repo.insert() do
            {:ok, r} -> {:ok, %{referral: r, duplicate: false}}
            e -> e
          end
      end
    end
  end

  defp parse_dt(s) when is_binary(s),
    do:
      (case DateTime.from_iso8601(s) do
         {:ok, dt, _} -> dt
         _ -> DateTime.utc_now() |> DateTime.truncate(:second)
       end)

  defp parse_dt(_), do: DateTime.utc_now() |> DateTime.truncate(:second)

  def attribute(referral, principal_id, decision, evidence) do
    ag = Repo.get!(BrokerageAgreement, referral.agreement_id)

    if ag.principal_id != principal_id,
      do: {:error, :forbidden},
      else: do_attr(referral, decision, evidence)
  end

  defp do_attr(referral, decision, evidence) when decision in ["accept", "accepted"] do
    if referral.attribution != "pending",
      do: {:error, :bad_state},
      else:
        referral
        |> Referral.changeset(%{attribution: "accepted", evidence: evidence || referral.evidence})
        |> Repo.update()
  end

  defp do_attr(referral, "contest", evidence) do
    if referral.attribution != "pending",
      do: {:error, :bad_state},
      else:
        referral
        |> Referral.changeset(%{attribution: "contested", evidence: evidence})
        |> Repo.update()
  end

  defp do_attr(_, _, _), do: {:error, :bad_decision}

  def record_outcome(referral, actor_id, milestone, evidence_refs, amount_minor, currency) do
    ag = Repo.get!(BrokerageAgreement, referral.agreement_id)

    # 12-API: participants only; valid outcome only after attribution accepted
    # (Q05/Q07: no commission claim from unauthorised or unverified leads).
    if actor_id not in [ag.principal_id, ag.broker_id] do
      {:error, :forbidden}
    else
      if referral.attribution != "accepted" do
        {:error, :bad_state}
      else
        trigger = "#{referral.id}:#{milestone}"

        # Deal event + unique claim commit together (11-DATA: unique by
        # referral and qualifying trigger); a duplicate rolls both back.
        Repo.transaction(fn ->
          {:ok, _ev} =
            %DealEvent{}
            |> DealEvent.changeset(%{
              referral_id: referral.id,
              actor_id: actor_id,
              milestone: milestone,
              evidence_refs: evidence_refs || []
            })
            |> Repo.insert()

          %CommissionClaim{}
          |> CommissionClaim.changeset(%{
            referral_id: referral.id,
            trigger_key: trigger,
            amount_minor: amount_minor || 0,
            currency: currency || "UGX",
            status: "earned"
          })
          |> Repo.insert()
          |> elem(1)
        end)
      end
    end
  end

  # 12-API: payment-report is payer only (the selling principal); acknowledge
  # is payee only (the broker). State must move earned → reported → received
  # (Q10: not received until the payee acknowledges).
  def report_payment(claim, payer_id, amount) do
    claim = Repo.get!(CommissionClaim, claim.id)
    r = Repo.get!(Referral, claim.referral_id)
    ag = Repo.get!(BrokerageAgreement, r.agreement_id)

    if ag.principal_id != payer_id or claim.status != "earned",
      do: {:error, :forbidden},
      else: do_report(claim, payer_id, amount)
  end

  defp do_report(claim, payer_id, amount) do
    {:ok, pr} =
      %PaymentRecord{}
      |> PaymentRecord.changeset(%{
        claim_id: claim.id,
        reported_by: payer_id,
        amount_minor: amount,
        reported_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.insert()

    {:ok, _} = claim |> CommissionClaim.changeset(%{status: "payment_reported"}) |> Repo.update()
    {:ok, pr}
  end

  def acknowledge(claim, payee_id) do
    claim = Repo.get!(CommissionClaim, claim.id)

    if claim.status != "payment_reported",
      do: {:error, :bad_state},
      else: do_ack(claim, payee_id)
  end

  defp do_ack(claim, payee_id) do
    r = Repo.get!(Referral, claim.referral_id)
    ag = Repo.get!(BrokerageAgreement, r.agreement_id)

    if ag.broker_id != payee_id,
      do: {:error, :forbidden},
      else: do_ack_payee(claim, payee_id)
  end

  defp do_ack_payee(claim, payee_id) do
    pr =
      Repo.one(
        from p in PaymentRecord,
          where: p.claim_id == ^claim.id,
          order_by: [desc: p.inserted_at],
          limit: 1
      )

    {:ok, pr2} =
      pr
      |> PaymentRecord.changeset(%{
        acknowledged_by: payee_id,
        acknowledged_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()

    {:ok, _} = claim |> CommissionClaim.changeset(%{status: "received"}) |> Repo.update()
    {:ok, pr2}
  end
end
