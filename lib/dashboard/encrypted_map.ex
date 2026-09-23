#
## EPITECH PROJECT, 2026
## encrypted_map.ex
## File description:
## Ecto type storing a map encrypted at rest
#

defmodule Dashboard.EncryptedMap do
  @moduledoc """
  Ecto type for a map that is JSON encoded then encrypted with
  `Dashboard.Vault` before being written to a `:binary` column.

  Keys are always loaded back as strings.
  """

  use Ecto.Type

  alias Dashboard.Vault

  def type, do: :binary

  def cast(map) when is_map(map), do: {:ok, stringify_keys(map)}
  def cast(_), do: :error

  def dump(map) when is_map(map) do
    case Jason.encode(map) do
      {:ok, json} -> {:ok, Vault.encrypt(json)}
      {:error, _} -> :error
    end
  end

  def dump(_), do: :error

  def load(ciphertext) when is_binary(ciphertext) do
    with {:ok, json} <- Vault.decrypt(ciphertext),
         {:ok, map} when is_map(map) <- Jason.decode(json) do
      {:ok, map}
    else
      _ -> :error
    end
  end

  def load(_), do: :error

  def embed_as(_format), do: :dump

  defp stringify_keys(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)
end
