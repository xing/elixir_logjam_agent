defmodule LogjamAgent.Forwarder do
  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  def forward(pid, buffer) do
    GenServer.cast(pid, {:pool_forward, buffer})
  end

  def forward(buffer) do
    GenServer.cast(__MODULE__, {:forward, buffer})
  end

  def config do
    GenServer.call(__MODULE__, :config)
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

  def handle_cast({:pool_forward, buffer}, state) do
    handle_cast({:forward, buffer}, state)
    :poolboy.checkin :logjam_forwarder_pool, self

    {:noreply, state}
  end

  def handle_cast({:forward, buffer}, state) do
    msg = LogjamAgent.Transformer.to_logjam_msg(buffer)

    if state.config.enabled do
      Exrabbit.Producer.publish(state.amqp, Jazz.encode!(msg), routing_key: state.routing_key)
    else
      debug_output(msg)
    end

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
  end

  defp logjam_env do
    case Mix.env do
      :prod -> :production
      env   -> env
    end
  end
end
