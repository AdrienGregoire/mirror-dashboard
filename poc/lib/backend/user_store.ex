defmodule Poc.UserStore do
  @table :users

  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table])
    end
  end

  def create(email, password) do
    case find_by_email(email) do
      nil ->
        hash = :crypto.hash(:sha256, password) |> Base.encode16()
        :ets.insert(@table, {email, hash})
        {:ok, email}
      _ ->
        {:error, :already_exists}
    end
  end

  def find_by_email(email) do
    case :ets.lookup(@table, email) do
      [{email, hash}] -> %{email: email, hash: hash}
      [] -> nil
    end
  end

  def authenticate(email, password) do
    hash = :crypto.hash(:sha256, password) |> Base.encode16()
    case find_by_email(email) do
      %{hash: ^hash} -> {:ok, email}
      _ -> {:error, :invalid}
    end
  end
end
