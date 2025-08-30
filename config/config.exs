# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mention_score,
  ecto_repos: [MentionScore.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :mention_score, MentionScoreWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MentionScoreWeb.ErrorHTML, json: MentionScoreWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MentionScore.PubSub,
  live_view: [signing_salt: "6KTSbhMn"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# config :mention_score, MentionScore.Mailer, adapter: Swoosh.Adapters.Local

# config :mention_score, MentionScore.Mailer,
#   adapter: Swoosh.Adapters.Mailgun,
#   api_key: System.get_env("MAILGUN_API_KEY"),
#   domain: System.get_env("MAILGUN_DOMAIN")


# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  mention_score: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  mention_score: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ueberauth, Ueberauth,
  providers: [
    google:
      {Ueberauth.Strategy.Google,
       [
         default_scope: "email profile",
         request_path: "/auth/google",
         callback_path: "/auth/callback/google"
       ]}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
