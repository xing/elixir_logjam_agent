defmodule LogjamAgent.Forwarder do
  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
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
    # FIXME: logjam needs to be defined as application and added as such in the applications list, otherwise
    # the config entries can't be read and just return nil within the release bundle
    config = Application.get_env(:logjam, :forwarder) || %{enabled: false}
    config |> Enum.into(%{})
  end

  defp init_env(state) do
    connection = Exrabbit.Producer.new(
      exchange: "request-stream-#{state.config.app_name}-#{Mix.env}",
      conn_opts: [host: state.config.amqp.broker])

     state
      |> Dict.put(:amqp, connection)
      |> Dict.put(:routing_key, "logs.#{state.config.app_name}.#{Mix.env}")
  end
end
