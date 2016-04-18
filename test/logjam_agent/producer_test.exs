Code.require_file("integrated_test_case.exs", "test/support/")

defmodule LogjamAgent.ProducerTest do
  use LogjamAgent.IntegratedTestCase
  @moduletag uses_rabbitmq: true
  @routing_key "test_routing_key"

  test "connect/1 connects to the broker" do
    {result, _value} = LogjamAgent.Producer.connect(amqp_options: [host: "localhost"], exchange: "test_exchange")

    assert result == :ok
  end

  test "publish/3 publishes the given message" do
    payload = unique_message
    run_publish = fn -> LogjamAgent.Producer.publish(create_producer, payload, @routing_key) end

    assert consume_message(run_publish, routing_key: @routing_key) == payload
  end

  test "publish/3 publishes the message for the specified routing_key" do
    payload     = unique_message
    run_publish = fn -> create_producer |> LogjamAgent.Producer.publish(payload, @routing_key) end

    assert consume_message(run_publish, routing_key: @routing_key) == payload
  end

  test "disconnect/3 stops the producer" do
    producer = create_producer
    :timer.sleep(200)
    disconnected_producer = LogjamAgent.Producer.disconnect(producer)

    refute Map.get(disconnected_producer, :connection)
    refute Map.get(disconnected_producer, :channel)
  end

  test "disconnect/3 stops the producer gracefully when the channel has crashed" do
    producer = create_producer
    :timer.sleep(200)

    Process.exit(producer.channel.pid, :kill)
    :timer.sleep(200)
    disconnected_producer = LogjamAgent.Producer.disconnect(producer)

    refute Map.get(disconnected_producer, :connection)
    refute Map.get(disconnected_producer, :channel)
  end

  test "disconnect/3 stops the producer gracefully when the connection has crashed" do
    producer = create_producer
    :timer.sleep(200)

    Process.exit(producer.connection.pid, :kill)
    :timer.sleep(100)
    disconnected_producer = LogjamAgent.Producer.disconnect(producer)

    refute Map.get(disconnected_producer, :connection)
    refute Map.get(disconnected_producer, :channel)
  end
end
