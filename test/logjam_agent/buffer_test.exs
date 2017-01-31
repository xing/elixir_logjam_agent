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

  test "store_if_missing/2 does not overwrite existing value" do
    Buffer.store_if_missing(:test_request_id, foo: "foo")
    Buffer.store_if_missing(:test_request_id, foo: "bar", baz: 1)

    assert "foo" = Buffer.fetch(:test_request_id, :foo)
    assert 1 = Buffer.fetch(:test_request_id, :baz)
  end
end
