defmodule LogjamAgent.TimerEctoTest do
  use ExUnit.Case, async: false
  alias LogjamAgent.Metadata
  alias LogjamAgent.TimerEcto

  setup do
    Metadata.new_request_id!

    Metadata.delete(:db_calls)
    Metadata.delete(:db_time)
    :ok
  end

  defp to_native(milliseconds) do
    milliseconds |> System.convert_time_unit(:milliseconds, :native)
  end

  test "log/1 handles not all timing values being present" do
    log_entry = %{
      query_time:  123 |> to_native,
      decode_time: nil,
      queue_time:  nil
    }

    TimerEcto.log(log_entry)

    assert 1 == Metadata.fetch(:db_calls)
    assert 123 == Metadata.fetch(:db_time)
  end

  test "log/1 sums up different timing values" do
    log_entry = %{
      query_time:  123 |> to_native,
      decode_time: 123 |> to_native,
      queue_time:  123 |> to_native
    }

    TimerEcto.log(log_entry)

    assert 1 == Metadata.fetch(:db_calls)
    assert 123 * 3 == Metadata.fetch(:db_time)
  end

  test "log/1 counts calls and adds times on multiple queries" do
    log_entry = %{
      query_time:  123 |> to_native,
      decode_time: nil,
      queue_time:  nil
    }

    TimerEcto.log(log_entry)
    TimerEcto.log(log_entry)

    assert 2 == Metadata.fetch(:db_calls)
    assert 123 * 2 == Metadata.fetch(:db_time)
  end

  test "log/1 converts times into milliseconds before logging" do
    log_entry = %{
      query_time:  500 |> to_native,
      decode_time: nil,
      queue_time:  nil
    }

    TimerEcto.log(log_entry)

    assert 500 == Metadata.fetch(:db_time)
  end
end
