defmodule Backend.Work do
  import Ecto.Query
  alias Backend.Repo
  alias Backend.Schemas.{Application, Offer, Booking, Quote}

  @booking_flow %{
    "requested" => ["quoted", "cancelled"],
    "quoted" => ["accepted", "cancelled"],
    "accepted" => ["in_progress", "cancelled"],
    "in_progress" => ["completion_requested", "cancelled"],
    "completion_requested" => ["completed", "cancelled"],
    "completed" => [],
    "cancelled" => []
  }
  def apply(listing, applicant_id, attrs) do
    if listing.owner_id == applicant_id,
      do: {:error, :self_apply},
      else:
        %Application{}
        |> Application.changeset(
          Map.merge(attrs, %{"listing_id" => listing.id, "applicant_id" => applicant_id})
        )
        |> Repo.insert()
  end

  def make_offer(app, attrs) do
    max_v =
      Repo.one(from o in Offer, where: o.application_id == ^app.id, select: max(o.version)) || 0

    Repo.update_all(
      from(o in Offer, where: o.application_id == ^app.id and o.status == "proposed"),
      set: [status: "superseded"]
    )

    %Offer{}
    |> Offer.changeset(
      Map.merge(attrs, %{
        "application_id" => app.id,
        "version" => max_v + 1,
        "status" => "proposed"
      })
    )
    |> Repo.insert()
  end

  def accept_offer(offer, _user_id) do
    offer = if offer.status != "proposed", do: {:error, :bad_state}, else: offer

    with %Offer{} = o <- offer do
      {:ok, o2} = o |> Offer.changeset(%{status: "accepted"}) |> Repo.update()
      app = Repo.get!(Application, o.application_id)
      listing = Repo.get!(Backend.Schemas.Listing, app.listing_id)

      {:ok, b} =
        %Booking{}
        |> Booking.changeset(%{
          offer_id: o.id,
          listing_id: listing.id,
          customer_id: listing.owner_id,
          provider_id: app.applicant_id,
          status: "accepted"
        })
        |> Repo.insert()

      {:ok, %{offer: o2, booking: b}}
    end
  end

  def booking_event(booking, to, notes) do
    allowed = Map.get(@booking_flow, booking.status, [])

    if to in allowed,
      do: booking |> Booking.changeset(%{status: to, outcome_notes: notes}) |> Repo.update(),
      else: {:error, :bad_transition}
  end

  def create_quote(listing_id, uid, attrs) do
    %Quote{}
    |> Quote.changeset(Map.merge(attrs, %{"listing_id" => listing_id, "requester_id" => uid}))
    |> Repo.insert()
  end
end
