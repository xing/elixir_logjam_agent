defmodule LogjamAgent.Transformer do
  use Timex

  @fields_to_copy [
    :code,
    :request_id,
    :host,
    :ip,
    :rest_time,
    :rest_calls,
    :db_time,
    :db_calls
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

  defp add_logjam_started_at(output, input) do
    in_secs    = Time.convert(input.action_started_at, :secs)
    epoch_secs = Date.epoch(:secs)
    in_iso     = Date.from(epoch_secs + in_secs, :secs, :zero)
                  |> Timezone.convert(Timezone.local)
                  |> to_logjam_iso8601
    Dict.put(output, :started_at, in_iso)
  end

  defp add_logjam_total_time(output, input) do
    first_response = Dict.get(input, :response_send_at, input[:action_finished_at])
    total_time = :timer.now_diff(first_response, input.action_started_at) |> div(1000)
    Dict.put(output, :total_time, total_time)
  end

  defp add_logjam_action(output, input) do
    module_name = input.module
                  |> Atom.to_string
                  |> String.replace("Elixir.", "")
                  |> String.replace(".", "::")
    Dict.put(output, :action, "#{module_name}##{input.function}")
  end

  defp add_logjam_severity(output, input) do
    winner = Enum.max_by(input.log_messages, &to_logjam_log_level/1)
    Dict.put(output, :severity, to_logjam_log_level(winner))
  end

  defp add_logjam_lines(output, input) do
    lines = Enum.reverse(input.log_messages) |> Enum.map(fn(log) ->
      [
        to_logjam_log_level(log),
        logger_timestamp_to_iso8601(log.timestamp),
        format_log_message(log)
      ]
    end)

    Dict.put(output, :lines, lines)
  end

  defp add_system_info(output) do
    output
    |> Dict.merge(LogjamAgent.SystemMetrics.get)
  end

  defp copy_fields(output, input) do
    Dict.merge(output, Dict.take(input, @fields_to_copy))
  end

  def add_request_info(output, input) do
    req_headers = Dict.get(input, :request_headers, []) |> Enum.into(%{})
    query_string = Dict.get(input, :query_string, "")

    output
    |> Dict.put(:caller_id, req_headers["X-Logjam-Caller-Id"])
    |> Dict.put(:caller_action, req_headers["X-Logjam-Action"])
    |> Dict.put(:request_info, %{
        query_parameters: Plug.Conn.Query.decode(query_string),
        headers: req_headers,
        method:  input[:method]
       })
  end

  defp to_logjam_log_level(log) do
    @logjam_severities[log.level]
  end

  defp format_log_message(log) do
    "#{inspect(log.pid)} #{log.msg}"
  end

  defp logger_timestamp_to_iso8601({date, {h, m, s, micro}}) do
    Date.from({date, {h,m,s}}, :local) |> to_logjam_iso8601(micro)
  end

  defp to_logjam_iso8601(timex_date, micro \\ nil) do
    iso_date = DateFormat.format!(timex_date, "{ISOdate}")
    iso_time = DateFormat.format!(timex_date, "{ISOtime}")
    if micro, do: "#{iso_date}T#{iso_time}.#{micro}", else: "#{iso_date}T#{iso_time}"
  end

end
