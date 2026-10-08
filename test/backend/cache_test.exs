#
## EPITECH PROJECT, 2026
## cache_test.exs
## File description:
## ExUnit for Dashboard.Cache
#

defmodule Dashboard.CacheTest do
  use ExUnit.Case, async: false

  alias Dashboard.Cache

  setup do
    Application.put_env(:dashboard, Cache, enabled: true)
    Cache.clear()

    on_exit(fn ->
      Application.put_env(:dashboard, Cache, enabled: false)
      Cache.clear()
    end)
  end

  defp counter_fun(counter, result) do
    fn ->
      Agent.update(counter, &(&1 + 1))
      result
    end
  end

  setup do
    {:ok, counter} = Agent.start_link(fn -> 0 end)
    %{counter: counter}
  end

  test "serves a successful result without calling the function again", %{counter: counter} do
    fun = counter_fun(counter, {:ok, "data"})

    assert Cache.fetch(:key, 1_000, fun) == {:ok, "data"}
    assert Cache.fetch(:key, 1_000, fun) == {:ok, "data"}
    assert Agent.get(counter, & &1) == 1
  end

  test "keeps the keys apart", %{counter: counter} do
    assert Cache.fetch(:a, 1_000, counter_fun(counter, {:ok, 1})) == {:ok, 1}
    assert Cache.fetch(:b, 1_000, counter_fun(counter, {:ok, 2})) == {:ok, 2}
    assert Agent.get(counter, & &1) == 2
  end

  test "never caches errors", %{counter: counter} do
    fun = counter_fun(counter, {:error, "boom"})

    assert Cache.fetch(:key, 1_000, fun) == {:error, "boom"}
    assert Cache.fetch(:key, 1_000, fun) == {:error, "boom"}
    assert Agent.get(counter, & &1) == 2
  end

  test "calls the function again once the entry has expired", %{counter: counter} do
    fun = counter_fun(counter, {:ok, "data"})

    Cache.fetch(:key, 20, fun)
    Process.sleep(40)
    Cache.fetch(:key, 20, fun)

    assert Agent.get(counter, & &1) == 2
  end

  test "does not cache with a zero ttl or when disabled", %{counter: counter} do
    fun = counter_fun(counter, {:ok, "data"})

    Cache.fetch(:key, 0, fun)
    Cache.fetch(:key, 0, fun)
    assert Agent.get(counter, & &1) == 2

    Application.put_env(:dashboard, Cache, enabled: false)
    Cache.fetch(:other, 1_000, fun)
    Cache.fetch(:other, 1_000, fun)
    assert Agent.get(counter, & &1) == 4
  end

  test "clear/0 drops the entries", %{counter: counter} do
    fun = counter_fun(counter, {:ok, "data"})

    Cache.fetch(:key, 1_000, fun)
    Cache.clear()
    Cache.fetch(:key, 1_000, fun)

    assert Agent.get(counter, & &1) == 2
  end
end
