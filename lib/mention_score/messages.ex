defmodule MentionScore.Messages do
  import Ecto.Query, warn: false
  alias MentionScore.Repo

  alias MentionScore.Messages.Message

  def list_messages do
    Repo.all(Message)
  end

  def list_messages_by_user_id(user_id) do
    Repo.all(
      from m in Message,
        where: m.user_id == ^user_id,
        order_by: [asc: m.inserted_at]
    )
  end

  def get_chat!(id), do: Repo.get!(Message, id)

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def delete_all_messages_by_user_id(user_id) do
    from(m in Message, where: m.user_id == ^user_id)
    |> Repo.delete_all()
  end
end
