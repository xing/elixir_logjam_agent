defmodule LogjamAgent.Buffer do
  require Logger

  alias LogjamAgent.{Transformer, Forwarders}

  def start_link do
    Agent.start_link(fn -> HashDict.new end, name: __MODULE__)
  end

  def instrument(request_id, env, action) do
    store_if_missing(request_id, Map.put(env, :action_started_at, :os.timestamp))

    result = try do
      action.()
    catch
      kind, reason -> log_error_and_reraise(kind, reason, System.stacktrace, %{logjam_request_id: request_id, pid: self})
    after
      finish_request(request_id, __MODULE__)
    end
    result
  end

  def finish_request(request_id, source) do
    store(request_id, %{action_finished_at: :os.timestamp})
    Logger.log(:warn, "<Logjam Syncpoint from #{source}>", logjam_request_id: request_id, logjam_signal: :finished)
  end

  defp log_error_and_reraise(kind, reason, stack, meta) do
    timestamp = Logger.Utils.timestamp(Logger.Config.__data__.utc_log)

    log(:error, Exception.format(kind, reason, stack), timestamp, meta)
    :erlang.raise(kind, reason, stack)
  end

  def log(_, _, _, %{logjam_request_id: request_id, logjam_signal: :finished}) do
    buffer = Agent.get_and_update(__MODULE__, fn(state) ->
      {state[request_id], Dict.delete(state, request_id)}
    end)

    if(buffer) do
      buffer
      |> Enum.into(%{})
      |> Transformer.to_logjam_msg
      |> Forwarders.forward
    end
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

  def fetch(request_id, key) do
    Agent.get(__MODULE__, fn(state) -> Dict.get(state, request_id)[key] end)
  end

  def create(request_id) do
    result = Agent.get_and_update(__MODULE__, fn(state) ->
      if Dict.has_key?(state, request_id) do
        {:already_exists, state}
      else
        {:ok, Dict.put(state, request_id, %{request_id: request_id, log_messages: []})}
      end
    end)

    case result do
      :already_exists -> raise ArgumentError, "#{request_id} is already present, cannot create again"
      :ok -> :ok
    end
  end

  def store(request_id, map) when is_map(map) do
    update_buffer(request_id, &Map.merge(&1, map))
  end

  def store_if_missing(request_id, map) when is_map(map) do
    update_buffer(request_id, &Map.merge(map, &1))
  end

  def update(request_id, key, initial, fun) do
    update_buffer(request_id, &Map.update(&1, key, initial, fun))
  end

  def delete(request_id, key) do
    update_buffer(request_id, &Map.delete(&1, key))
  end

  defp update_buffer(request_id, updater) do
    Agent.update(__MODULE__, fn(state) ->
      if Dict.has_key?(state, request_id) do
        Dict.update!(state, request_id, updater)
      else
        state
      end

    end)
  end
end
