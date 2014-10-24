defmodule LogjamAgent.SystemMetrics do
  use GenServer

  # Some of the system metrics are expensive to query, therefore we don't update them in real time
  @update_interval 1000

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def update do
    GenServer.cast(__MODULE__, :update)
  end

  def init(_) do
    :timer.apply_interval(@update_interval, LogjamAgent.SystemMetrics, :update, [])
    { :ok, get_metrics }
  end

  def handle_call(:get, _from, state) do
    { :reply, state, state }
  end

  def handle_cast(:update, state) do
    { :noreply, get_metrics }
  end

  defp get_metrics do
    %{
      processes: length(Process.list)
    }
  end

end
