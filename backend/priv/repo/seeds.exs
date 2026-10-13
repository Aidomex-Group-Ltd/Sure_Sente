import Ecto.Query
alias Backend.Repo
alias Backend.Schemas.Category

cats = [
  %{
    key: "work-cleaning",
    name: "Cleaning tasks",
    kind: "work",
    pilot_enabled: true,
    gate_status: "open"
  },
  %{
    key: "work-shifts",
    name: "Shifts & events",
    kind: "work",
    pilot_enabled: true,
    gate_status: "open"
  },
  %{
    key: "service-repairs",
    name: "Repairs",
    kind: "service",
    pilot_enabled: true,
    gate_status: "open"
  },
  %{
    key: "service-tailoring",
    name: "Tailoring",
    kind: "service",
    pilot_enabled: true,
    gate_status: "open"
  },
  %{
    key: "goods-household",
    name: "Household goods",
    kind: "deal",
    pilot_enabled: true,
    gate_status: "open"
  },
  %{key: "vehicles", name: "Vehicles", kind: "deal", pilot_enabled: false, gate_status: "closed"},
  %{key: "property", name: "Property", kind: "deal", pilot_enabled: false, gate_status: "closed"},
  %{key: "land", name: "Land", kind: "deal", pilot_enabled: false, gate_status: "closed"},
  %{
    key: "finance",
    name: "Finance",
    kind: "service",
    pilot_enabled: false,
    gate_status: "closed"
  },
  %{key: "health", name: "Health", kind: "service", pilot_enabled: false, gate_status: "closed"},
  %{
    key: "overseas-recruitment",
    name: "Overseas recruitment",
    kind: "work",
    pilot_enabled: false,
    gate_status: "closed"
  }
]

Enum.each(cats, fn c ->
  Repo.insert!(%Category{} |> Category.changeset(c), on_conflict: :nothing)
end)

if System.get_env("SEED_DEMO") == "true" do
  alias Backend.Schemas.{User, Listing}

  {:ok, _seller} =
    %User{}
    |> User.changeset(%{phone: "+256700000001", is_seller: true, is_employer: true})
    |> Repo.insert(on_conflict: :nothing)

  seller = Repo.get_by(User, phone: "+256700000001")
  cat = Repo.get_by(Category, key: "work-cleaning")

  %Listing{}
  |> Listing.changeset(%{
    owner_id: seller.id,
    category_id: cat.id,
    title: "[DEMO] Office cleaning, Kampala",
    kind: "work",
    pay_amount_minor: 50000,
    pay_basis: "day",
    currency: "UGX",
    coarse_location: "Kampala",
    status: "published"
  })
  |> Repo.insert(on_conflict: :nothing)
end
