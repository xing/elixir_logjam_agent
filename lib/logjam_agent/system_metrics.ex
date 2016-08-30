defmodule LogjamAgent.SystemMetrics do
  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def init(_) do
    {:ok, %{host: hostname}}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  defp hostname do
    case System.cmd("hostname", ["-f"]) do
      {fqdn, 0} -> fqdn |> String.strip
      _         -> nil
    end
  end
end
