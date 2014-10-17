defmodule LogjamAgent.ForwarderPool do
  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def forward(buffer) do
    GenServer.cast(__MODULE__, {:forward, buffer})
  end

  def init(_) do
    { :ok, %{} }
  end

  def handle_cast({:forward, buffer}, state) do
    worker = :poolboy.checkout :logjam_forwarder_pool
    LogjamAgent.Forwarder.forward(worker, buffer)

    {:noreply, state}
  end
end
