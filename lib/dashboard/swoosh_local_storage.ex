defmodule Dashboard.SwooshLocalStorage do
  @moduledoc """
  Ensures the process backing `Swoosh.Adapters.Local` (used to fake email
  sending in dev/local Docker) is actually running.
  """

  def child_spec(_opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, []}, restart: :transient}
  end

  def start_link do
    case Swoosh.Adapters.Local.Storage.Manager.start_link() do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> :ignore
      other -> other
    end
  end
end
