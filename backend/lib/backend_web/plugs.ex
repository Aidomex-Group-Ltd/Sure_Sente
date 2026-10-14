defmodule BackendWeb.Plugs.CORS do
  import Plug.Conn
  def init(o), do: o

  # Read at runtime so releases pick up the container env.
  # Comma-separated list allowed; reflects the request origin when matched.
  defp allowed_origin(conn) do
    allowed =
      System.get_env("CORS_ORIGIN", "http://localhost:5173")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)

    req = List.first(get_req_header(conn, "origin"))

    if req in allowed, do: req, else: List.first(allowed)
  end

  def call(c, _) do
    c
    |> put_resp_header("access-control-allow-origin", allowed_origin(c))
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

  # Central error envelope per 12-API spec:
  # {error: {code, message, fields?}, request_id}. request_id comes from
  # Plug.RequestId (also sent as the x-request-id response header).
  def err(conn, status, code, message, extra \\ %{}) do
    request_id =
      Logger.metadata()[:request_id] || get_resp_header(conn, "x-request-id") |> List.first()

    body = %{error: Map.merge(%{code: code, message: message}, extra), request_id: request_id}
    conn |> put_status(status) |> Phoenix.Controller.json(body)
  end

  def need_user(conn, _) do
    if conn.assigns[:current_user],
      do: conn,
      else:
        conn
        |> err(401, "unauthorized", "Login required")
        |> halt()
  end

  def need_staff(conn, _) do
    u = conn.assigns[:current_user]

    if u && u.is_staff,
      do: conn,
      else:
        conn
        |> err(403, "forbidden", "Staff only")
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
        |> BackendWeb.Helpers.err(401, "unauthorized", "Login required")
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
        |> BackendWeb.Helpers.err(403, "forbidden", "Staff only")
        |> halt()
  end
end

defmodule BackendWeb.Plugs.SecurityHeaders do
  @moduledoc "OWASP A05: secure browser headers + CSP (ISO 27001 A.8.9)."
  import Plug.Conn
  def init(o), do: o

  def call(conn, _) do
    conn
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; frame-ancestors 'none';"
    )
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
  end
end

defmodule BackendWeb.Plugs.RateLimiter do
  @moduledoc "Brute-force / DoS guard (ETS-backed, no new deps). 60 req/min per IP+path."
  import Plug.Conn
  @table :sure_sente_rate_limit
  @limit 60
  @window_ms 60_000

  def init(o), do: o

  def call(conn, _) do
    ensure_table()
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    key = {conn.request_path, ip}
    now = System.system_time(:millisecond)

    count =
      case :ets.lookup(@table, key) do
        [{^key, {n, reset}}] when now < reset -> n
        _ -> 0
      end

    if count >= @limit do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(429, "Too many requests. Please slow down and try again in a minute.")
      |> halt()
    else
      reset = now + @window_ms

      if count == 0,
        do: :ets.insert(@table, {key, {1, reset}}),
        else: :ets.update_element(@table, key, {2, count + 1})

      conn
    end
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])
    end
  end
end

defmodule BackendWeb.Plugs.SecurityAuditor do
  @moduledoc "ISO 27001 A.8.15 / Computer Misuse Act: immutable audit log of 401/403/429 + financial endpoints."
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      if conn.status in [401, 403, 429] or
           String.starts_with?(conn.request_path, "/api/v1/referrals") or
           String.contains?(conn.request_path, "claim") or
           conn.request_path == "/api/v1/me/earnings" do
        log_security_event(conn)
      end

      conn
    end)
  end

  defp log_security_event(conn) do
    user_id = conn.assigns[:current_user] && conn.assigns.current_user.id
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    payload = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      ip_address: ip,
      path: conn.request_path,
      method: conn.method,
      status: conn.status,
      user_id: user_id,
      user_agent: get_req_header(conn, "user-agent") |> List.first()
    }

    Logger.info("[SECURITY_AUDIT_LOG] #{Jason.encode!(payload)}")

    try do
      Backend.Accounts.audit(
        user_id,
        "security.#{conn.status}",
        "http_request",
        conn.request_path,
        payload
      )
    rescue
      _ -> :ok
    end

    :ok
  end
end
