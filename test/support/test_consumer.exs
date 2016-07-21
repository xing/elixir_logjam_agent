defmodule LogjamAgent.TestConsumer do
  use GenServer
  use AMQP

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @exchange    "logjam_agent_test_exchange"
  @queue       "logjam_agent_test_queue"

  def init(options) do
    {:ok, conn} = Connection.open("amqp://guest:guest@localhost")
    {:ok, chan} = Channel.open(conn)
    exchange    = Keyword.get(options, :exchange, @exchange)
    routing_key = Keyword.get(options, :routing_key, "")

    queue = Queue.declare(chan, @queue, durable: false, auto_delete: true)
    Exchange.topic(chan, exchange, auto_delete: true)
    Queue.bind(chan, @queue, exchange, routing_key: routing_key)

    {:ok, _consumer_tag} = Basic.consume(chan, @queue)
    {:ok, %{channel: chan, messages: [], queue: queue}}
  end

  def exchange, do: @exchange
  def queue,    do: @queue

  def messages,       do: GenServer.call(__MODULE__, :messages)
  def store(payload), do: GenServer.cast(__MODULE__, {:store, payload})

  def last_message do
    case messages do
      []           -> nil
      [latest | _] -> latest
    end
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, _}, chan) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, _}, chan) do
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, _},  chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, _}, chan) do
    store(payload)

    {:noreply, chan}
  end

  def handle_cast({:store, data}, %{messages: messages} = state) do
    {:noreply, %{ state | messages: [data | messages] }}
  end

  def handle_call(:messages, _from, %{messages: messages} = state) do
    {:reply, messages, state}
  end
end
