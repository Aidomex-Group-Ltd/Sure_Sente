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
    attrs = alias_fields(attrs)
    cat_id = attrs["category_id"] || attrs[:category_id]

    case category_for(cat_id, attrs["kind"]) do
      {:error, reason} ->
        {:error, reason}

      {:ok, c} ->
        %Listing{}
        |> Listing.changeset(
          attrs
          |> Map.put("owner_id", owner_id)
          |> Map.put("category_id", c.id)
        )
        |> Repo.insert()
    end
  end

  # Web/curl aliases per 04-UI/06-CATEGORIES fields: pay_minor -> pay_amount_minor,
  # area/price -> coarse_location. Server stays validator of last resort.
  defp alias_fields(a) when is_map(a) do
    a
    |> then(fn m ->
      pay = m["pay_minor"] || m[:pay_minor] || m["price_minor"] || m[:price_minor]

      if pay,
        do:
          Map.put(
            Map.drop(m, ["pay_minor", :pay_minor, "price_minor", :price_minor]),
            "pay_amount_minor",
            pay
          ),
        else: m
    end)
    |> then(fn m ->
      area = m["area"] || m[:area] || m["location"] || m[:location]

      if area && !m["coarse_location"],
        do: Map.put(Map.drop(m, ["area", :area, "location", :location]), "coarse_location", area),
        else: m
    end)
  end

  # 06-CATEGORIES: taxonomy supports all kinds; only approved pilot categories
  # enabled. If the client omits category_id, pick the first open pilot category
  # of that kind (Kampala pilot default) instead of failing.
  defp category_for(nil, kind) do
    first =
      Repo.one(
        from c in Category,
          where: c.kind == ^kind and c.pilot_enabled and c.gate_status == "open",
          order_by: [asc: c.inserted_at],
          limit: 1
      )

    if first, do: {:ok, first}, else: {:error, :gated}
  end

  defp category_for(cat_id, _kind) do
    case gate_check!(cat_id) do
      {:error, _} -> {:error, :gated}
      {:ok, c} -> {:ok, c}
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
