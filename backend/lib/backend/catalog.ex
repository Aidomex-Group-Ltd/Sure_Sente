defmodule Backend.Catalog do
  import Ecto.Query
  alias Backend.Repo
  alias Backend.Schemas.{Category, Listing, ListingVersion}
  def list_categories, do: Repo.all(Category)

  def gate_check!(category_id) do
    c = Repo.get!(Category, category_id)
    if c.gate_status == "closed" or not c.pilot_enabled, do: {:error, c}, else: {:ok, c}
  end

  def create_listing(owner_id, attrs) do
    cat_id = attrs["category_id"] || attrs[:category_id]

    case gate_check!(cat_id) do
      {:error, _} ->
        {:error, :gated}

      {:ok, _} ->
        %Listing{} |> Listing.changeset(Map.put(attrs, "owner_id", owner_id)) |> Repo.insert()
    end
  end

  def update_listing(l, attrs) do
    l |> Listing.changeset(attrs) |> Repo.update()
  end

  def publish(listing) do
    v = (listing.version || 1) + 1
    {:ok, l} = listing |> Listing.changeset(%{status: "published", version: v}) |> Repo.update()

    snap =
      Map.from_struct(l)
      |> Map.drop([:__meta__, :__struct__])
      |> Enum.map(fn {k, val} -> {Atom.to_string(k), val} end)
      |> Map.new()

    {:ok, _} =
      %ListingVersion{}
      |> ListingVersion.changeset(%{listing_id: l.id, version: v, snapshot: snap})
      |> Repo.insert()

    {:ok, l}
  end

  def list_published(filters, limit, cursor) do
    q =
      from l in Listing,
        where: l.status == "published",
        order_by: [desc: l.inserted_at],
        limit: ^(limit + 1)

    q = if f = filters["kind"], do: from(l in q, where: l.kind == ^f), else: q
    q = if f = filters["town"], do: from(l in q, where: l.coarse_location == ^f), else: q

    q =
      if f = filters["area"] || filters["location"],
        do: from(l in q, where: l.coarse_location == ^f),
        else: q

    q = if f = filters["category_id"], do: from(l in q, where: l.category_id == ^f), else: q
    q = if f = filters["q"], do: from(l in q, where: ilike(l.title, ^"%#{f}%")), else: q
    q = if cursor, do: from(l in q, where: l.id < ^cursor), else: q
    rows = Repo.all(q)

    {Enum.take(rows, limit),
     if(length(rows) > limit, do: List.last(Enum.take(rows, limit)).id, else: nil)}
  end
end
