defmodule LogjamAgent.Buffer do
  def start_link do
    Agent.start_link(fn -> HashDict.new end, name: __MODULE__)
  end

  def instrument(request_id \\ LogjamAgent.Metadata.current_request_id, env, action) do
    before_time = :os.timestamp()
    store(request_id, Dict.merge(env, started_at: before_time))

    result = try do
      action.()
    after
      after_time = :os.timestamp()
      diff = :timer.now_diff(after_time, before_time)
      store(request_id, total_time: div(diff, 1000))
      Logger.log(:warn, '<Logjam Syncpoint>', logjam_request_id: request_id, logjam_signal: :finished)
    end
    result
  end

  def log(_, _, _, %{logjam_request_id: request_id, logjam_signal: :finished}) do
    buffer = Agent.get_and_update(__MODULE__, fn(state) ->
      { state[request_id], Dict.delete(state, request_id) }
    end)

    Logjam.Forwarder.forward(buffer)
  end

  def log(level, msg, timestamp, %{logjam_request_id: request_id, pid: pid}) do
    msg = %{
      msg: IO.chardata_to_string(msg),
      timestamp: timestamp,
      level: level,
      pid: pid
    }

    update_buffer(request_id, fn(buffer) ->
      put_in(buffer.log_messages, [msg | buffer.log_messages])
    end)
  end

  def log(_, _, _, _), do: nil

  def store(request_id, dict), do: update_buffer(request_id, &Dict.merge(&1, dict))

  defp update_buffer(request_id, updater) do
    Agent.update(__MODULE__, fn(state) ->
      d = if Dict.has_key?(state, request_id) do
        state
      else
        Dict.put(state, request_id, %{ request_id: request_id, log_messages: [] })
      end

      Dict.update!(d, request_id, updater)
    end)
  end
end
