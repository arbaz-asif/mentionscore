defmodule MentionScore.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :email, :citext, null: false
      add :hashed_password, :string, null: true
      add :confirmed_at, :utc_datetime
      add :last_login, :utc_datetime
      add :credits, :integer, default: 5, null: false
      add :total_credits_used, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :message_by, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:user_id])
  end
end
