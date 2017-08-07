defmodule LogjamAgent.Forwarders.Proxy do
  use GenServer

  alias LogjamAgent.Config
  alias LogjamAgent.Forwarders.{Pool, ZMQForwarder}

  @forwarder Application.get_env(:logjam_agent, :forwarder_module, ZMQForwarder)

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_) do
    state = %{config: Config.current}
    Process.send_after(self(), :connect, state.config.initial_connect_delay)
    {:ok, state}
  end

  def forward(pid, {type, msg}) do
    GenServer.cast(pid, {:forward, type, msg})
  end

  def reload_config(pid, config) do
    GenServer.call(pid, {:reload_config, config})
  end

  def forwarder_pid(pid) do
    GenServer.call(pid, :forwarder_pid)
  end

  @doc """
    Is primarily used for testing to obtain the pid
    of the proxied forwarder
  """
  def handle_call(:forwarder_pid, _from, state) do
    {:reply, Map.get(state, :forwarder_pid), state}
  end

  @doc """
    Reloads the configuration and re-establishes the ZMQ socket
  """
  def handle_call({:reload_config, config}, _from, state) do
    new_state = reconnect(%{state | config: config})
    {:reply, new_state, new_state}
  end

  @doc """
    Forwards logjam information to the ZMQ socket
  """
  def handle_cast({:forward, type, msg}, %{forwarder_pid: forwarder_pid} = state) do
    try do
      @forwarder.forward(forwarder_pid, {type, msg})
    after
      Pool.checkin(self())
    end

    {:noreply, state}
  end

  @doc """
    Blackhole for forwarded messages when no active ZMQ socket exists
  """
  def handle_cast({:forward, _type, _msg}, state) do
    {:noreply, state}
  end

  @doc """
    (Re-) establishes the ZMQ connection
  """
  def handle_info(:connect, state) do
    {:noreply, connect(state)}
  end

  @doc """
    Monitor messages that handle when the ZMQ socket went down.
    Only restarts the ZMQ socket, when it really crashed
  """
  def handle_info({:DOWN, _reference, :process, pid, :normal}, %{forwarder_pid: forwarder_pid} = state) when forwarder_pid != pid do
    {:noreply, state}
  end
  def handle_info({:DOWN, _reference, :process, _pid, :normal}, state) do
    {:noreply, disconnect(state)}
  end
  def handle_info({:DOWN, _reference, :process, _pid, {:shutdown, :normal}}, state) do
    {:noreply, disconnect(state)}
  end
  def handle_info({:DOWN, _reference, :process, _pid, _reason}, state) do
    {:noreply, reconnect(state)}
  end

  defp reconnect(state) do
    state
      |> disconnect
      |> connect
  end

  defp disconnect(state)
  defp disconnect(%{forwarder_pid: forwarder_pid} = state) do
    stop_forwarder(forwarder_pid)
    Map.delete(state, :forwarder_pid)
  end
  defp disconnect(state) do
    state
  end

  defp connect(state)
  defp connect(%{config: %{enabled: false}} = state) do
    state
  end
  defp connect(%{config: config} = state) do
    {:ok, pid} = @forwarder.start(config)
    _reference = Process.monitor(pid)
    Map.put(state, :forwarder_pid, pid)
  end

  defp stop_forwarder(pid) do
    try do
      @forwarder.stop(pid)
    catch
      :noproc ->
        :ok
      :exit, _reason ->
        :ok
    end
  end
end
