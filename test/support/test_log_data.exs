defmodule TestLogData do
  def new do
    %{
      action_started_at: {1411, 56_187, 117_735},
      action_finished_at: {1411, 58_187, 117_735},
      code: 200,
      method: "GET",
      function: :dummy,
      module: RestProxy.DummyController,
      request_id: "9efb4bde3e5311e4bc483c075440625c",
      request_headers: [
        {"accept", "application/json"}
      ],
      query_string: "foo=bar&fields=a,b",
      caller_action: "CALLER_ACTION",
      caller_id: "CALLER_ID",
      rest_time: 25.99,
      rest_calls: 1,
      redis_time: 0.99,
      redis_calls: 2,
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
  end
end
