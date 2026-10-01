#
## EPITECH PROJECT, 2026
## repo.ex
## File description:
## Ecto repository interface for database interactions
#

defmodule Dashboard.Repo do
  use Ecto.Repo,
    otp_app: :dashboard,
    adapter: Ecto.Adapters.Postgres
end
