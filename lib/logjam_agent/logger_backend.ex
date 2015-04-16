defmodule LogjamAgent.LoggerBackend do
  use GenEvent

  def init(_) do
    {:ok, configure([])}
  end

  def handle_call({:configure, options}, _state) do
    {:ok, :ok, configure(options)}
  end

  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    end
    {:ok, state}
  end

  ## Helpers
  defp configure(options) do
    format   = Keyword.get(options, :format) |> Logger.Formatter.compile
    level    = Keyword.get(options, :level)
    metadata = Keyword.get(options, :metadata, [])
    %{format: format, metadata: metadata, level: level}
  end

  def log_event(level, msg, timestamp, metadata, _) do
    LogjamAgent.Buffer.log(level, msg, timestamp, Enum.into(metadata, %{}))
  end
end
