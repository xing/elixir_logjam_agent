defmodule LogjamAgent.ActionTest do
  use LogjamAgent.ForwarderTestCase, async: false

  defmodule TestModWithoutOptions do
    use LogjamAgent.Action

    def some_action(conn) do
      :timer.sleep(50)

      :instrumented
    end

    def action(conn, other) do
      :timer.sleep(50)

      :excluded_by_default
    end

    def action_returning_conn(conn), do: conn
  end

  defmodule TestMod do
    use LogjamAgent.Action, except: [excluded_action: 1, some_action: 2]

    def excluded_action(conn) do
      :timer.sleep(50)

      :excluded
    end

    def action(conn, other) do
      :timer.sleep(50)

      :excluded_by_default
    end

    def some_action(conn) do
      :timer.sleep(50)

      :instrumented
    end

    def some_action(conn, param) do
      :timer.sleep(50)

      :excluded
    end
  end

  describe "when no options are specified" do
    test "instrumented actions retain their functionality" do
      assert :instrumented = TestModWithoutOptions.some_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})
    end

    test "instrumented actions publish to logjam" do
      TestModWithoutOptions.some_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{action: "ActionTest::TestModWithoutOptions#some_action"}} = msg
    end

    test "instrumented action is set in the header and stored in Metadata" do
      conn = TestModWithoutOptions.action_returning_conn(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

      assert Plug.Conn.get_resp_header(conn, "x-logjam-request-action") == ["ActionTest::TestModWithoutOptions#action_returning_conn"]
      assert LogjamAgent.Metadata.fetch(:action) == "ActionTest::TestModWithoutOptions#action_returning_conn"
    end

    test "action/2 is globally excluded" do
      TestModWithoutOptions.action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"}, :argument)

      assert [[]] = all_forwarded_log_messages
    end
  end

  describe "when :except option is specified" do
    test "instrumented actions retain their functionality" do
      assert :instrumented = TestMod.some_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})
    end

    test "instrumented actions publish to logjam" do
      TestMod.some_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{action: "ActionTest::TestMod#some_action"}} = msg
    end

    test "exclude actions if name and arity match" do
      TestMod.some_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"}, :additional_argument)

      assert [[]] = all_forwarded_log_messages
    end

    test "does not exclude if the name matches but not the arity" do
      TestMod.some_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{action: "ActionTest::TestMod#some_action"}} = msg
    end

    test "action/2 is globally excluded by default" do
      TestMod.action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"}, :argument)

      assert [[]] = all_forwarded_log_messages
    end

      test "uninstrumented actions retain their functionality" do
      assert :excluded = TestMod.excluded_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})
    end

    test "uninstrumented action do not publish to logjam" do
      TestMod.excluded_action(%Plug.Conn{req_headers: %{}, query_string: "foo", method: "get"})

      assert [[]] = all_forwarded_log_messages
    end
  end
end
