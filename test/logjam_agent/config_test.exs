defmodule LogjamAgent.ConigTest do
  use ExUnit.Case, async: false

  setup do
    System.put_env("LOGJAM_BROKER", "")
    :ok
  end

  test "loads the broker from the environment if it's present" do
    System.put_env("LOGJAM_BROKER", "env.broker.example.com")
    Application.put_env(:logjam_agent, :forwarder,
                        amqp: [host: "broker.example.com"])

    assert Keyword.fetch!(LogjamAgent.Config.current.amqp, :host) == "env.broker.example.com"
  end

  test "loads the broker from the config if the environment variable does not override it" do
    Application.put_env(:logjam_agent, :forwarder,
                        amqp: [host: "broker.example.com"])

    assert Keyword.fetch!(LogjamAgent.Config.current.amqp, :host) == "broker.example.com"
  end

  test "loads an empty amqp config map if it was not provided" do
    Application.put_env(:logjam_agent, :forwarder, enabled: false)

    assert Enum.empty?(LogjamAgent.Config.current.amqp)
  end
end
