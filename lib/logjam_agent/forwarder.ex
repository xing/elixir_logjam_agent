defmodule LogjamAgent.Forwarder do
  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
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

  def init(_) do
    state = %{config: load_config }

    if state.config.enabled do
      { :ok, init_env(state) }
    else
      { :ok, state }
    end
  end

  def handle_call(:config, _from, state) do
    {:reply, state.config, state}
  end

  def handle_cast({:forward, msg, :log}, state) do
    forward(msg, state, state.routing_key)
  end

  def handle_cast({:forward, msg, :event}, state) do
    forward(msg, state, state.event_routing_key)
  end

  def handle_cast(:reload_config, _state) do
    { :ok, new_state } = init(:ok)
    {:noreply, new_state}
  end


  defp forward(msg, state, routing_key) do
    if state.config.enabled do
      Exrabbit.Producer.publish(state.amqp, Jazz.encode!(msg), routing_key: routing_key)
    else
      debug_output(msg)
    end
    :poolboy.checkin :logjam_forwarder_pool, self

    {:noreply, state}
  end

  defp debug_output(transformed) do
    IO.puts "Forwarder received data"
    IO.inspect(transformed)
  end

  defp load_config do
    config = Application.get_env(:logjam_agent, :forwarder) || %{enabled: false}
    config |> Enum.into(%{})
  end

  defp init_env(state) do
    connection = Exrabbit.Producer.new(
      exchange: "request-stream-#{state.config.app_name}-#{logjam_env}",
      conn_opts: [host: state.config.amqp.broker])

     state
      |> Dict.put(:amqp, connection)
      |> Dict.put(:routing_key, "logs.#{state.config.app_name}.#{logjam_env}")
      |> Dict.put(:event_routing_key, "events.#{state.config.app_name}.#{logjam_env}")
  end

  defp logjam_env do
    case Mix.env do
      :prod -> :production
      env   -> env
    end
  end
end
