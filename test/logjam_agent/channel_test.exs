defmodule LogjamAgent.ChannelTest do
  use LogjamAgent.ForwarderTestCase, async: false

  defmodule TestChannel do
    use LogjamAgent.Channel

    intercept ["test"]
    log_assigns [:user_id, :consumer_key]

    def join(topic, params, socket)
    def join(_topic, %{reject_join: true}, socket) do
      :timer.sleep(50)
      {:error, %{sample: :error}}
    end
    def join(_topic, %{exception: true}, socket) do
      :timer.sleep(50)
      raise "BOOM"
    end
    def join(_topic, params, socket) do
      :timer.sleep(50)
      {:ok, socket}
    end

    def handle_in(event, params, socket)
    def handle_in(_event, %{reply: true}, socket) do
      :timer.sleep(50)
      {:reply, %{the: :reply}, socket}
    end
    def handle_in(_event, %{exception: true}, socket) do
      :timer.sleep(50)
      raise "BOOM"
    end
    def handle_in(_event, %{stop: true}, socket) do
      :timer.sleep(50)
      {:stop, :normal, socket}
    end
    def handle_in(_event, params, socket) do
      :timer.sleep(50)
      {:noreply, socket}
    end

    def handle_out(event, params, socket)
    def handle_out(_event, %{stop: true}, socket) do
      :timer.sleep(50)
      {:stop, :normal, socket}
    end
    def handle_out(_event, %{exception: true}, socket) do
      :timer.sleep(50)
      raise "BOOM"
    end
    def handle_out(_event, params, socket) do
      :timer.sleep(50)
      {:noreply, socket}
    end

    def other(_event, _params, _socket) do
      :other
    end
  end

  test "Phoenix intercepts are properly injected" do
    assert ["test"] = TestChannel.__intercepts__
  end

  test "other functions stay uninstrumented" do
    assert :other = TestChannel.other(:nil, :nil, :nil)
    assert [[]] = all_forwarded_log_messages
  end

  describe ".join" do
    def perform_join(opts \\ []) do
      topic  = Dict.get(opts, :topic, "")
      params = Dict.get(opts, :params, %{})
      socket = Dict.get(opts, :socket, %{assigns: %{}})

      TestChannel.join(topic, params, socket)
    end

    test "instrumented actions publish to logjam" do
      assert {:ok, _socket} = perform_join
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{action: "ChannelTest::TestChannel#join"}} = msg
    end

    test "successful joins are represented as 200 status code" do
      assert {:ok, _socket} = perform_join
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{code: 200}} = msg
    end

    test "failed joins are respresented as 401 status code" do
      assert {:error, %{}} = perform_join(params: %{reject_join: true})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{code: 401}} = msg
    end

    test "pattern matched params still forward complete params to logjam" do
      assert {:error, %{}} = perform_join(params: %{reject_join: true, foo: :bar})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{request_info: %{headers: %{reject_join: true, foo: :bar}}}} = msg
    end

    test "fatally failed joins are represented as 500 status code" do
      assert {:error, %{error_type: :internal}} = perform_join(params: %{exception: true})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{code: 500}} = msg
    end

    test "explicitly specified log parameters are also written to request_info" do
      assigns = %{
        user_id: "USER_ID",
        consumer_key: "CONSUMER_KEY",
        access_token: "ACCESS_TOKEN"
      }

      assert {:ok, _socket} = perform_join(socket: %{assigns: assigns})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{request_info: %{headers: headers}}} = msg
      assert %{user_id: "USER_ID", consumer_key: "CONSUMER_KEY"} = headers
    end
  end

  describe ".handle_in" do
    def perform_handle_in(opts \\ []) do
      event   = Dict.get(opts, :event, "")
      payload = Dict.get(opts, :payload, %{})
      socket  = Dict.get(opts, :socket, %{assigns: %{}})

      TestChannel.handle_in(event, payload, socket)
    end

    test "instrumented actions publish to logjam" do
      assert {:noreply, _socket} = perform_handle_in
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{action: "ChannelTest::TestChannel#handle_in"}} = msg
    end

    test "successful handle_in invocations are represented as 200 status code" do
      assert {:noreply, _socket} = perform_handle_in
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{code: 200}} = msg
    end

    test "replies to handle_in invocations are handled properly" do
      assert {:reply, %{the: :reply}, _socket} = perform_handle_in(payload: %{reply: true})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{code: 200}} = msg
    end

    test "pattern matched params still forward complete params to logjam" do
      assert {:reply, _, _} = perform_handle_in(payload: %{reply: true, foo: :bar})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{request_info: %{headers: %{reply: true, foo: :bar}}}} = msg
    end

    test "fatally failed handle_in invocations are represented as 500 status code" do
      assert {:noreply, %{}} = perform_handle_in(payload: %{exception: true})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{code: 500}} = msg
    end

    test "explicitly specified log parameters are also written to request_info" do
      assigns = %{
        user_id: "USER_ID",
        consumer_key: "CONSUMER_KEY",
        access_token: "ACCESS_TOKEN"
      }

      assert {:noreply, _socket} = perform_handle_in(socket: %{assigns: assigns})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{request_info: %{headers: headers}}} = msg
      assert %{user_id: "USER_ID", consumer_key: "CONSUMER_KEY"} = headers
    end
  end

  describe ".handle_out" do
    def perform_handle_out(opts \\ []) do
      event   = Dict.get(opts, :event, "")
      payload = Dict.get(opts, :payload, %{})
      socket  = Dict.get(opts, :socket, %{assigns: %{}})

      TestChannel.handle_out(event, payload, socket)
    end

    test "instrumented actions publish to logjam" do
      assert {:noreply, _socket} = perform_handle_out
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{action: "ChannelTest::TestChannel#handle_out"}} = msg
    end

    test "successful handle_out invocations are represented as 200 status code" do
      assert {:noreply, _socket} = perform_handle_out
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{code: 200}} = msg
    end

    test "pattern matched params still forward complete params to logjam" do
      assert {:stop, :normal, _} = perform_handle_out(payload: %{stop: true, foo: :bar})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{request_info: %{headers: %{stop: true, foo: :bar}}}} = msg
    end

    test "fatally failed handle_out invocations are represented as 500 status code" do
      assert {:noreply, %{}} = perform_handle_out(payload: %{exception: true})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{code: 500}} = msg
    end

    test "explicitly specified log parameters are also written to request_info" do
      assigns = %{
        user_id: "USER_ID",
        consumer_key: "CONSUMER_KEY",
        access_token: "ACCESS_TOKEN"
      }

      assert {:noreply, _socket} = perform_handle_out(socket: %{assigns: assigns})
      assert [[msg]] = all_forwarded_log_messages
      assert {:log, %{request_info: %{headers: headers}}} = msg
      assert %{user_id: "USER_ID", consumer_key: "CONSUMER_KEY"} = headers
    end
  end
end
