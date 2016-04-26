defmodule LogjamAgent.Producer do
  require Logger
  use AMQP

  @moduledoc """
    A simple abstraction that implements an AMQP client that can publish messages

    Example:
      LogjamAgent.Producer(amqp_options: [host: "localhost"], exchange: "exchange_name")
  """
  alias __MODULE__
  defstruct connection: nil, channel: nil, exchange: nil

  @doc """
    Connect to the specified AMQP broker and return a producer

    * `amqp_options` - A keyword list of options compatible with the options of AMQP.Connection.open/1
    * `exchange` - The exchange to use for all operations
  """
  def connect(options) do
    with {:ok, amqp_opts} <- Keyword.fetch(options, :amqp_options),
         {:ok, exchange}  <- Keyword.fetch(options, :exchange),
         {:ok, conn}      <- Connection.open(amqp_opts),
         {:ok, chan}      <- Channel.open(conn),
      do: {:ok, %Producer{connection: conn, channel: chan, exchange: exchange}}
  end

  @doc """
    Disconnect the producer, thus releasing the channel and the connection
  """
  def disconnect(%Producer{connection: conn, channel: chann} = producer) do
    if Process.alive?(conn.pid) do
      Process.unlink(conn.pid)
      Connection.close(conn)
    end

    producer
      |> Map.delete(:connection)
      |> Map.delete(:channel)
  end

  @doc """
    Connect to the message broker and link the connection to the current process
    Returns: {:ok, producer} or {:error, reason}
  """
  def start_link(options) do
    case connect(options) do
      {:ok, producer} ->
        Process.link(producer.connection.pid)
        {:ok, producer}
      error ->
        error
    end
  end

  @doc """
    Publish a message using the connected producer

    * `producer`      - the producer to use for publishing
    * `payload`       - the payload to publish
    * `routing_key`   - the routing_key to use for publishing
    * `ampq_options`  - a keyword list of options
  """
  def publish(producer, payload, routing_key, amqp_options \\ [])
  def publish(%Producer{channel: chan, exchange: exchange}, payload, routing_key, amqp_options) do
    Basic.publish(chan, exchange, routing_key, payload, amqp_options)
  end

  def publish(%Producer{}, _payload, _routing_key, _amqp_options) do
    Logger.warn("can not publish event, since the producer is not connected")
  end
end
