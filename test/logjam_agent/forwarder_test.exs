Code.require_file("integrated_test_case.exs", "test/support/")

defmodule LogjamAgent.ForwarderTest do
  use LogjamAgent.IntegratedTestCase
  alias LogjamAgent.{Metadata, Config, Forwarder}
  @moduletag uses_rabbitmq: true

  setup do
    config     = Config.current
    exchange   = "request-stream-#{config.app_name}-#{Metadata.logjam_env}"
    {:ok, pid} = Forwarder.start_link

    {:ok, %{ config: config, exchange: exchange, forwarder: pid }}
  end

  test "forward/3 publishes the message", %{ exchange: exchange, forwarder: pid } do
    payload       = %{ key: unique_message }
    do_forward    = fn -> Forwarder.forward(pid, payload) end

    assert consume_message(do_forward, exchange: exchange, routing_key: "logs.logjam_agent.test") == Poison.encode!(payload)
  end
end
