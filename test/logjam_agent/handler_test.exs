defmodule LogjamAgent.HandlerTest do
  use LogjamAgent.ForwarderTestCase, async: false

  alias Exbeetle.Client.ResultCode
  alias Exbeetle.Client.Message
  alias Poison, as: JSON

  defmodule TestHandler do
    use LogjamAgent.Handler

    def process(_msg) do
      Logger.warn("Wow such a cool message")
    end
  end

  def create_message(payload, headers \\ nil) do
    amqp_state  = %{
      message_id: "MESSAGE_ID",
      timeout:    12_345,
      headers:    headers || [
        {"flags", :integer, "1"},
        {"sender_action", :longstr, "Messages::ThreadsController#reply"},
        {"sender_id", :longstr, "messagesprimera-development_sandbox-08300cb2a1d44c4e8bdcf5b8a9461696"}
      ]
    }

    handler_settings = %{
      attempts: 1,
      exceptions: 0,
      timeout: 5_000,
      delay: 0
    }

    Message.load("TEST_QUEUE", JSON.encode!(payload), amqp_state, handler_settings)
  end

  def process(msg) do
    {:ok, msg1} = TestHandler.pre_process(msg)
    try do
      :ok = TestHandler.process(msg1)
      TestHandler.completed(msg1, ResultCode.ack)
    rescue
      ex ->
        TestHandler.completed(msg1, ResultCode.handler_crash(ex))
    end
  end

  describe "in case of successful processing" do
    test "produces the correct action" do
      msg = create_message(%{})
      process(msg)

      assert [[log: logjam_msg]] = all_forwarded_log_messages()
      assert "HandlerTest::TestHandler#process" = logjam_msg.action
    end

    test "produces the correct code" do
      msg = create_message(%{})
      process(msg)

      assert [[log: logjam_msg]] = all_forwarded_log_messages()
      assert 200 = logjam_msg.code
    end

    test "produces the correct severity" do
      msg = create_message(%{})
      process(msg)

      assert [[log: logjam_msg]] = all_forwarded_log_messages()
      assert 2 = logjam_msg.severity
    end

    test "adds the host information" do
      msg = create_message(%{})
      process(msg)

      assert [[log: logjam_msg]] = all_forwarded_log_messages()
      assert logjam_msg.host
    end

    test "generates a unique request id" do
      msg = create_message(%{})
      process(msg)

      assert [[log: logjam_msg]] = all_forwarded_log_messages()
      assert is_binary(logjam_msg.request_id)
      assert Regex.match?(~r/^[\w\d]{32}$/, logjam_msg.request_id)
    end

    test "if processed twice, has different request_id" do
      msg = create_message(%{})
      process(msg)
      process(msg)

      assert [[log: logjam_msg1, log: logjam_msg2]] = all_forwarded_log_messages()
      assert logjam_msg1.request_id != logjam_msg2.request_id
    end

    test "logs time to completion" do
      msg = create_message(%{})
      process(msg)

      assert [[log: logjam_msg]] = all_forwarded_log_messages()
      assert is_integer(logjam_msg.total_time)
    end

    test "logs amqp headers as part of request_info" do
      msg = create_message(%{})
      process(msg)

      assert [[log: %{request_info: request_info}]] = all_forwarded_log_messages()
      refute request_info[:method]
      assert %{} = request_info.query_parameters
      assert %{
        "flags" => "1"
      } = request_info.headers
    end

    test "forwards the correct log lines" do
      msg = create_message(%{})
      process(msg)

      assert [[log: logjam_msg]] = all_forwarded_log_messages()
      assert [
        [1, _, log_line1],
        [1, _, log_line2],
        [1, _, log_line3],
        [1, _, log_line4],
        [2, _, log_line5],
        [1, _, log_line6],
      ] = logjam_msg.lines

      assert Regex.match?(~r/#PID<[\d\.]+> Processing HandlerTest::TestHandler#process/, log_line1)
      assert Regex.match?(~r/#PID<[\d\.]+> Sender id is messagesprimera-development_sandbox-08300cb2a1d44c4e8bdcf5b8a9461696/, log_line2)
      assert Regex.match?(~r/#PID<[\d\.]+> Sender action is Messages::ThreadsController#reply/, log_line3)
      assert Regex.match?(~r/#PID<[\d\.]+> \*\*\* HandlerTest::TestHandler#process received a payload with size: 0.002 KB/, log_line4)
      assert Regex.match?(~r/#PID<[\d\.]+> Wow such a cool message/, log_line5)
      assert Regex.match?(~r/#PID<[\d\.]+> Completed 200 ok/, log_line6)
    end

    test "can tolerate absence of sender_id and sender_action" do
      msg = create_message(%{}, [])

      process(msg)

      assert [[log: logjam_msg]] = all_forwarded_log_messages()
      assert [
        [1, _, log_line1],
        [1, _, log_line2],
        [2, _, log_line3],
        [1, _, log_line4],
      ] = logjam_msg.lines

      assert Regex.match?(~r/#PID<[\d\.]+> Processing HandlerTest::TestHandler#process/, log_line1)
      assert Regex.match?(~r/#PID<[\d\.]+> \*\*\* HandlerTest::TestHandler#process received a payload with size: 0.002 KB/, log_line2)
      assert Regex.match?(~r/#PID<[\d\.]+> Wow such a cool message/, log_line3)
      assert Regex.match?(~r/#PID<[\d\.]+> Completed 200 ok/, log_line4)
    end
  end
end
