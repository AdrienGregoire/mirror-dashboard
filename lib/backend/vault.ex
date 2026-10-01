#
## EPITECH PROJECT, 2026
## vault.ex
## File description:
## Symmetric encryption (AES-256-GCM) of sensitive data stored in database
#

defmodule Dashboard.Vault do
  @moduledoc """
  Encrypts and decrypts sensitive values (service tokens, passwords, ...)
  with AES-256-GCM before they reach the database.

  The ciphertext layout is `<<iv::12 bytes, tag::16 bytes, ciphertext>>`.
  The 32 bytes key is read from `config :dashboard, Dashboard.Vault, key: ...`
  as a Base64 string.
  """

  @cipher :aes_256_gcm
  @aad "Dashboard.Vault.v1"
  @iv_size 12
  @tag_size 16
  @key_size 32

  @spec encrypt(binary()) :: binary()
  def encrypt(plaintext) when is_binary(plaintext) do
    iv = :crypto.strong_rand_bytes(@iv_size)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(@cipher, key(), iv, plaintext, @aad, @tag_size, true)

    iv <> tag <> ciphertext
  end

  @spec decrypt(binary()) :: {:ok, binary()} | :error
  def decrypt(<<iv::binary-size(@iv_size), tag::binary-size(@tag_size), ciphertext::binary>>) do
    case :crypto.crypto_one_time_aead(@cipher, key(), iv, ciphertext, @aad, tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> :error
    end
  end

  def decrypt(_), do: :error

  defp key do
    with encoded when is_binary(encoded) <- Application.get_env(:dashboard, __MODULE__)[:key],
         {:ok, key} when byte_size(key) == @key_size <- Base.decode64(encoded) do
      key
    else
      _ -> raise "Dashboard.Vault key is missing or is not a Base64 encoded 32 bytes key"
    end
  end
end
