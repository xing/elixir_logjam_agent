Code.require_file("integrated_test_case.exs", "test/support/")

defmodule LogjamAgent.ActionTest do
  use LogjamAgent.IntegratedTestCase
  alias LogjamAgent.{Metadata, Config}

  @moduletag uses_rabbitmq: true

  defmodule TestMod do
    use LogjamAgent.Action

    def instrumented_action(conn) do
      :timer.sleep(500)

      :instrumented
    end

    @logjam false
    def uninstrumented_action(conn) do
      :timer.sleep(500)

      :uninstrumented
    end
  end

  setup do
    config      = Config.current
    exchange    = "request-stream-#{config.app_name}-#{Metadata.logjam_env}"
    routing_key = "logs.#{config.app_name}.#{Metadata.logjam_env}"

    {:ok, %{config: config, exchange: exchange, routing_key: routing_key}}
  end

  test "instrumented actions publish to logjam", %{exchange: exchange, routing_key: routing_key} do
    action = fn ->
      TestMod.instrumented_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})
    end

    message = consume_message(action, exchange: exchange, routing_key: routing_key, filter: ~r/instrumented_action/)

    assert message
    assert Poison.decode!(message)["action"] == "LogjamAgent::ActionTest::TestMod#instrumented_action"

  end

  test "instrumented actions retain their functionality" do
    result = TestMod.instrumented_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

    assert result == :instrumented
  end

  test "uninstrumented action do not publish to logjam", %{exchange: exchange, routing_key: routing_key} do
    action = fn ->
      TestMod.uninstrumented_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})
    end

    refute consume_message(action, exchange: exchange, routing_key: routing_key, filter: ~r/ActionTest::TestMod#uninstrumented_action/)
  end

  test "uninstrumented actions retain their functionality" do
    result = TestMod.uninstrumented_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

    assert result == :uninstrumented
  end
end
