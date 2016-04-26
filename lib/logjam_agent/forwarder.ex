defmodule LogjamAgent.Forwarder do
  use GenServer
  alias LogjamAgent.Metadata
  alias Poison, as: JSON
  require Logger

  @heartbeat 60

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_) do
    Process.flag(:trap_exit, true)

    state = pre_connect_state
    Process.send_after(self, :reconnect, state.config.initial_connect_delay)

    {:ok, state}
  end

  def terminate(_reason, state) do
    Logger.debug("forwarder terminated")
    disconnect_producer(state)
  end

  def forward(pid, msg) do
    GenServer.cast(pid, {:forward, msg, :log})
  end

  def forward_event(pid, msg) do
    GenServer.cast(pid, {:forward, msg, :event})
  end

  def reload_config(pid) do
    GenServer.cast(pid, :reload_config)
  end

  def handle_call(:config, _from, state) do
    {:reply, state.config, state}
  end

  def handle_cast({:forward, msg, :log}, state) do
    if message_high_water_mark?(state.config.forwarder_high_water_mark) do
      {:noreply, state}
    else
      do_forward(msg, state, Map.get(state, :routing_key))
    end
  end

  def handle_cast({:forward, msg, :event}, state) do
    do_forward(msg, state, Map.get(state, :event_routing_key))
  end

  def handle_cast(:reload_config, state) do
    {:noreply, reconnect(state)}
  end

  def handle_info(:reconnect, state) do
    {:noreply, reconnect(state)}
  end

  defp do_forward(msg, %{amqp: %LogjamAgent.Producer{}, config: %{enabled: true}} = state, routing_key) do
    LogjamAgent.Producer.publish(state.amqp, JSON.encode!(msg), routing_key)
    :poolboy.checkin :logjam_forwarder_pool, self

    {:noreply, state}
  end

  defp do_forward(msg, state, _routing_key) do
    debug_output(msg, state)

    {:noreply, state}
  end

  defp reconnect(current_state) do
    Logger.info("reconnecting forwarder")

    disconnect_producer(current_state)
    pre_connect_state
     |> configure
     |> connect_producer
  end

  defp pre_connect_state, do: %{config: LogjamAgent.Config.current}

  defp disconnect_producer(%{amqp: conn} = state) do
    LogjamAgent.Producer.disconnect(conn)
    Logger.debug("disconected producer: #{inspect(conn)}")
    Map.delete(state, :amqp)
  end

  defp disconnect_producer(state) do
    {:ok, state}
  end

  defp connect_producer(%{config: %{enabled: true}} = state) do
    {:ok, conn} = LogjamAgent.Producer.start_link(
                   exchange: state.exchange,
                   amqp_options: Keyword.merge([heartbeat: @heartbeat], state.config.amqp))

    Logger.debug("connected producer: #{inspect(conn)}")
    Map.put(state, :amqp, conn)
  end

  defp connect_producer(state) do
    Logger.warn("forwarder disabled. will not connect producer")
    state
  end

  defp configure(state) do
    config = LogjamAgent.Config.current

    state
     |> Map.put(:config, config)
     |> Map.put(:exchange, "request-stream-#{state.config.app_name}-#{Metadata.logjam_env}")
     |> Map.put(:routing_key, "logs.#{state.config.app_name}.#{Metadata.logjam_env}")
     |> Map.put(:event_routing_key, "events.#{state.config.app_name}.#{Metadata.logjam_env}")
  end

  defp debug_output(transformed, %{config: %{debug_to_stdout: true}}) do
    IO.puts "Forwarder received data: #{inspect(transformed)}"
  end

  defp debug_output(transformed, _state) do
    transformed
  end

  defp message_high_water_mark?(nil), do: false
  defp message_high_water_mark?(high_water_mark) do
    {:message_queue_len, len} = Process.info(self, :message_queue_len)
    len > high_water_mark
  end
end
