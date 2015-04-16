defmodule LogjamAgent.Buffer do
  alias LogjamAgent.Metadata
  alias LogjamAgent.ForwarderPool
  alias LogjamAgent.Transformer

  def start_link do
    Agent.start_link(fn -> HashDict.new end, name: __MODULE__)
  end

  def instrument(request_id \\ Metadata.current_request_id, env, action) do
    store(request_id, Dict.merge(env, action_started_at: :os.timestamp))

    result = try do
      action.()
    after
      store(request_id, action_finished_at: :os.timestamp)
      Logger.log(:warn, '<Logjam Syncpoint>', logjam_request_id: request_id, logjam_signal: :finished)
    end
    result
  end

  def log(_, _, _, %{logjam_request_id: request_id, logjam_signal: :finished}) do
    buffer = Agent.get_and_update(__MODULE__, fn(state) ->
      { state[request_id], Dict.delete(state, request_id) }
    end)

    buffer
    |> Transformer.to_logjam_msg
    |> ForwarderPool.forward
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

  def fetch(request_id, key) do
    Agent.get(__MODULE__, fn(state) -> Dict.get(state, request_id)[key] end)
  end

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
