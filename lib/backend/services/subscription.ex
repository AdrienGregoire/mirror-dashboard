#
## EPITECH PROJECT, 2026
## subscription.ex
## File description:
## Ecto Schema of a user subscription to a service
#

defmodule Dashboard.Services.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Dashboard.Services.{Registry, Service}

  schema "service_subscriptions" do
    field :service, :string
    field :credentials, Dashboard.EncryptedMap, redact: true

    belongs_to :user, Dashboard.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:service, :credentials, :user_id])
    |> validate_required([:service, :credentials, :user_id])
    |> validate_service()
    |> validate_credentials()
    |> unique_constraint([:user_id, :service])
    |> foreign_key_constraint(:user_id)
  end

  defp validate_service(changeset) do
    validate_change(changeset, :service, fn :service, name ->
      case Registry.get(name) do
        nil -> [service: "does not exist"]
        %Service{auth: :none} -> [service: "does not require a subscription"]
        %Service{} -> []
      end
    end)
  end

  defp validate_credentials(changeset) do
    with service when not is_nil(service) <- Registry.get(get_field(changeset, :service)),
         credentials when is_map(credentials) <- get_field(changeset, :credentials) do
      missing =
        Enum.reject(Service.required_credentials(service), fn key ->
          is_binary(credentials[key]) and credentials[key] != ""
        end)

      if missing == [] do
        changeset
      else
        add_error(changeset, :credentials, "missing #{Enum.join(missing, ", ")}")
      end
    else
      _ -> changeset
    end
  end
end
