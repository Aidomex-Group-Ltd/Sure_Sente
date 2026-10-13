defmodule Backend.ChatOps do
  import Ecto.Query
  alias Backend.Repo
  alias Backend.Schemas.{Conversation, Message, Report, Dispute, AuditEvent, IdempotencyKey}

  def create_conversation(uid, attrs) do
    parts = Enum.uniq([uid | attrs["participant_ids"] || attrs[:participant_ids] || []])

    %Conversation{}
    |> Conversation.changeset(%{
      subject_type: attrs["subject_type"] || attrs[:subject_type],
      subject_id: attrs["subject_id"] || attrs[:subject_id],
      participant_ids: parts
    })
    |> Repo.insert()
  end

  def send_message(conv, sender_id, attrs) do
    if sender_id in conv.participant_ids,
      do:
        %Message{}
        |> Message.changeset(%{
          conversation_id: conv.id,
          sender_id: sender_id,
          body: attrs["body"] || attrs[:body],
          attachment_ref: attrs["attachment_ref"] || attrs[:attachment_ref]
        })
        |> Repo.insert(),
      else: {:error, :forbidden}
  end

  def list_messages(conv, uid) do
    if uid in conv.participant_ids,
      do:
        {:ok,
         Repo.all(
           from m in Message, where: m.conversation_id == ^conv.id, order_by: [asc: m.inserted_at]
         )},
      else: {:error, :forbidden}
  end

  def check_idem(key, uid) do
    if is_nil(key) or key == "",
      do: :miss,
      else:
        (case Repo.get_by(IdempotencyKey, key: key, user_id: uid) do
           nil -> :miss
           r -> {:hit, r.response}
         end)
  end

  def store_idem(key, uid, resp) do
    if is_nil(key) or key == "",
      do: :ok,
      else:
        %IdempotencyKey{}
        |> IdempotencyKey.changeset(%{key: key, user_id: uid, response: resp})
        |> Repo.insert(on_conflict: :nothing)
        |> elem(0)
        |> then(fn _ -> :ok end)
  end

  def report(uid, attrs) do
    %Report{} |> Report.changeset(Map.put(attrs, "reporter_id", uid)) |> Repo.insert()
  end

  def dispute(uid, attrs) do
    %Dispute{} |> Dispute.changeset(Map.put(attrs, "reporter_id", uid)) |> Repo.insert()
  end

  def decide(uid, entity, id, action, status) do
    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_id: uid,
      action: action,
      entity: entity,
      entity_id: id,
      metadata: %{status: status}
    })
    |> Repo.insert()

    case entity do
      "report" -> Repo.get!(Report, id) |> Report.changeset(%{status: status}) |> Repo.update()
      "dispute" -> Repo.get!(Dispute, id) |> Dispute.changeset(%{status: status}) |> Repo.update()
      _ -> {:error, :unknown}
    end
  end
end
