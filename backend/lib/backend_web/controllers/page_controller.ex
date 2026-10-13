defmodule BackendWeb.PageController do
  use BackendWeb, :controller
  alias Backend.{Repo, Catalog}
  alias Backend.Schemas.Category
  alias BackendWeb.Helpers
  import Ecto.Query

  def home(conn, _params) do
    {listings, _} = Catalog.list_published(%{}, 6, nil)
    cats = Repo.all(from c in Category, where: c.gate_status != "closed" and c.pilot_enabled == true)

    html =
      EEx.eval_file(
        Path.join([__DIR__, "..", "home.html.eex"]),
        listings: Enum.map(listings, &Helpers.public_listing/1),
        categories: Enum.map(cats, &Helpers.render_model/1)
      )

    html(conn, html)
  end
end
