#
## EPITECH PROJECT, 2026
## router.ex
## File description:
## maps each URL to the correct controller
#

defmodule DashboardWeb.Router do
  use DashboardWeb, :router
  import DashboardWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DashboardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :guest_only do
    plug :redirect_if_user_is_authenticated
  end

  scope "/", DashboardWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/users/confirm/:token", UserConfirmationController, :confirm
    delete "/logout", SessionController, :delete
  end

  scope "/", DashboardWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated, on_mount: [{DashboardWeb.UserAuth, :ensure_authenticated}] do
      live "/onboarding", OnboardingLive
      live "/dashboard", DashboardLive
    end

    get "/account", AccountController, :show
  end

  scope "/", DashboardWeb do
    pipe_through [:browser, :guest_only]

    get "/register", UserRegistrationController, :new
    post "/register", UserRegistrationController, :create
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    get "/auth/:provider", AuthController, :request
    get "/auth/:provider/callback", AuthController, :callback
  end

  scope "/", DashboardWeb do
    pipe_through :api

    get "/about.json", AboutController, :show
  end

  scope "/admin", DashboardWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin]

    get "/users", AdminUserController, :index
    delete "/users/:id", AdminUserController, :delete
    patch "/users/:id/promote", AdminUserController, :promote
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dashboard, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DashboardWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
