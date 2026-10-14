defmodule BackendWeb.PageController do
  use BackendWeb, :controller
  alias Backend.{Repo, Catalog}
  alias Backend.Schemas.Category
  alias BackendWeb.Helpers
  import Ecto.Query

  def home(conn, _params) do
    {listings, _} = Catalog.list_published(%{}, 12, nil)
    cats = Repo.all(from c in Category, where: c.gate_status != "closed" and c.pilot_enabled == true)

    public = Enum.map(listings, &Helpers.public_listing/1)
    by_kind = Enum.group_by(public, & &1["kind"])
    deals = Enum.take(by_kind["deal"] || by_kind["product"] || [], 8)
    gigs = Enum.take(by_kind["work"] || by_kind["gig"] || [], 8)
    comms = Enum.filter(public, &(&1["commission_type"] not in [nil, "none"])) |> Enum.take(8)

    html =
      EEx.eval_file(
        Path.join([__DIR__, "..", "home.html.eex"]),
        listings: public,
        featured_deals: if(deals == [], do: Enum.take(public, 8), else: deals),
        active_gigs: if(gigs == [], do: Enum.take(public, 8), else: gigs),
        commission_opps: comms,
        categories: Enum.map(cats, &Helpers.render_model/1)
      )

    html(conn, html)
  end
end
