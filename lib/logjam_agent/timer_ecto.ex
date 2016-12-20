defmodule LogjamAgent.TimerEcto do
  alias LogjamAgent.Metadata

  @typep int_or_nil :: pos_integer | nil

  @type log_entry :: %{
    :query_time => pos_integer,
    :decode_time => int_or_nil,
    :queue_time => int_or_nil,
    optional(any) => any
  }

  @spec log(log_entry) :: log_entry
  def log(entry) do
    total_time = entry.query_time + (entry.decode_time || 0) + (entry.queue_time || 0)
    total_ms = System.convert_time_unit(total_time, :native, :milliseconds)

    Metadata.update(:db_calls, 1, &(&1 + 1))
    Metadata.update(:db_time, total_ms, &(&1 + total_ms))

    entry
  end
end
