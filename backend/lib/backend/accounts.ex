defmodule Backend.Accounts do
  import Ecto.Query
  alias Backend.Repo
  require Logger
  alias Backend.Schemas.{User, OtpCode, Profile, AuditEvent, Notification}
  @expiry_min 10
  def request_code(phone) do
    hour_ago = DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -3600, :second)

    count =
      Repo.aggregate(
        from(o in OtpCode, where: o.phone == ^phone and o.inserted_at > ^hour_ago),
        :count
      )

    if count >= 5, do: {:error, :rate_limited}, else: do_request(phone)
  end

  defp do_request(phone) do
    code = (:rand.uniform(900_000) + 100_000) |> Integer.to_string()
    hash = :crypto.hash(:sha256, code) |> Base.encode16()

    expires =
      DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), @expiry_min * 60, :second)

    {:ok, _} =
      %OtpCode{}
      |> OtpCode.changeset(%{phone: phone, code_hash: hash, expires_at: expires})
      |> Repo.insert()

    require Logger
    Logger.info("OTP sent", phone_redacted: redact(phone))

    user =
      Repo.get_by(User, phone: phone) ||
        elem(Repo.insert(%User{} |> User.changeset(%{phone: phone})), 1)

    {:ok, %{user: user, code: code}}
  end

  def verify_code(phone, code) do
    otp =
      Repo.one(
        from o in OtpCode,
          where: o.phone == ^phone and is_nil(o.used_at),
          order_by: [desc: o.inserted_at],
          limit: 1
      )

    cond do
      is_nil(otp) ->
        {:error, :invalid}

      DateTime.compare(DateTime.utc_now() |> DateTime.truncate(:second), otp.expires_at) == :gt ->
        {:error, :expired}

      true ->
        hash = :crypto.hash(:sha256, code) |> Base.encode16()

        if hash != otp.code_hash do
          Repo.update(Ecto.Changeset.change(otp, attempts: otp.attempts + 1))
          {:error, :invalid}
        else
          Repo.update(
            Ecto.Changeset.change(otp, used_at: DateTime.utc_now() |> DateTime.truncate(:second))
          )

          user = Repo.get_by(User, phone: phone)
          {:ok, user}
        end
    end
  end

  def token_for(user) do
    Phoenix.Token.sign(BackendWeb.Endpoint, "user", user.id)
  end

  def redact(phone) when is_binary(phone) do
    n = String.length(phone)
    if n <= 4, do: "****", else: String.slice(phone, 0, 2) <> "****" <> String.slice(phone, -2, 2)
  end

  def redact(_), do: "****"
  def get_profile(uid), do: Repo.get_by(Profile, user_id: uid)

  def upsert_profile(uid, attrs) do
    case Repo.get_by(Profile, user_id: uid) do
      nil -> %Profile{} |> Profile.changeset(Map.put(attrs, "user_id", uid)) |> Repo.insert()
      p -> p |> Profile.changeset(attrs) |> Repo.update()
    end
  end

  def audit(actor_id, action, entity, entity_id, meta \\ %{}) do
    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_id: actor_id,
      action: action,
      entity: entity,
      entity_id: entity_id,
      metadata: meta
    })
    |> Repo.insert()
  end

  def notify(user_id, kind, payload, dedupe) do
    %Notification{}
    |> Notification.changeset(%{
      user_id: user_id,
      kind: kind,
      payload: payload,
      dedupe_key: dedupe
    })
    |> Repo.insert(on_conflict: :nothing)
  end
end
