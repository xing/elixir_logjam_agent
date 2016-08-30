defmodule LogjamAgent.ActionTest do
  use LogjamAgent.ForwarderTestCase, async: false

  defmodule TestMod do
    use LogjamAgent.Action

    def instrumented_action(conn) do
      :timer.sleep(50)

      :instrumented
    end

    @logjam false
    def uninstrumented_action(conn) do
      :timer.sleep(50)

      :uninstrumented
    end
  end

  test "instrumented actions retain their functionality" do
    assert :instrumented = TestMod.instrumented_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})
  end

  test "instrumented actions publish to logjam" do
    TestMod.instrumented_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

    assert [[msg]] = all_forwarded_log_messages
    assert {:log, %{action: "LogjamAgent::ActionTest::TestMod#instrumented_action"}} = msg
  end

  test "uninstrumented actions retain their functionality" do
    assert :uninstrumented = TestMod.uninstrumented_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})
  end

  test "uninstrumented action do not publish to logjam" do
    TestMod.uninstrumented_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

    assert [[]] = all_forwarded_log_messages
  end
end
