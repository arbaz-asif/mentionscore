defmodule MentionScore.Repo do
  use Ecto.Repo,
    otp_app: :mention_score,
    adapter: Ecto.Adapters.Postgres
end
