defmodule BackendWeb.Plugs.CORS do
  import Plug.Conn
  def init(o), do: o

  def call(c, _) do
    c
    |> put_resp_header("access-control-allow-origin", "http://localhost:5173")
    |> put_resp_header(
      "access-control-allow-headers",
      "authorization, content-type, idempotency-key"
    )
    |> put_resp_header("access-control-allow-methods", "GET,POST,PATCH,PUT,DELETE,OPTIONS")
    |> then(fn c -> if c.method == "OPTIONS", do: c |> send_resp(200, "") |> halt(), else: c end)
  end
end

defmodule BackendWeb.Plugs.Auth do
  import Plug.Conn
  def init(o), do: o

  def call(conn, _) do
    with ["Bearer " <> tok] <- get_req_header(conn, "authorization"),
         {:ok, uid} <- Phoenix.Token.verify(BackendWeb.Endpoint, "user", tok, max_age: 86400 * 7),
         user when not is_nil(user) <- Backend.Repo.get(Backend.Schemas.User, uid) do
      assign(conn, :current_user, user)
    else
      _ -> assign(conn, :current_user, nil)
    end
  end
end

defmodule BackendWeb.Helpers do
  import Plug.Conn

  def need_user(conn, _) do
    if conn.assigns[:current_user],
      do: conn,
      else:
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{error: %{code: "unauthorized", message: "Login required"}})
        |> halt()
  end

  def need_staff(conn, _) do
    u = conn.assigns[:current_user]

    if u && u.is_staff,
      do: conn,
      else:
        conn
        |> put_status(403)
        |> Phoenix.Controller.json(%{error: %{code: "forbidden", message: "Staff only"}})
        |> halt()
  end

  def render_model(m) do
    m
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Enum.map(fn {k, v} -> {Atom.to_string(k), enc(v)} end)
    |> Map.new()
  end

  # Public projections: safe for guests. Never include phones, emails,
  # contact keys, consent refs, identity docs, or precise addresses.
  @listing_public ~w(id category_id title description kind pay_amount_minor pay_basis currency coarse_location status version commission_type commission_value_minor commission_bps commission_currency commission_version inserted_at updated_at)
  def public_listing(m) do
    full = render_model(m)
    pub = Map.take(full, @listing_public)
    Map.put(pub, "owner", owner_public(full["owner_id"]))
  end

  def owner_public(nil), do: nil

  def owner_public(uid) do
    alias Backend.{Repo, Schemas}

    case Repo.get(Schemas.User, uid) do
      nil ->
        nil

      user ->
        prof = Repo.get_by(Schemas.Profile, user_id: uid)

        %{
          "id" => uid,
          "display_name" => (prof && prof.display_name) || "Sure Sente member",
          "roles" => %{
            worker: user.is_worker,
            provider: user.is_provider,
            seller: user.is_seller,
            employer: user.is_employer,
            broker: user.is_broker
          },
          "service_areas" => (prof && prof.service_areas) || [],
          "skills" => (prof && prof.skills) || [],
          "verification" => "unverified"
        }
    end
  end

  defp enc(%DateTime{} = d), do: DateTime.to_iso8601(d)
  defp enc(o), do: o
end

defmodule BackendWeb.Plugs.RequireUser do
  import Plug.Conn
  def init(o), do: o

  def call(conn, _) do
    if conn.assigns[:current_user],
      do: conn,
      else:
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{error: %{code: "unauthorized", message: "Login required"}})
        |> halt()
  end
end

defmodule BackendWeb.Plugs.RequireStaff do
  import Plug.Conn
  def init(o), do: o

  def call(conn, _) do
    u = conn.assigns[:current_user]

    if u && u.is_staff,
      do: conn,
      else:
        conn
        |> put_status(403)
        |> Phoenix.Controller.json(%{error: %{code: "forbidden", message: "Staff only"}})
        |> halt()
  end
end
