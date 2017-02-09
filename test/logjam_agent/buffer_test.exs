defmodule LogjamAgent.BufferTest do
  use ExUnit.Case, async: false
  alias LogjamAgent.Buffer

  test "create/1 refuses to create entry when already present", %{test: test} do
    assert Buffer.create(test)
    assert_raise ArgumentError, fn -> Buffer.create(test) end
  end

  test "update/4 is a no-op when no value is present", %{test: test} do
    refute Buffer.fetch(test, :test_field)
    assert :ok = Buffer.update(test, :test_field, 0, &(&1 + 1))
    refute Buffer.fetch(test, :test_field)
  end

  test "update/4 evaluates updater when value is present", %{test: test} do
    Buffer.create(test)

    refute Buffer.fetch(test, :test_field)

    for _i <- 1..3 do
      assert :ok = Buffer.update(test, :test_field, 0, &(&1 + 1))
    end

    assert 2 = Buffer.fetch(test, :test_field)
  end

  test "store_if_missing/2 does not overwrite existing value", %{test: test} do
    Buffer.create(test)

    Buffer.store_if_missing(test, %{foo: "foo"})
    Buffer.store_if_missing(test, %{foo: "bar", baz: 1})

    assert "foo" = Buffer.fetch(test, :foo)
    assert 1 = Buffer.fetch(test, :baz)
  end
end
