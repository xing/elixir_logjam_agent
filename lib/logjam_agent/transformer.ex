defmodule LogjamAgent.Transformer do

  @fields_to_copy [
    :code,
    :request_id,
    :ip,
    :rest_time,
    :rest_calls,
    :redis_time,
    :redis_calls,
    :db_time,
    :db_calls,
    :wait_time,
    :exceptions
  ]

  @logjam_severities %{
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
    fatal: 4,
    any: 5
  }

  def to_logjam_msg(buffer) do
    %{}
      |> add_logjam_started_at(buffer)
      |> add_logjam_total_time(buffer)
      |> add_logjam_action(buffer)
      |> add_logjam_severity(buffer)
      |> add_logjam_lines(buffer)
      |> add_request_info(buffer)
      |> add_system_info
      |> copy_fields(buffer)
  end

  def to_logjam_event(label) do
    %{
      label: label,
      host: nil
    }
    |> add_logjam_started_at(%{action_started_at: :os.timestamp})
    |> add_system_info
  end

  def logjam_action_name(module, function) do
    module_name = module
                  |> Atom.to_string
                  |> String.replace("Elixir.", "")
                  |> strip_app_prefix
                  |> String.replace(".", "::")
    "#{module_name}##{function}"
  end

  defp strip_app_prefix(module) do
    String.replace(module, ~r/\A\w+\./, "", global: false)
  end

  defp add_logjam_started_at(output, input) do
    in_iso = :calendar.now_to_local_time(input.action_started_at)
             |> to_logjam_iso8601

    Map.put(output, :started_at, in_iso)
  end

  defp add_logjam_total_time(output, input) do
    first_response = Map.get(input, :response_send_at, input[:action_finished_at])
    total_time = :timer.now_diff(first_response, input.action_started_at) |> div(1000)
    Map.put(output, :total_time, total_time)
  end

  defp add_logjam_action(output, input) do
    action = case Map.fetch(input, :override_action) do
      {:ok, value} -> value
      :error       ->
        module = Map.get(input, :module, :Unknown)
        function = Map.get(input, :function, :unknown)
        logjam_action_name(module, function)
    end
    Map.put(output, :action, action)
  end

  defp add_logjam_severity(output, input) do
    winner = case input.log_messages do
      []       -> %{level: :info}
      messages -> Enum.max_by(messages, &to_logjam_log_level/1)
    end
    Map.put(output, :severity, to_logjam_log_level(winner))
  end

  defp add_logjam_lines(output, input) do
    lines = Enum.reverse(input.log_messages) |> Enum.map(fn(log) ->
      [
        to_logjam_log_level(log),
        logger_timestamp_to_iso8601(log.timestamp),
        format_log_message(log)
      ]
    end)

    Map.put(output, :lines, lines)
  end

  defp add_system_info(output) do
    output
    |> Map.merge(LogjamAgent.SystemMetrics.get)
  end

  defp copy_fields(output, input) do
    Map.merge(output, Map.take(input, @fields_to_copy))
  end

  def add_request_info(output, input) do
    req_headers = Map.get(input, :request_headers, []) |> to_string_map
    query_string = Map.get(input, :query_string, "")
    request_path = Map.get(input, :request_path, "")
    query_params_clean = query_string
                         |> Plug.Conn.Query.decode
                         |> filter_sensitive_params

    url = if query_string != "" do
      request_path <> "?" <> Plug.Conn.Query.encode(query_params_clean)
    else
      request_path
    end

    request_info = %{
                      query_parameters: query_params_clean,
                      headers: req_headers,
                      method:  input[:method],
                      url:     url
                    }
                    |> Enum.reject(fn {_, v} -> v == nil || v == "" end)
                    |> Enum.into(%{})

    output
    |> Map.put(:caller_id, req_headers["x-logjam-caller-id"])
    |> Map.put(:caller_action, req_headers["x-logjam-action"])
    |> Map.put(:request_info, request_info)
  end

  @sensitive_params %{"password" => "[FILTERED]"}
  defp filter_sensitive_params(params) when is_map(params) do
    masked_sensitive_params = Map.take(@sensitive_params, Map.keys(params))
    Map.merge(params, masked_sensitive_params)
  end

  defp to_string_map(input)
  defp to_string_map(%{__struct__: _} = input) do
    input
      |> Map.delete(:__struct__)
      |> to_string_map
  end

  defp to_string_map(input) do
    Enum.into(input, %{}, fn{k, v} -> {to_string(k), stringify(v)} end)
  end

  defp stringify(value)
  defp stringify(value) when is_map(value), do: value
  defp stringify(value), do: to_string(value)

  defp to_logjam_log_level(log) do
    @logjam_severities[log.level]
  end

  defp format_log_message(log) do
    "#{inspect(log.pid)} #{log.msg}"
  end

  defp logger_timestamp_to_iso8601({date, {h, m, s, micro}}) do
    to_logjam_iso8601({date, {h, m, s}}, micro)
  end

  defp to_logjam_iso8601(time, micro) do
    "#{to_logjam_iso8601(time)}.#{micro}"
  end

  defp to_logjam_iso8601({{year, month, day}, {hour, minute, second}}) do
    "#{year}-#{pad month}-#{pad day}T#{pad hour}:#{pad minute}:#{pad second}"
  end

  defp pad(number) when number > 9, do: Integer.to_string(number)
  defp pad(number), do: "0" <> Integer.to_string(number)

end
