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

  def handle_cast(:update, _state) do
    { :noreply, get_metrics }
  end

  defp get_metrics do
    Dict.merge(static_metrics, dynamic_metrics)
  end

  defp dynamic_metrics do
    %{
      processes: length(Process.list),
      run_queue: :erlang.statistics(:run_queue),
      time_between_gc: uptime / gc_runs,
      total_memory: :erlang.memory[:total]
    }
  end

  defp static_metrics do
    %{
      host: hostname
    }
  end

  defp uptime do
    {sec, _} = :erlang.statistics(:wall_clock)
    sec
  end

  defp gc_runs do
    case :erlang.statistics(:garbage_collection) do
      {gc, _,_ } when gc == 0 -> 1
      {gc, _,_ } -> gc
    end
  end

  defp hostname do
    case System.cmd("hostname", ["-f"]) do
      {hostname, 0} -> hostname |> String.strip
      _             -> nil
    end
  end
end
