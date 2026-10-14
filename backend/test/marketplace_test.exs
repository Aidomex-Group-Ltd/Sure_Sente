defmodule Backend.MarketplaceTest do
  use Backend.DataCase, async: false
  alias Backend.{Accounts, Catalog, Work, Brokerage, ChatOps, Repo}
  alias Backend.Schemas.{User, Category, Listing}

  defp user!(phone, extra \\ %{}) do
    {:ok, u} = %User{} |> User.changeset(Map.merge(%{phone: phone}, extra)) |> Repo.insert()
    u
  end

  defp cat!(key, open \\ true) do
    Repo.get_by(Category, key: key) ||
      elem(
        %Category{}
        |> Category.changeset(%{
          key: key,
          name: key,
          kind: "work",
          pilot_enabled: open,
          gate_status: if(open, do: "open", else: "closed")
        })
        |> Repo.insert(),
        1
      )
  end

  test "OTP expiry/replay/rate-limit" do
    phone = "+256700111001"
    {:ok, %{code: c1}} = Accounts.request_code(phone)
    {:ok, _} = Accounts.verify_code(phone, c1)
    assert {:error, :invalid} = Accounts.verify_code(phone, c1)
    {:ok, %{code: c2}} = Accounts.request_code(phone)

    _otp =
      Repo.one(
        Ecto.Query.from(o in Backend.Schemas.OtpCode,
          where: o.phone == ^phone,
          order_by: [desc: o.inserted_at],
          limit: 1
        )
      )

    Repo.update_all(Ecto.Query.from(o in Backend.Schemas.OtpCode, where: o.phone == ^phone),
      set: [
        expires_at: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -60, :second)
      ]
    )

    assert {:error, :expired} = Accounts.verify_code(phone, c2)

    for _ <- 1..6 do
      Accounts.request_code("+256700999888")
    end

    assert {:error, :rate_limited} = Accounts.request_code("+256700999888")
  end

  test "DPPA legal gate: terms acceptance + 18+ enforced, consent logged" do
    phone = "+256700111009"
    {:ok, %{code: c}} = Accounts.request_code(phone)
    # no consent attrs -> existing users pass through untouched
    assert {:ok, user} = Accounts.verify_code(phone, c)

    {:ok, %{code: c2}} = Accounts.request_code(phone)
    # under-18 rejected
    minor_dob = Date.utc_today() |> Date.add(-365 * 10) |> Date.to_iso8601()

    assert {:error, {:legal_gate, _}} =
             Accounts.verify_code(phone, c2, %{
               "terms_accepted" => true,
               "date_of_birth" => minor_dob,
               "client_ip" => "127.0.0.1"
             })

    {:ok, %{code: c3}} = Accounts.request_code(phone)
    # terms not accepted rejected
    adult_dob = Date.utc_today() |> Date.add(-365 * 25) |> Date.to_iso8601()

    assert {:error, {:legal_gate, _}} =
             Accounts.verify_code(phone, c3, %{
               "terms_accepted" => false,
               "date_of_birth" => adult_dob
             })

    {:ok, %{code: c4}} = Accounts.request_code(phone)

    assert {:ok, gated} =
             Accounts.verify_code(phone, c4, %{
               "terms_accepted" => true,
               "date_of_birth" => adult_dob,
               "client_ip" => "127.0.0.1"
             })

    assert gated.dppa_consent_given == true
    assert gated.dppa_consent_ip == "127.0.0.1"
    assert %DateTime{} = gated.dppa_consent_timestamp
    assert %DateTime{} = gated.terms_accepted_at
    assert gated.id == user.id

    # XSS sanitizer strips tags on listings
    s = user!("+256700111010", %{is_seller: true})
    c5 = cat!("t-secure")

    {:ok, l} =
      Catalog.create_listing(s.id, %{
        "category_id" => c5.id,
        "title" => "<script>alert(1)</script>Cleaner",
        "kind" => "work"
      })

    refute String.contains?(l.title, "<script>")
    assert String.contains?(l.title, "Cleaner")
  end

  test "immutable offers: new terms new version, accept one" do
    s = user!("+256700111002", %{is_seller: true})
    wu = user!("+256700111003", %{is_worker: true})
    c = cat!("t-work")

    {:ok, l} =
      Catalog.create_listing(s.id, %{"category_id" => c.id, "title" => "T", "kind" => "work"})

    {:ok, l} = Catalog.publish(l)
    {:ok, app} = Work.apply(Repo.get!(Listing, l.id), wu.id, %{})
    {:ok, o1} = Work.make_offer(app, %{"pay_minor" => 100, "scope_text" => "v1"})
    {:ok, o2} = Work.make_offer(app, %{"pay_minor" => 200, "scope_text" => "v2"})
    assert o2.version == o1.version + 1
    assert Repo.get!(Backend.Schemas.Offer, o1.id).status == "superseded"
    {:ok, _} = Work.accept_offer(o2, wu.id)

    assert {:error, :bad_state} =
             Work.accept_offer(Repo.get!(Backend.Schemas.Offer, o2.id), wu.id)
  end

  test "brokerage happy path + duplicate + no-silence-accept + reported vs received" do
    s = user!("+256700111004", %{is_seller: true})
    b = user!("+256700111005", %{is_broker: true})
    c = cat!("t-deal")

    {:ok, l} =
      Catalog.create_listing(s.id, %{
        "category_id" => c.id,
        "title" => "Deal",
        "kind" => "deal",
        "commission_type" => "fixed",
        "commission_value_minor" => 5000
      })

    {:ok, l} = Catalog.publish(l)
    {:ok, req} = Brokerage.request_access(l.id, b.id)
    {:ok, %{agreement: ag}} = Brokerage.approve(req, s.id)
    {:ok, ag} = Brokerage.accept_agreement(ag, b.id)
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    {:ok, %{referral: r1, duplicate: false}} =
      Brokerage.create_referral(ag, l.id, %{
        "buyer_consent_at" => now,
        "consent_ref" => "C1",
        "buyer_phone" => "+256712345678"
      })

    assert r1.attribution == "pending"

    {:ok, %{referral: r2, duplicate: true}} =
      Brokerage.create_referral(ag, l.id, %{
        "buyer_consent_at" => now,
        "consent_ref" => "C2",
        "buyer_phone" => "+256712345678"
      })

    assert r1.id == r2.id

    assert {:error, :consent_required} =
             Brokerage.create_referral(ag, l.id, %{"buyer_phone" => "+256700000000"})

    {:ok, r1} = Brokerage.attribute(r1, s.id, "accept", nil)
    assert r1.attribution == "accepted"
    {:ok, claim} = Brokerage.record_outcome(r1, s.id, "sold", [], 5000, "UGX")
    assert claim.status == "earned"
    assert {:error, _} = Brokerage.record_outcome(r1, s.id, "sold", [], 5000, "UGX")
    {:ok, _} = Brokerage.report_payment(claim, s.id, 5000)
    assert Repo.get!(Backend.Schemas.CommissionClaim, claim.id).status == "payment_reported"
    {:ok, _} = Brokerage.acknowledge(Repo.get!(Backend.Schemas.CommissionClaim, claim.id), b.id)
    assert Repo.get!(Backend.Schemas.CommissionClaim, claim.id).status == "received"
  end

  test "category gate rejection" do
    s = user!("+256700111006")
    g = cat!("gated-x", false)

    assert {:error, :gated} =
             Catalog.create_listing(s.id, %{
               "category_id" => g.id,
               "title" => "T",
               "kind" => "deal"
             })
  end

  test "messaging scope" do
    a = user!("+256700111007")
    b = user!("+256700111008")
    e = user!("+256700111009")
    {:ok, conv} = ChatOps.create_conversation(a.id, %{"participant_ids" => [b.id]})
    {:ok, _} = ChatOps.send_message(conv, a.id, %{"body" => "hi"})
    assert {:error, :forbidden} = ChatOps.send_message(conv, e.id, %{"body" => "hack"})
    assert {:error, :forbidden} = ChatOps.list_messages(conv, e.id)
  end

  test "idempotency keys" do
    u = user!("+256700111010")
    assert :miss = ChatOps.check_idem("k1", u.id)
    ChatOps.store_idem("k1", u.id, %{a: 1})
    assert {:hit, _} = ChatOps.check_idem("k1", u.id)
  end

  test "public projections leak no private fields" do
    s = user!("+256700111011", %{is_seller: true})
    c = cat!("t-pub")

    {:ok, l} =
      Catalog.create_listing(s.id, %{
        "category_id" => c.id,
        "title" => "Pub",
        "kind" => "work",
        "location_text" => "exact hidden",
        "description" => "open"
      })

    {:ok, l} = Catalog.publish(l)
    pub = BackendWeb.Helpers.public_listing(Backend.Repo.get!(Listing, l.id))

    for k <- ["owner_id", "location_text"] do
      refute Map.has_key?(pub, k), "leaked #{k}"
    end

    refute pub["owner"] |> Map.keys() |> Enum.any?(&(&1 in ["phone", "email"]))
    assert pub["owner"]["id"] == s.id
  end

  test "outcome/report/ack guards: participants, payer, payee, state order" do
    s = user!("+256700111014", %{is_seller: true})
    b = user!("+256700111015", %{is_broker: true})
    outsider = user!("+256700111016")
    c = cat!("t-guard")

    {:ok, l} =
      Catalog.create_listing(s.id, %{
        "category_id" => c.id,
        "title" => "G",
        "kind" => "deal",
        "commission_type" => "fixed",
        "commission_value_minor" => 3000
      })

    {:ok, l} = Catalog.publish(l)
    {:ok, req} = Brokerage.request_access(l.id, b.id)
    {:ok, %{agreement: ag}} = Brokerage.approve(req, s.id)
    {:ok, ag} = Brokerage.accept_agreement(ag, b.id)
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    {:ok, %{referral: r1}} =
      Brokerage.create_referral(ag, l.id, %{
        "buyer_consent_at" => now,
        "consent_ref" => "CG",
        "buyer_phone" => "+256712000001"
      })

    # Outcome by non-participant, and before attribution accepted (Q05/Q07).
    assert {:error, :forbidden} =
             Brokerage.record_outcome(r1, outsider.id, "sold", [], 100, "UGX")

    assert {:error, :bad_state} = Brokerage.record_outcome(r1, s.id, "sold", [], 100, "UGX")
    {:ok, r1} = Brokerage.attribute(r1, s.id, "accept", nil)
    {:ok, claim} = Brokerage.record_outcome(r1, s.id, "sold", [], 3000, "UGX")

    # Payment report: payer = principal only (Q10); report before payee ack.
    assert {:error, :forbidden} = Brokerage.report_payment(claim, b.id, 3000)
    assert {:error, :forbidden} = Brokerage.report_payment(claim, outsider.id, 3000)

    # Acknowledge only after payment_reported, and only by the broker payee.
    assert {:error, :bad_state} = Brokerage.acknowledge(claim, b.id)
    {:ok, _} = Brokerage.report_payment(claim, s.id, 3000)
    assert {:error, :forbidden} = Brokerage.acknowledge(claim, s.id)
    assert {:error, :forbidden} = Brokerage.acknowledge(claim, outsider.id)
    {:ok, _} = Brokerage.acknowledge(Repo.get!(Backend.Schemas.CommissionClaim, claim.id), b.id)
    assert Repo.get!(Backend.Schemas.CommissionClaim, claim.id).status == "received"
  end

  test "seller cannot broker-request own listing; default pilot category + field aliases" do
    s = user!("+256700111017", %{is_seller: true})
    c = cat!("t-sel", true)

    {:ok, l} =
      Catalog.create_listing(s.id, %{"category_id" => c.id, "title" => "S", "kind" => "work"})

    {:ok, l} = Catalog.publish(l)
    assert {:error, :forbidden} = Brokerage.request_access(l.id, s.id)

    # No category_id: falls back to first open pilot category of that kind.
    {:ok, l2} =
      Catalog.create_listing(s.id, %{
        "title" => "D2",
        "kind" => "work",
        "pay_minor" => 4200,
        "area" => "Jinja"
      })

    assert l2.category_id
    assert l2.pay_amount_minor == 4200
    assert l2.coarse_location == "Jinja"
  end

  test "reviews: create, reject self-review" do
    a = user!("+256700111012")
    b = user!("+256700111013")

    {:ok, r} =
      %Backend.Schemas.Review{}
      |> Backend.Schemas.Review.changeset(%{
        reviewer_id: a.id,
        reviewee_id: b.id,
        rating: 5,
        body: "great"
      })
      |> Repo.insert()

    assert r.rating == 5

    assert {:error, _} =
             %Backend.Schemas.Review{}
             |> Backend.Schemas.Review.changeset(%{
               reviewer_id: a.id,
               reviewee_id: a.id,
               rating: 0
             })
             |> Repo.insert()
  end
end
