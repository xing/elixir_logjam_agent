Code.require_file("test_log_data.exs", "test/support/")

defmodule LogjamAgent.Forwarders.ZMQForwarderTest do
  use ExUnit.Case

  alias LogjamAgent.{Config, Forwarders.ZMQForwarder, Transformer}
  alias Poison, as: JSON

  setup do
    config = Config.current

    {:ok, receiver} = :ezmq.start_link(type: :dealer)
    {proto, _host, port} = ZMQForwarder.default_endpoint
    :ok = :ezmq.bind(receiver, proto, port, [])
    {:ok, forwarder} = ZMQForwarder.start(config)

    context = %{
      forwarder: forwarder,
      data:  Transformer.to_logjam_msg(TestLogData.new),
      receiver: receiver,
      config: config
    }

    {:ok, context}
  end

  test "can forward messages to another socket", %{forwarder: forwarder, data: data, receiver: receiver} do
    :ok = ZMQForwarder.forward(forwarder, {:log, data})

    assert {:ok, [app_env, routing_key, msg, meta]} = :ezmq.recv(receiver)
    assert app_env == "logjam_agent-test"
    assert routing_key == "logs.logjam_agent.test"

    received_msg = JSON.decode!(msg)

    assert received_msg["host"] == data.host
    assert received_msg["action"] == "DummyController#dummy"
    assert received_msg["severity"] == 2
    assert received_msg["total_time"] == 2_000_000
    assert [
      [2, "2014-09-17T10:17:58.221", _m1],
      [0, "2014-09-17T10:17:58.213", _m2],
      [1, "2014-09-17T10:17:58.40", _m3]
    ] = received_msg["lines"]

    assert <<0xcabd::big-integer-unsigned-size(16),
      0::big-integer-unsigned-size(8),
      1::integer-unsigned-size(8),
      0::big-integer-unsigned-size(32),
      _zclock_time::big-integer-unsigned-size(64),
      1::big-integer-unsigned-size(64)>> = meta
  end

  test "shuts down forwarder on parent exit", %{config: config} do
    parent = spawn(fn -> Process.sleep(1000) end)
    {:ok, forwarder} = GenServer.start(ZMQForwarder, {parent, config})

    assert Process.alive?(parent)
    assert Process.alive?(forwarder)

    Process.exit(parent, :kill)
    Process.sleep(5)

    refute Process.alive?(forwarder)
  end
end
