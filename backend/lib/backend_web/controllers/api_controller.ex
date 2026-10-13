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
        conn
        |> put_status(429)
        |> json(%{error: %{code: "rate_limited", message: "Too many codes"}})

      {:ok, %{code: code}} ->
        base = %{message: "If the number is registered, a code was sent"}
        resp = if Mix.env() == :prod, do: base, else: Map.put(base, :code, code)
        json(conn, %{data: resp})
    end
  end

  def verify_code(conn, %{"phone" => phone, "code" => code}) do
    case Accounts.verify_code(phone, code) do
      {:error, :expired} ->
        conn |> put_status(422) |> json(%{error: %{code: "expired", message: "Code expired"}})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: %{code: "invalid", message: "Invalid code"}})

      {:ok, user} ->
        json(conn, %{data: %{token: Accounts.token_for(user), user: Helpers.render_model(user)}})
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
        conn
        |> put_status(404)
        |> json(%{error: %{code: "not_found", message: "Listing not available"}})

      {:ok, _} ->
        l = Repo.get!(Listing, id)

        if l.status == "published" or
             (conn.assigns[:current_user] && conn.assigns.current_user.id == l.owner_id) do
          json(conn, %{data: Helpers.public_listing(l)})
        else
          conn
          |> put_status(404)
          |> json(%{error: %{code: "not_found", message: "Listing not available"}})
        end
    end
  end

  def profile_public(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      :error ->
        conn
        |> put_status(404)
        |> json(%{error: %{code: "not_found", message: "Profile not found"}})

      {:ok, _} ->
        case Helpers.owner_public(id) do
          nil ->
            conn
            |> put_status(404)
            |> json(%{error: %{code: "not_found", message: "Profile not found"}})

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
      conn
      |> put_status(422)
      |> json(%{error: %{code: "invalid", message: "Cannot review yourself"}})
    else
      case %Backend.Schemas.Review{}
           |> Backend.Schemas.Review.changeset(Map.put(params, "reviewer_id", uid))
           |> Backend.Repo.insert() do
        {:ok, r} ->
          conn |> put_status(201) |> json(%{data: Helpers.render_model(r)})

        {:error, _cs} ->
          conn |> put_status(422) |> json(%{error: %{code: "invalid", message: "Invalid review"}})
      end
    end
  end

  def listing_create(conn, params) do
    case Catalog.create_listing(conn.assigns.current_user.id, params) do
      {:error, :gated} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "category_gated", message: "Category not enabled"}})

      {:ok, l} ->
        conn |> put_status(201) |> json(%{data: Helpers.render_model(l)})

      {:error, cs} ->
        conn
        |> put_status(422)
        |> json(%{
          error: %{
            code: "invalid",
            message: "Invalid",
            fields: cs.errors |> Enum.map(fn {k, {m, _}} -> %{field: k, message: m} end)
          }
        })
    end
  end

  def listing_update(conn, %{"id" => id} = params) do
    l = Repo.get!(Listing, id)

    if l.owner_id != conn.assigns.current_user.id,
      do: conn |> put_status(403) |> json(%{error: %{code: "forbidden", message: "Not owner"}}),
      else:
        (case Catalog.update_listing(l, Map.drop(params, ["id"])) do
           {:ok, l2} ->
             json(conn, %{data: Helpers.render_model(l2)})

           {:error, _cs} ->
             conn |> put_status(422) |> json(%{error: %{code: "invalid", message: "Invalid"}})
         end)
  end

  def listing_publish(conn, %{"id" => id}) do
    l = Repo.get!(Listing, id)

    if l.owner_id != conn.assigns.current_user.id,
      do: conn |> put_status(403) |> json(%{error: %{code: "forbidden", message: "Not owner"}}),
      else:
        (case Catalog.gate_check!(l.category_id) do
           {:error, _} ->
             conn
             |> put_status(422)
             |> json(%{error: %{code: "category_gated", message: "Category gated"}})

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
      do:
        conn |> put_status(422) |> json(%{error: %{code: "closed", message: "Listing not open"}}),
      else:
        (case Work.apply(l, conn.assigns.current_user.id, Map.take(params, ["cover_note"])) do
           {:error, :self_apply} ->
             conn
             |> put_status(422)
             |> json(%{error: %{code: "self_apply", message: "Cannot apply to own listing"}})

           {:ok, a} ->
             conn |> put_status(201) |> json(%{data: Helpers.render_model(a)})
         end)
  end

  def offer(conn, %{"application_id" => aid} = params) do
    app = Repo.get!(Application, aid)
    l = Repo.get!(Listing, app.listing_id)

    if l.owner_id != conn.assigns.current_user.id,
      do: conn |> put_status(403) |> json(%{error: %{code: "forbidden", message: "Owner only"}}),
      else:
        (case Work.make_offer(app, Map.take(params, ["pay_minor", "scope_text"])) do
           {:ok, o} ->
             conn |> put_status(201) |> json(%{data: Helpers.render_model(o)})

           {:error, _} ->
             conn |> put_status(422) |> json(%{error: %{code: "invalid", message: "Invalid"}})
         end)
  end

  def offer_accept(conn, %{"offer_id" => oid}) do
    o = Repo.get!(Offer, oid)
    app = Repo.get!(Application, o.application_id)
    uid = conn.assigns.current_user.id

    if uid != app.applicant_id,
      do:
        conn |> put_status(403) |> json(%{error: %{code: "forbidden", message: "Not applicant"}}),
      else:
        (case Work.accept_offer(o, uid) do
           {:ok, %{offer: o2, booking: b}} ->
             json(conn, %{
               data: %{offer: Helpers.render_model(o2), booking: Helpers.render_model(b)}
             })

           {:error, :bad_state} ->
             conn
             |> put_status(422)
             |> json(%{error: %{code: "bad_state", message: "Offer not proposed"}})
         end)
  end

  def booking_event(conn, %{"booking_id" => bid} = params) do
    b = Repo.get!(Booking, bid)
    uid = conn.assigns.current_user.id

    if uid not in [b.customer_id, b.provider_id],
      do:
        conn
        |> put_status(403)
        |> json(%{error: %{code: "forbidden", message: "Not participant"}}),
      else:
        (case Work.booking_event(b, params["to"], params["outcome_notes"]) do
           {:ok, b2} ->
             json(conn, %{data: Helpers.render_model(b2)})

           {:error, :bad_transition} ->
             conn
             |> put_status(422)
             |> json(%{error: %{code: "bad_transition", message: "Illegal transition"}})
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
        conn |> put_status(422) |> json(%{error: %{code: "invalid", message: "Invalid"}})
    end
  end

  # BROKERAGE
  def broker_request(conn, %{"listing_id" => lid}) do
    {:ok, r} = Brokerage.request_access(lid, conn.assigns.current_user.id)
    conn |> put_status(201) |> json(%{data: Helpers.render_model(r)})
  end

  def broker_approve(conn, %{"id" => id}) do
    req = Repo.get!(BrokerRequest, id)

    case Brokerage.approve(req, conn.assigns.current_user.id) do
      {:error, :forbidden} ->
        conn |> put_status(403) |> json(%{error: %{code: "forbidden", message: "Principal only"}})

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
            conn
            |> put_status(403)
            |> json(%{error: %{code: "forbidden", message: "Broker only"}})

          {:error, :bad_state} ->
            conn
            |> put_status(422)
            |> json(%{error: %{code: "bad_state", message: "Already decided"}})

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
            conn
            |> put_status(403)
            |> json(%{error: %{code: "not_authorised", message: "Agreement not active"}})

          {:error, :consent_required} ->
            conn
            |> put_status(422)
            |> json(%{
              error: %{code: "consent_required", message: "Buyer consent + consent_ref required"}
            })

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
        conn |> put_status(403) |> json(%{error: %{code: "forbidden", message: "Principal only"}})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: %{code: "bad_state", message: "Cannot decide"}})

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

      {:error, _cs} ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "duplicate", message: "Claim already exists for trigger"}})
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
        {:ok, pr} = Brokerage.report_payment(claim, uid, params["amount_minor"])
        resp = %{data: Helpers.render_model(pr)}
        ChatOps.store_idem(key, uid, resp)
        conn |> put_status(201) |> json(resp)
    end
  end

  def claim_ack(conn, %{"id" => id}) do
    claim = Repo.get!(CommissionClaim, id)
    {:ok, pr} = Brokerage.acknowledge(claim, conn.assigns.current_user.id)
    json(conn, %{data: Helpers.render_model(pr)})
  end

  def earnings(conn, _) do
    uid = conn.assigns.current_user.id
    import Ecto.Query

    claims =
      Repo.all(
        from c in CommissionClaim,
          join: r in Referral,
          on: r.id == c.referral_id,
          join: a in BrokerageAgreement,
          on: a.id == r.agreement_id,
          where: a.broker_id == ^uid
      )

    {exp, earn} = Enum.split_with(claims, &(&1.status == "expected"))

    json(conn, %{
      data: %{
        expected: Enum.map(exp, &Helpers.render_model/1),
        earned: Enum.map(earn, &Helpers.render_model/1)
      }
    })
  end

  # MESSAGING
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
            conn
            |> put_status(403)
            |> json(%{error: %{code: "forbidden", message: "Not a participant"}})

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
        conn
        |> put_status(403)
        |> json(%{error: %{code: "forbidden", message: "Not a participant"}})

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
        conn |> put_status(422) |> json(%{error: %{code: "invalid", message: "Cannot decide"}})
    end
  end

  # UPLOADS
  def upload(conn, params) do
    allowed = ["image/jpeg", "image/png", "image/webp"]
    ct = params["content_type"] || "image/jpeg"
    size = params["size"] || 1000

    cond do
      ct not in allowed ->
        conn
        |> put_status(422)
        |> json(%{error: %{code: "file_type", message: "Only jpg/png/webp"}})

      size > 5 * 1024 * 1024 ->
        conn |> put_status(422) |> json(%{error: %{code: "file_size", message: "Max 5MB"}})

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
