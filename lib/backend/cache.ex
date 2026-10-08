#
## EPITECH PROJECT, 2026
## cache.ex
## File description:
## Small in-memory TTL cache shared by the service providers
#

defmodule Dashboard.Cache do
  @moduledoc """
  ETS backed cache with a time to live per entry.

  Only successful results (`{:ok, value}`) are stored, so an error is always
  retried on the next call. Reads never go through the owning process, they hit
  the public ETS table directly. The process only creates the table and sweeps
  expired entries.

  The cache can be turned off with `config :dashboard, Dashboard.Cache, enabled: false`
  (this is what the test environment does).
  """

  use GenServer

  @table __MODULE__
  @sweep_every :timer.minutes(1)

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Returns the cached value of `key`, or runs `fun` and caches its result for
  `ttl_ms` milliseconds when it is `{:ok, value}`.
  """
  @spec fetch(term(), non_neg_integer(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def fetch(key, ttl_ms, fun) when is_integer(ttl_ms) and is_function(fun, 0) do
    if enabled?() and ttl_ms > 0 do
      case lookup(key) do
        {:ok, _value} = hit -> hit
        :miss -> fun.() |> store(key, ttl_ms)
      end
    else
      fun.()
    end
  end

  @doc """
  Removes every entry.
  """
  def clear do
    if :ets.whereis(@table) != :undefined, do: :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = now()
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] -> if expires_at > now(), do: {:ok, value}, else: :miss
      [] -> :miss
    end
  end

  defp store({:ok, value} = result, key, ttl_ms) do
    :ets.insert(@table, {key, value, now() + ttl_ms})
    result
  end

  defp store(result, _key, _ttl_ms), do: result

  defp enabled? do
    :ets.whereis(@table) != :undefined and
      Application.get_env(:dashboard, __MODULE__, []) |> Keyword.get(:enabled, true)
  end

  defp now, do: System.monotonic_time(:millisecond)
  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_every)
end
