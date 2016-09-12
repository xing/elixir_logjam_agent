defmodule LogjamAgent.MetadataTest do
  use ExUnit.Case, async: false
  alias LogjamAgent.{Buffer, Metadata}

  setup do
    Metadata.new_request_id!
    Buffer.delete(Metadata.current_request_id, :rest_calls)
    Buffer.delete(Metadata.current_request_id, :exceptions)
    :ok
  end

  test "increment_rest_calls_counter/0 properly increments the counter with every call" do
    refute Buffer.fetch(Metadata.current_request_id, :rest_calls)

    for i <- 1..5 do
      Metadata.increment_rest_calls_counter
      assert ^i = Buffer.fetch(Metadata.current_request_id, :rest_calls)
    end
  end

  test "collect_exception/1 adds the exception logjam style" do
    refute Buffer.fetch(Metadata.current_request_id, :exceptions)

    Metadata.collect_exception("TestException")
    Metadata.collect_exception("TestException2")

    assert ["TestException2", "TestException"] = Buffer.fetch(Metadata.current_request_id, :exceptions)
  end
end
