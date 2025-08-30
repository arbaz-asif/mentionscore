defmodule MentionScoreWeb.Router do
  use MentionScoreWeb, :router

  import MentionScoreWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MentionScoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_with_flash do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
  end

  scope "/", MentionScoreWeb do
    pipe_through :browser

    # get "/", PageController, :home
    live "/", LandingPageLive.Index
    live "/privacy-policy", PrivacyPolicyLive.Index
    live "/terms", TermsOfServicesLive.Index
    live "/contact-us", ContactUsLive.Index
    live "/refund-policy", RefundPolicyLive.Index
    # live "/dashboard", DashboardLive.Index
  end

  # Other scopes may use custom stacks.
  # scope "/api", MentionScoreWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mention_score, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MentionScoreWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/auth", MentionScoreWeb do
    pipe_through :browser

    get "/:provider", CallbackController, :request
    get "/callback/:provider", CallbackController, :callback
  end

  scope "/callback", MentionScoreWeb do
    pipe_through :api_with_flash

    post "/gumroad", CallbackController, :gumroad_callback
  end

  scope "/", MentionScoreWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{MentionScoreWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", MentionScoreWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{MentionScoreWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/dashboard", DashboardLive.Index
    end
  end

  scope "/", MentionScoreWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{MentionScoreWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
