#
## EPITECH PROJECT, 2026
## vault_test.exs
## File description:
## ExUnit for Dashboard.Vault
#

defmodule Dashboard.VaultTest do
  use ExUnit.Case, async: true
  alias Dashboard.Vault

  test "decrypts what it encrypted" do
    assert {:ok, "my-secret-token"} = "my-secret-token" |> Vault.encrypt() |> Vault.decrypt()
  end

  test "never produces the same ciphertext twice nor leaks the plaintext" do
    first = Vault.encrypt("my-secret-token")
    second = Vault.encrypt("my-secret-token")

    assert first != second
    refute first =~ "my-secret-token"
  end

  test "rejects a tampered ciphertext" do
    <<head::binary-size(30), byte, rest::binary>> = Vault.encrypt("my-secret-token")
    tampered = head <> <<Bitwise.bxor(byte, 1)>> <> rest

    assert Vault.decrypt(tampered) == :error
  end

  test "rejects garbage" do
    assert Vault.decrypt("too short") == :error
    assert Vault.decrypt(nil) == :error
  end
end
