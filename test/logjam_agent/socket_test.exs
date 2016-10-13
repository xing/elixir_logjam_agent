defmodule LogjamAgent.SocketTest do
  use LogjamAgent.ForwarderTestCase, async: false

  defmodule TestSocket do
    use LogjamAgent.Socket

    def connect(params, socket)
    def connect(%{reject_connect: true}, _socket) do
      :timer.sleep(50)
      :error
    end

    def connect(%{exception: true}, _socket) do
      :timer.sleep(50)
      raise "BOOM"
    end

    def connect(params, socket) do
      :timer.sleep(50)

      new = put_in(socket, [:assigns, :request_id], LogjamAgent.Metadata.current_request_id)

      {:ok, new}
    end

    def other(_conn, _socket) do
      :other
    end
  end

  def perform_action(opts \\ []) do
    params = Dict.get(opts, :params, %{})
    socket = Dict.get(opts, :socket, %{assigns: %{}})

    TestSocket.connect(params, socket)
  end

  test "instrumented actions publish to logjam" do
    assert {:ok, _socket} = perform_action
    assert [[msg]] = all_forwarded_log_messages
    assert {:log, %{action: "SocketTest::TestSocket#connect"}} = msg
  end

  test "successful connects are represented as 200 status code" do
    assert {:ok, _socket} = perform_action
    assert [[msg]] = all_forwarded_log_messages
    assert {:log, %{code: 200}} = msg
  end

  test "request_id is assigned to the process" do
    assert {:ok, socket} = perform_action
    assert socket.assigns.request_id
  end

  test "failed connects are respresented as 401 status code" do
    assert :error = perform_action(params: %{reject_connect: true})
    assert [[msg]] = all_forwarded_log_messages
    assert {:log, %{code: 401}} = msg
  end

  test "fatally failed connects are represented as 500 status code" do
    assert :error = perform_action(params: %{exception: true})
    assert [[msg]] = all_forwarded_log_messages
    assert {:log, %{code: 500}} = msg
  end

  test "other functions stay uninstrumented" do
    assert :other = TestSocket.other(:nil, :nil)
    assert [[]] = all_forwarded_log_messages
  end
end
