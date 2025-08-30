defmodule MentionScore.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  # @foreign_key_type :binary_id

  schema "messages" do
    field :content, :string
    field :message_by, :string
    belongs_to :user, MentionScore.Users.User

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs, _opts \\ []) do
    message
    |> cast(attrs, [:content, :message_by, :user_id])
    |> validate_required([:content, :message_by, :user_id])
  end
end
