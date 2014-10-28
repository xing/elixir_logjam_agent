defmodule LogjamAgent.TransformerTest do
  use ExUnit.Case

  alias LogjamAgent.Transformer, as: T

  setup_all do
    data = %{
      action_started_at: {1411, 56187, 117735},
      action_finished_at: {1411, 58187, 117735},
      code: 200,
      method: "GET",
      function: :dummy,
      module: RestProxy.DummyController,
      request_id: "9efb4bde3e5311e4bc483c075440625c",
      request_headers: [
        { "accept", "application/json" }
      ],
      query_string:  "foo=bar&fields=a,b",
      caller_action: "CALLER_ACTION",
      caller_id: "CALLER_ID",
      rest_time: 25.99,
      rest_calls: 1,
      log_messages: [
        %{
          pid: "#PID<0.419.0>",
          level: :info,
          msg: "GET /dummy",
          timestamp: {{2014, 9, 17}, {10, 17, 58, 40}}
        },
        %{
          pid: "#PID<0.419.0>",
          level: :debug,
          msg: "Processing by RestProxy.DummyController.dummy",
          timestamp: {{2014, 9, 17}, {10, 17, 58, 213}}
        },
        %{
          pid: "#PID<0.419.0>",
          level: :warn,
          msg: "Sent 200 in 180ms",
          timestamp: {{2014, 9, 17}, {10, 17, 58, 221}}
        }
      ]
    }

    {:ok, data }
  end

  test "#to_logjam_msg transforms the start_at timestamp", data do
    result = T.to_logjam_msg(data)
    assert result.started_at == "2014-09-18T18:03:07"
  end

  test "#to_logjam_msg can calculates the diff between actions ", data do
    result = T.to_logjam_msg(data)
    assert result.total_time == 2000000
  end

  test "#to_logjam_msg can calculates the diff action and first response sent", data do
    result = data |> Dict.put(:response_send_at, {1411, 69000, 117735}) |> T.to_logjam_msg
    assert result.total_time == 12813000
  end

  test "#to_logjam_msg creates the logjam action", data do
    result = T.to_logjam_msg(data)
    assert result.action == "RestProxy::DummyController#dummy"
  end

  test "#to_logjam_msg checks for override_action field", data do
    result = data |> Dict.put(:override_action, "Foo#bar") |> T.to_logjam_msg
    assert result.action == "Foo#bar"
  end

  test "#to_logjam_msg drops transient fields", data do
    result = T.to_logjam_msg(data)
    assert result[:function] == nil
    assert result[:module] == nil
  end

  test "#to_logjam_msg finds out the highest message severity", data do
    result = T.to_logjam_msg(data)
    assert result[:severity] == 2
  end

  test "#to_logjam_msg reorders the messages chronologically", data do
    result = T.to_logjam_msg(data)

    assert Enum.at(result.lines, 0) |> Enum.at(2) == "\"#PID<0.419.0>\" Sent 200 in 180ms"
    assert Enum.at(result.lines, 1) |> Enum.at(2) == "\"#PID<0.419.0>\" Processing by RestProxy.DummyController.dummy"
    assert Enum.at(result.lines, 2) |> Enum.at(2) == "\"#PID<0.419.0>\" GET /dummy"
  end

  test "#to_logjam_msg transforms the log messages timestamps", data do
    result = T.to_logjam_msg(data)

    assert Enum.at(result.lines, 0) |> Enum.at(1) == "2014-09-17T10:17:58.221"
    assert Enum.at(result.lines, 1) |> Enum.at(1) == "2014-09-17T10:17:58.213"
    assert Enum.at(result.lines, 2) |> Enum.at(1) == "2014-09-17T10:17:58.40"
  end

  test "#to_logjam_msg includes request_id", data do
    result = T.to_logjam_msg(data)
    assert result[:request_id] == data[:request_id]
  end

  test "#to_logjam_msg includes rest_time", data do
    result = T.to_logjam_msg(data)
    assert result[:rest_time] == data[:rest_time]
  end

  test "#to_logjam_msg includes rest_calls", data do
    result = T.to_logjam_msg(data)
    assert result[:rest_calls] == data[:rest_calls]
  end

  test "#to_logjam_msg includes the response code", data do
    result = T.to_logjam_msg(data)
    assert result[:code] == data[:code]
  end

  test "#to_logjam_msg includes the request headers", data do
    result = T.to_logjam_msg(data)
    assert result[:request_info][:headers] == %{ "accept" => "application/json" }
  end

  test "#to_logjam_msg includes the query string", data do
    result = T.to_logjam_msg(data)
    assert result[:request_info][:query_parameters] == %{"fields" => "a,b", "foo" => "bar"}
  end

  test "#to_logjam_msg includes the HTTP method", data do
    result = T.to_logjam_msg(data)
    assert result[:request_info][:method] == "GET"
  end
end
