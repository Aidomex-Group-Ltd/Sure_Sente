defmodule BackendWeb.FallbackController do
  @moduledoc """
  12-API contract: invalid UUIDs return 404, never 400/500.

  `phoenix_ecto` maps `Ecto.Query.CastError` to 400 via the
  `Plug.Exception` protocol, and we cannot override that protocol
  (duplicate implementations break `mix release`). Instead this
  action fallback rescues those exceptions per-controller and renders
  the standard error envelope.
  """
  use BackendWeb, :controller

  alias BackendWeb.Helpers

  def call(conn, %Ecto.Query.CastError{}) do
    Helpers.err(conn, 404, "not_found", "Not found")
  end

  def call(conn, %Ecto.NoResultsError{}) do
    Helpers.err(conn, 404, "not_found", "Not found")
  end

  def call(_conn, err), do: raise(err)
end
