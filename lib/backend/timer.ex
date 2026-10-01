#
## EPITECH PROJECT, 2026
## timer.ex
## File description:
## GenServer that refreshes each widget instance on its own refresh rate
#

defmodule Dashboard.Timer do
  @moduledoc """
  Schedules a refresh for every widget instance according to its `refresh_rate`.

  Instances communicate their rate (in seconds) through `register/1`. When the
  interval elapses, the timer broadcasts `{:refresh_widget, id}` on the
  `"dashboard:user:<user_id>"` topic of `Dashboard.PubSub`, then schedules the
  next refresh. Fetching the data stays outside this process: subscribers
  react to the broadcast.
  """

  use GenServer

  alias Dashboard.Widgets
  alias Dashboard.Widgets.WidgetInstance

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Tracks a widget instance and (re)schedules its next refresh.

  Calling it again for the same id replaces the previous schedule, which is
  how a new refresh rate takes effect.
  """
  def register(server \\ __MODULE__, %WidgetInstance{} = widget) do
    GenServer.call(server, {:register, widget.id, widget.user_id, widget.refresh_rate})
  end

  @doc """
  Stops refreshing a widget instance.
  """
  def unregister(server \\ __MODULE__, id) when is_integer(id) do
    GenServer.call(server, {:unregister, id})
  end

  @doc """
  Returns the refresh rate (seconds) currently scheduled for `id`, or `nil`.
  """
  def get_refresh_rate(server \\ __MODULE__, id) when is_integer(id) do
    GenServer.call(server, {:get_refresh_rate, id})
  end

  @impl true
  def init(opts) do
    config = Application.get_env(:dashboard, __MODULE__, [])

    state = %{
      entries: %{},
      ms_per_second: Keyword.get(opts, :ms_per_second, Keyword.get(config, :ms_per_second, 1_000))
    }

    if Keyword.get(opts, :load_instances, Keyword.get(config, :load_instances, true)) do
      send(self(), :load_instances)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:register, id, user_id, refresh_rate}, _from, state)
      when is_integer(refresh_rate) and refresh_rate > 0 do
    {:reply, :ok, put_entry(state, id, user_id, refresh_rate)}
  end

  def handle_call({:unregister, id}, _from, state) do
    {:reply, :ok, drop_entry(state, id)}
  end

  def handle_call({:get_refresh_rate, id}, _from, state) do
    rate =
      case Map.get(state.entries, id) do
        %{refresh_rate: refresh_rate} -> refresh_rate
        nil -> nil
      end

    {:reply, rate, state}
  end

  @impl true
  def handle_info(:load_instances, state) do
    state =
      Enum.reduce(Widgets.list_all(), state, fn widget, state ->
        put_entry(state, widget.id, widget.user_id, widget.refresh_rate)
      end)

    {:noreply, state}
  end

  def handle_info({:refresh, id, token}, state) do
    case Map.get(state.entries, id) do
      %{token: ^token, user_id: user_id, refresh_rate: refresh_rate} ->
        Phoenix.PubSub.broadcast(
          Dashboard.PubSub,
          "dashboard:user:#{user_id}",
          {:refresh_widget, id}
        )

        {:noreply, put_entry(state, id, user_id, refresh_rate)}

      _ ->
        {:noreply, state}
    end
  end

  defp put_entry(state, id, user_id, refresh_rate) do
    state = drop_entry(state, id)
    {timer, token} = schedule(id, refresh_rate, state.ms_per_second)

    entry = %{
      id: id,
      user_id: user_id,
      refresh_rate: refresh_rate,
      timer: timer,
      token: token
    }

    %{state | entries: Map.put(state.entries, id, entry)}
  end

  defp schedule(id, refresh_rate, ms_per_second) do
    token = make_ref()
    timer = Process.send_after(self(), {:refresh, id, token}, refresh_rate * ms_per_second)
    {timer, token}
  end

  defp drop_entry(state, id) do
    case Map.pop(state.entries, id) do
      {%{timer: timer}, entries} ->
        Process.cancel_timer(timer)
        %{state | entries: entries}

      {nil, _entries} ->
        state
    end
  end
end
