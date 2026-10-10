#
## EPITECH PROJECT, 2026
## runtime.exs
## File description:
## Dynamic runtime configuration for production execution
#

import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/dashboard start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :dashboard, DashboardWeb.Endpoint, server: true
end

config :dashboard, DashboardWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# GitHub OAuth App credentials
config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: System.get_env("GITHUB_CLIENT_ID"),
  client_secret: System.get_env("GITHUB_CLIENT_SECRET")

if config_env() == :dev do
  # Inside docker compose the database lives on the `db` host, not on localhost.
  # Without DATABASE_URL we keep the localhost settings from config/dev.exs.
  if database_url = System.get_env("DATABASE_URL") do
    config :dashboard, Dashboard.Repo, url: database_url
  end

  # Reload browser tabs when matching files change.
  config :dashboard, DashboardWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/frontend/router\.ex$"E,
        ~r"lib/frontend/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :dashboard, Dashboard.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  encryption_key =
    System.get_env("ENCRYPTION_KEY") ||
      raise """
      environment variable ENCRYPTION_KEY is missing.
      It encrypts the service credentials stored in database.
      You can generate one by calling: openssl rand -base64 32
      """

  config :dashboard, Dashboard.Vault, key: encryption_key

  host = System.get_env("PHX_HOST") || "example.com"

  # The scheme/port Phoenix uses to build *absolute* URLs (OAuth
  # callback URLs, confirmation links, ...)
  url_scheme = System.get_env("URL_SCHEME", "https")

  url_port =
    System.get_env("URL_PORT", System.get_env("PORT", "4000"))
    |> String.to_integer()

  config :dashboard, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :dashboard, DashboardWeb.Endpoint,
    url: [host: host, port: url_port, scheme: url_scheme],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end

# SMTP mailer. Always used in production; in dev it replaces the local mailbox
# as soon as SMTP credentials are provided (otherwise emails stay in /dev/mailbox).
if config_env() != :test and
     (config_env() == :prod or System.get_env("SMTP_USERNAME") not in [nil, ""]) do
  smtp_host = System.get_env("SMTP_HOST", "smtp.gmail.com")

  config :dashboard, Dashboard.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_host,
    port: String.to_integer(System.get_env("SMTP_PORT", "587")),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    ssl: false,
    tls: :always,
    auth: :always,
    # Without explicit CA certificates the STARTTLS handshake fails (`:tls_failed`)
    # on recent OTP versions, so no email can be sent.
    tls_options: [
      versions: [:"tlsv1.3", :"tlsv1.2"],
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(smtp_host),
      depth: 99
    ]
end
