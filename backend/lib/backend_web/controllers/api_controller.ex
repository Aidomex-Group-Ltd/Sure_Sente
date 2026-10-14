defmodule BackendWeb.ApiController do
  use BackendWeb, :controller
  alias Backend.{Repo, Accounts, Catalog, Work, Brokerage, ChatOps}

  alias Backend.Schemas.{
    Listing,
    Application,
    Offer,
    Booking,
    BrokerRequest,
    BrokerageAgreement,
    Referral,
    CommissionClaim,
    Conversation
  }

  alias BackendWeb.Helpers
  # AUTH
  def request_code(conn, %{"phone" => phone}) do
    case Accounts.request_code(phone) do
      {:error, :rate_limited} ->
        Helpers.err(conn, 429, "rate_limited", "Too many codes")

      {:ok, %{code: code}} ->
        base = %{message: "If the number is registered, a code was sent"}
        resp = if Mix.env() == :prod, do: base, else: Map.put(base, :code, code)
        json(conn, %{data: resp})
    end
  end

  def verify_code(conn, %{"phone" => phone, "code" => code} = params) do
    consent =
      params
      |> Map.take(["terms_accepted", "date_of_birth"])
      |> Map.put("client_ip", conn.remote_ip |> :inet.ntoa() |> to_string())

    case Accounts.verify_code(phone, code, consent) do
      {:error, :expired} ->
        Helpers.err(conn, 422, "expired", "Code expired")

      {:error, :locked} ->
        Helpers.err(conn, 429, "locked", "Too many attempts. Request a new code")

      {:error, {:legal_gate, changeset}} ->
        fields =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

        Helpers.err(
          conn,
          422,
          "legal_gate",
          "You must accept the Terms and be 18+ to continue.",
          %{fields: fields}
        )

      {:error, _} ->
        Helpers.err(conn, 422, "invalid", "Invalid code")

      {:ok, user} ->
        json(conn, %{data: %{token: Accounts.token_for(user), user: Helpers.render_model(user)}})
    end
  end

  # DPPA Right to Erasure: file a deletion request for your own account.
  def erasure_request(conn, params) do
    case Accounts.request_erasure(conn.assigns.current_user.id, params["reason"]) do
      {:ok, req} ->
        Accounts.audit(
          conn.assigns.current_user.id,
          "privacy.erasure_requested",
          "user",
          conn.assigns.current_user.id,
          %{request_id: req.id}
        )

        json(conn, %{data: %{id: req.id, status: req.status}})

      {:error, changeset} ->
        Helpers.err(conn, 422, "invalid", "Could not file erasure request.", %{
          fields: inspect(changeset.errors)
        })
    end
  end

  def me(conn, _), do: json(conn, %{data: Helpers.render_model(conn.assigns.current_user)})

  def profile_get(conn, _) do
    case Accounts.get_profile(conn.assigns.current_user.id) do
      nil -> json(conn, %{data: nil})
      p -> json(conn, %{data: Helpers.render_model(p)})
    end
  end

  def profile_put(conn, params) do
    {:ok, p} = Accounts.upsert_profile(conn.assigns.current_user.id, params)
    json(conn, %{data: Helpers.render_model(p)})
  end

  # CATEGORIES
  def categories(conn, _) do
    cats =
      Catalog.list_categories()
      |> Enum.filter(&(&1.gate_status != "closed" and &1.pilot_enabled))
      |> Enum.map(&Helpers.render_model/1)

    json(conn, %{data: cats})
  end

  def categories_all(conn, _) do
    json(conn, %{data: Enum.map(Catalog.list_categories(), &Helpers.render_model/1)})
  end

  # LISTINGS
  def listings_index(conn, params) do
    limit = min(String.to_integer(Map.get(params, "limit", "20")), 50)
    {rows, next} = Catalog.list_published(params, limit, Map.get(params, "cursor"))
    json(conn, %{data: Enum.map(rows, &Helpers.public_listing/1), meta: %{next_cursor: next}})
  end

  def listing_show(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      :error ->
        Helpers.err(conn, 404, "not_found", "Listing not available")

      {:ok, _} ->
        l = Repo.get!(Listing, id)

        if l.status == "published" or
             (conn.assigns[:current_user] && conn.assigns.current_user.id == l.owner_id) do
          json(conn, %{data: Helpers.public_listing(l)})
        else
          Helpers.err(conn, 404, "not_found", "Listing not available")
        end
    end
  end

  def profile_public(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      :error ->
        Helpers.err(conn, 404, "not_found", "Profile not found")

      {:ok, _} ->
        case Helpers.owner_public(id) do
          nil ->
            Helpers.err(conn, 404, "not_found", "Profile not found")

          pub ->
            json(conn, %{data: pub})
        end
    end
  end

  def reviews_for_listing(conn, %{"id" => id}) do
    import Ecto.Query

    rows =
      Backend.Repo.all(
        from r in Backend.Schemas.Review,
          where: r.listing_id == ^id,
          order_by: [desc: r.inserted_at],
          limit: 20
      )

    json(conn, %{data: Enum.map(rows, &Helpers.render_model/1)})
  end

  def reviews_for_profile(conn, %{"id" => id}) do
    import Ecto.Query

    rows =
      Backend.Repo.all(
        from r in Backend.Schemas.Review,
          where: r.reviewee_id == ^id,
          order_by: [desc: r.inserted_at],
          limit: 20
      )

    json(conn, %{data: Enum.map(rows, &Helpers.render_model/1)})
  end

  def review_create(conn, params) do
    import Ecto.Query
    uid = conn.assigns.current_user.id

    if params["reviewee_id"] == uid do
      Helpers.err(conn, 422, "invalid", "Cannot review yourself")
    else
      # 08-TRUST: one review per reviewer/reviewee pair (per listing, or per
      # profile when no listing). Friendly 422 before the DB constraint.
      dup =
        if params["listing_id"] do
          Backend.Repo.one(
            from r in Backend.Schemas.Review,
              where:
                r.reviewer_id == ^uid and r.reviewee_id == ^params["reviewee_id"] and
                  r.listing_id == ^params["listing_id"],
              limit: 1
          )
        else
          Backend.Repo.one(
            from r in Backend.Schemas.Review,
              where:
                r.reviewer_id == ^uid and r.reviewee_id == ^params["reviewee_id"] and
                  is_nil(r.listing_id),
              limit: 1
          )
        end

      cond do
        dup ->
          Helpers.err(conn, 422, "duplicate", "Already reviewed")

        true ->
          case %Backend.Schemas.Review{}
               |> Backend.Schemas.Review.changeset(Map.put(params, "reviewer_id", uid))
               |> Backend.Repo.insert() do
            {:ok, r} ->
              conn |> put_status(201) |> json(%{data: Helpers.render_model(r)})

            {:error, cs} ->
              if Enum.any?(cs.errors, fn {_, {m, _}} -> m == "already reviewed" end) do
                Helpers.err(conn, 422, "duplicate", "Already reviewed")
              else
                Helpers.err(conn, 422, "invalid", "Invalid review")
              end
          end
      end
    end
  end

  def listing_create(conn, params) do
    case Catalog.create_listing(conn.assigns.current_user.id, params) do
      {:error, :gated} ->
        Helpers.err(conn, 422, "category_gated", "Category not enabled")

      {:ok, l} ->
        conn |> put_status(201) |> json(%{data: Helpers.render_model(l)})

      {:error, cs} ->
        Helpers.err(conn, 422, "invalid", "Invalid", %{
          fields: cs.errors |> Enum.map(fn {k, {m, _}} -> %{field: k, message: m} end)
        })
    end
  end

  def listing_update(conn, %{"id" => id} = params) do
    l = Repo.get!(Listing, id)

    if l.owner_id != conn.assigns.current_user.id,
      do: Helpers.err(conn, 403, "forbidden", "Not owner"),
      else:
        (case Catalog.update_listing(l, Map.drop(params, ["id"])) do
           {:ok, l2} ->
             json(conn, %{data: Helpers.render_model(l2)})

           {:error, _cs} ->
             Helpers.err(conn, 422, "invalid", "Invalid")
         end)
  end

  def listing_publish(conn, %{"id" => id}) do
    l = Repo.get!(Listing, id)

    if l.owner_id != conn.assigns.current_user.id,
      do: Helpers.err(conn, 403, "forbidden", "Not owner"),
      else:
        (case Catalog.gate_check!(l.category_id) do
           {:error, _} ->
             Helpers.err(conn, 422, "category_gated", "Category gated")

           {:ok, _} ->
             {:ok, l2} = Catalog.publish(l)
             json(conn, %{data: Helpers.render_model(l2)})
         end)
  end

  def listing_draft(conn, %{"id" => id}) do
    l = Repo.get!(Listing, id)
    {:ok, l2} = Catalog.update_listing(l, %{"status" => "draft"})
    json(conn, %{data: Helpers.render_model(l2)})
  end

  # WORK
  def apply(conn, %{"listing_id" => lid} = params) do
    l = Repo.get!(Listing, lid)

    if l.status != "published",
      do: Helpers.err(conn, 422, "closed", "Listing not open"),
      else:
        (case Work.apply(l, conn.assigns.current_user.id, Map.take(params, ["cover_note"])) do
           {:error, :self_apply} ->
             Helpers.err(conn, 422, "self_apply", "Cannot apply to own listing")

           {:ok, a} ->
             conn |> put_status(201) |> json(%{data: Helpers.render_model(a)})
         end)
  end

  def offer(conn, %{"application_id" => aid} = params) do
    app = Repo.get!(Application, aid)
    l = Repo.get!(Listing, app.listing_id)

    if l.owner_id != conn.assigns.current_user.id,
      do: Helpers.err(conn, 403, "forbidden", "Owner only"),
      else:
        (case Work.make_offer(app, Map.take(params, ["pay_minor", "scope_text"])) do
           {:ok, o} ->
             conn |> put_status(201) |> json(%{data: Helpers.render_model(o)})

           {:error, _} ->
             Helpers.err(conn, 422, "invalid", "Invalid")
         end)
  end

  def offer_accept(conn, %{"offer_id" => oid}) do
    o = Repo.get!(Offer, oid)
    app = Repo.get!(Application, o.application_id)
    uid = conn.assigns.current_user.id

    if uid != app.applicant_id,
      do: Helpers.err(conn, 403, "forbidden", "Not applicant"),
      else:
        (case Work.accept_offer(o, uid) do
           {:ok, %{offer: o2, booking: b}} ->
             json(conn, %{
               data: %{offer: Helpers.render_model(o2), booking: Helpers.render_model(b)}
             })

           {:error, :bad_state} ->
             Helpers.err(conn, 422, "bad_state", "Offer not proposed")
         end)
  end

  # Booking / referral timelines (03-IA deep links /bookings/:id, /referrals/:id).
  # Participant- or principal-scoped; outsiders get 403, never the record.
  def booking_show(conn, %{"id" => id}) do
    b = Repo.get!(Booking, id)
    uid = conn.assigns.current_user.id

    if uid in [b.customer_id, b.provider_id] do
      json(conn, %{data: Helpers.render_model(b)})
    else
      Helpers.err(conn, 403, "forbidden", "Not participant")
    end
  end

  def referral_show(conn, %{"id" => id}) do
    r = Repo.get!(Referral, id)
    ag = Repo.get!(BrokerageAgreement, r.agreement_id)
    uid = conn.assigns.current_user.id

    if uid in [ag.principal_id, ag.broker_id] do
      json(conn, %{data: Helpers.render_model(r)})
    else
      Helpers.err(conn, 403, "forbidden", "Not a party to this referral")
    end
  end

  def booking_event(conn, %{"booking_id" => bid} = params) do
    b = Repo.get!(Booking, bid)
    uid = conn.assigns.current_user.id

    if uid not in [b.customer_id, b.provider_id],
      do: Helpers.err(conn, 403, "forbidden", "Not participant"),
      else:
        (case Work.booking_event(b, params["to"], params["outcome_notes"]) do
           {:ok, b2} ->
             json(conn, %{data: Helpers.render_model(b2)})

           {:error, :bad_transition} ->
             Helpers.err(conn, 422, "bad_transition", "Illegal transition")
         end)
  end

  def quote_create(conn, %{"listing_id" => lid} = params) do
    case Work.create_quote(
           lid,
           conn.assigns.current_user.id,
           Map.take(params, ["amount_minor", "currency", "notes"])
         ) do
      {:ok, q} ->
        conn |> put_status(201) |> json(%{data: Helpers.render_model(q)})

      {:error, _} ->
        Helpers.err(conn, 422, "invalid", "Invalid")
    end
  end

  # BROKERAGE
  def broker_request(conn, %{"listing_id" => lid}) do
    case Brokerage.request_access(lid, conn.assigns.current_user.id) do
      {:error, :forbidden} ->
        Helpers.err(conn, 403, "forbidden", "Cannot request brokerage on your own listing")

      {:ok, r} ->
        conn |> put_status(201) |> json(%{data: Helpers.render_model(r)})
    end
  end

  def broker_approve(conn, %{"id" => id}) do
    req = Repo.get!(BrokerRequest, id)

    case Brokerage.approve(req, conn.assigns.current_user.id) do
      {:error, :forbidden} ->
        Helpers.err(conn, 403, "forbidden", "Principal only")

      {:ok, %{agreement: ag}} ->
        json(conn, %{data: Helpers.render_model(ag)})
    end
  end

  def agreement_accept(conn, %{"id" => id}) do
    key = List.first(Plug.Conn.get_req_header(conn, "idempotency-key"))
    uid = conn.assigns.current_user.id

    case ChatOps.check_idem(key, uid) do
      {:hit, resp} ->
        json(conn, resp)

      :miss ->
        ag = Repo.get!(BrokerageAgreement, id)

        case Brokerage.accept_agreement(ag, uid) do
          {:error, :forbidden} ->
            Helpers.err(conn, 403, "forbidden", "Broker only")

          {:error, :bad_state} ->
            Helpers.err(conn, 422, "bad_state", "Already decided")

          {:ok, ag2} ->
            resp = %{data: Helpers.render_model(ag2)}
            ChatOps.store_idem(key, uid, resp)
            json(conn, resp)
        end
    end
  end

  def referral_create(conn, %{"agreement_id" => aid} = params) do
    key = List.first(Plug.Conn.get_req_header(conn, "idempotency-key"))
    uid = conn.assigns.current_user.id

    case ChatOps.check_idem(key, uid) do
      {:hit, resp} ->
        json(conn, resp)

      :miss ->
        ag = Repo.get!(BrokerageAgreement, aid)
        listing_id = params["listing_id"] || ag.listing_id

        case Brokerage.create_referral(ag, listing_id, params) do
          {:error, :not_authorised} ->
            Helpers.err(conn, 403, "not_authorised", "Agreement not active")

          {:error, :consent_required} ->
            Helpers.err(conn, 422, "consent_required", "Buyer consent + consent_ref required")

          {:ok, %{referral: r, duplicate: dup}} ->
            resp = %{data: Map.put(Helpers.render_model(r), "duplicate", dup)}
            ChatOps.store_idem(key, uid, resp)
            conn |> put_status(201) |> json(resp)
        end
    end
  end

  def referral_attr(conn, %{"id" => id} = params) do
    r = Repo.get!(Referral, id)

    case Brokerage.attribute(
           r,
           conn.assigns.current_user.id,
           params["decision"],
           params["evidence"]
         ) do
      {:error, :forbidden} ->
        Helpers.err(conn, 403, "forbidden", "Principal only")

      {:error, _} ->
        Helpers.err(conn, 422, "bad_state", "Cannot decide")

      {:ok, r2} ->
        json(conn, %{data: Helpers.render_model(r2)})
    end
  end

  def referral_outcome(conn, %{"id" => id} = params) do
    r = Repo.get!(Referral, id)
    uid = conn.assigns.current_user.id

    case Brokerage.record_outcome(
           r,
           uid,
           params["milestone"] || "completed",
           params["evidence_refs"],
           params["amount_minor"],
           params["currency"]
         ) do
      {:ok, claim} ->
        conn |> put_status(201) |> json(%{data: Helpers.render_model(claim)})

      {:error, :forbidden} ->
        Helpers.err(conn, 403, "forbidden", "Not a participant")

      {:error, :bad_state} ->
        Helpers.err(conn, 422, "bad_state", "Attribution must be accepted first")

      {:error, _cs} ->
        Helpers.err(conn, 422, "duplicate", "Claim already exists for trigger")
    end
  end

  def claim_report(conn, %{"id" => id} = params) do
    key = List.first(Plug.Conn.get_req_header(conn, "idempotency-key"))
    uid = conn.assigns.current_user.id

    case ChatOps.check_idem(key, uid) do
      {:hit, resp} ->
        json(conn, resp)

      :miss ->
        claim = Repo.get!(CommissionClaim, id)

        case Brokerage.report_payment(claim, uid, params["amount_minor"]) do
          {:error, :forbidden} ->
            Helpers.err(conn, 403, "forbidden", "Payer only")

          {:ok, pr} ->
            resp = %{data: Helpers.render_model(pr)}
            ChatOps.store_idem(key, uid, resp)
            conn |> put_status(201) |> json(resp)
        end
    end
  end

  def claim_ack(conn, %{"id" => id}) do
    claim = Repo.get!(CommissionClaim, id)
    uid = conn.assigns.current_user.id

    case Brokerage.acknowledge(claim, uid) do
      {:error, :forbidden} ->
        Helpers.err(conn, 403, "forbidden", "Payee only")

      {:error, :bad_state} ->
        Helpers.err(conn, 422, "bad_state", "Payment not reported yet")

      {:ok, pr} ->
        json(conn, %{data: Helpers.render_model(pr)})
    end
  end

  # 03-IA /me/earnings: expected, confirmed(earned) and reported-paid amounts,
  # separated from received (acknowledged) per 07-BROKERAGE.
  def earnings(conn, _) do
    uid = conn.assigns.current_user.id
    import Ecto.Query

    rows =
      Repo.all(
        from c in CommissionClaim,
          join: r in Referral,
          on: r.id == c.referral_id,
          join: a in BrokerageAgreement,
          on: a.id == r.agreement_id,
          where: a.broker_id == ^uid,
          select: {c, r.attribution}
      )

    buckets = %{"expected" => [], "earned" => [], "reported" => [], "received" => []}

    groups =
      Enum.reduce(rows, buckets, fn {c, attribution}, acc ->
        key =
          cond do
            attribution != "accepted" -> "expected"
            c.status == "payment_reported" -> "reported"
            c.status == "received" -> "received"
            true -> "earned"
          end

        Map.update(acc, key, [Helpers.render_model(c)], &[Helpers.render_model(c) | &1])
      end)

    json(conn, %{data: groups})
  end

  # 03-IA ownership: workers see their applications; employers see
  # applications to their own listings (Q02: employer alone sees details).
  def applications_index(conn, _) do
    uid = conn.assigns.current_user.id
    import Ecto.Query

    worker =
      Repo.all(
        from a in Application,
          join: l in Listing,
          on: l.id == a.listing_id,
          where: a.applicant_id == ^uid,
          order_by: [desc: a.inserted_at],
          limit: 50,
          select: {a, l}
      )

    owner =
      Repo.all(
        from a in Application,
          join: l in Listing,
          on: l.id == a.listing_id,
          where: l.owner_id == ^uid,
          order_by: [desc: a.inserted_at],
          limit: 50,
          select: {a, l}
      )

    render = fn {a, l} ->
      %{
        "id" => a.id,
        "status" => a.status,
        "cover_note" => a.cover_note,
        "applicant_id" => a.applicant_id,
        "listing_id" => l.id,
        "listing_title" => l.title,
        "listing_kind" => l.kind,
        "listing_status" => l.status,
        "pay_amount_minor" => l.pay_amount_minor,
        "currency" => l.currency,
        "role" => if(uid == a.applicant_id, do: "worker", else: "owner"),
        "inserted_at" => Helpers.render_model(a)["inserted_at"]
      }
    end

    mine = Enum.map(worker, render)
    theirs = Enum.map(owner, render)
    json(conn, %{data: %{applications: Enum.uniq_by(mine ++ theirs, & &1["id"])}})
  end

  # MESSAGING
  # Inbox list: conversations the caller participates in (03-IA /messages).
  def conversations_index(conn, _) do
    uid = conn.assigns.current_user.id
    import Ecto.Query

    rows =
      Repo.all(
        from c in Conversation,
          where: ^uid in c.participant_ids,
          order_by: [desc: c.inserted_at],
          limit: 50
      )

    json(conn, %{data: Enum.map(rows, &Helpers.render_model/1)})
  end

  def conv_create(conn, params) do
    {:ok, c} = ChatOps.create_conversation(conn.assigns.current_user.id, params)
    conn |> put_status(201) |> json(%{data: Helpers.render_model(c)})
  end

  def msg_create(conn, %{"id" => id} = params) do
    key = List.first(Plug.Conn.get_req_header(conn, "idempotency-key"))
    uid = conn.assigns.current_user.id

    case ChatOps.check_idem(key, uid) do
      {:hit, resp} ->
        json(conn, resp)

      :miss ->
        conv = Repo.get!(Conversation, id)

        case ChatOps.send_message(conv, uid, params) do
          {:error, :forbidden} ->
            Helpers.err(conn, 403, "forbidden", "Not a participant")

          {:ok, m} ->
            resp = %{data: Helpers.render_model(m)}
            ChatOps.store_idem(key, uid, resp)
            conn |> put_status(201) |> json(resp)
        end
    end
  end

  def msg_list(conn, %{"id" => id}) do
    conv = Repo.get!(Conversation, id)

    case ChatOps.list_messages(conv, conn.assigns.current_user.id) do
      {:error, :forbidden} ->
        Helpers.err(conn, 403, "forbidden", "Not a participant")

      {:ok, ms} ->
        json(conn, %{data: Enum.map(ms, &Helpers.render_model/1)})
    end
  end

  # REPORTS/DISPUTES
  def report_create(conn, params) do
    {:ok, r} =
      ChatOps.report(
        conn.assigns.current_user.id,
        Map.take(params, ["target_type", "target_id", "reason"])
      )

    conn |> put_status(201) |> json(%{data: Helpers.render_model(r)})
  end

  def dispute_create(conn, params) do
    {:ok, d} =
      ChatOps.dispute(
        conn.assigns.current_user.id,
        Map.take(params, ["booking_id", "referral_id", "claim_id", "reason", "evidence_refs"])
      )

    conn |> put_status(201) |> json(%{data: Helpers.render_model(d)})
  end

  def admin_list(conn, %{"kind" => kind}) do
    mod = if kind == "reports", do: Backend.Schemas.Report, else: Backend.Schemas.Dispute
    json(conn, %{data: Enum.map(Repo.all(mod), &Helpers.render_model/1)})
  end

  def admin_decide(conn, %{"kind" => kind, "id" => id} = params) do
    case ChatOps.decide(
           conn.assigns.current_user.id,
           String.trim_trailing(kind, "s"),
           id,
           params["action"] || "decide",
           params["status"] || "resolved"
         ) do
      {:ok, e} ->
        json(conn, %{data: Helpers.render_model(e)})

      {:error, _} ->
        Helpers.err(conn, 422, "invalid", "Cannot decide")
    end
  end

  # UPLOADS
  def upload(conn, params) do
    allowed = ["image/jpeg", "image/png", "image/webp"]
    ct = params["content_type"] || "image/jpeg"
    size = params["size"] || 1000

    cond do
      ct not in allowed ->
        Helpers.err(conn, 422, "file_type", "Only jpg/png/webp")

      size > 5 * 1024 * 1024 ->
        Helpers.err(conn, 422, "file_size", "Max 5MB")

      true ->
        ref = "uploads/" <> Ecto.UUID.generate() <> "-" <> (params["filename"] || "file")

        {:ok, u} =
          %Backend.Schemas.Upload{}
          |> Backend.Schemas.Upload.changeset(%{
            uploader_id: conn.assigns.current_user.id,
            filename: params["filename"] || "file",
            content_type: ct,
            size: size,
            ref: ref,
            private: true
          })
          |> Repo.insert()

        conn |> put_status(201) |> json(%{data: %{ref: ref, upload: Helpers.render_model(u)}})
    end
  end
end
