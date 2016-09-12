defmodule LogjamAgent.BufferTest do
  use ExUnit.Case, async: false
  alias LogjamAgent.Buffer

  setup do
    Buffer.delete(:test_request_id, :test_field)
    :ok
  end

  test "update/4 stores inital value when no value is present" do
    refute Buffer.fetch(:test_request_id, :field)
    assert :ok = Buffer.update(:test_request_id, :test_field, 0, &(&1 + 1))
    assert 0 = Buffer.fetch(:test_request_id, :test_field)
  end

  test "update/4 evaluates updater when value is present" do
    refute Buffer.fetch(:test_request_id, :test_field)

    for _i <- 1..3 do
      assert :ok = Buffer.update(:test_request_id, :test_field, 0, &(&1 + 1))
    end

    assert 2 = Buffer.fetch(:test_request_id, :test_field)
  end
end
