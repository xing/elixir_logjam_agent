defmodule LogjamAgent.ConfigTest do
  use ExUnit.Case, async: false

  setup do
    System.put_env("LOGJAM_BROKER", "")

    on_exit(fn -> System.put_env("LOGJAM_BROKER", "") end)

    :ok
  end

  %{
    "env.broker.example.com, env.broker2.example.com " =>
      [{:tcp, "env.broker.example.com", 9604}, {:tcp, "env.broker2.example.com", 9604}],
    "env.broker.example.com" =>
      [{:tcp, "env.broker.example.com", 9604}],
    "env.broker.example.com:4000" =>
      [{:tcp, "env.broker.example.com", 4000}],
    "ipc://env.broker.example.com:4000" =>
      [{:ipc, "env.broker.example.com", 4000}],
    "ipc://env.broker.example.com" =>
      [{:ipc, "env.broker.example.com", 9604}]
   } |> Enum.each(fn {env_var, expected_endpoints} ->

    test ".current loads the zmqp endpoint '#{env_var}' from the environment properly" do
      System.put_env("LOGJAM_BROKER", unquote(env_var))

      Application.put_env(:logjam_agent, :forwarder, endpoints: [
        {:tcp, "broker.example.com", 4000}
      ])

      assert LogjamAgent.Config.current.endpoints == unquote(Macro.escape(expected_endpoints))
    end

  end)

  test ".current loads the zmq endpoints from the config if the environment variable does not override it" do
    Application.put_env(:logjam_agent, :forwarder, endpoints: [
      {:tcp, "broker.example.com", 4000}
    ])

    assert LogjamAgent.Config.current.endpoints == [
      {:tcp, "broker.example.com", 4000}
    ]
  end

  test ".current raises when invalid endpoint is specified" do
    System.put_env("LOGJAM_BROKER", ":::SOME_MALFORMED_SHIT:::")

    assert_raise RuntimeError, "Invalid endpoint specified: ':::SOME_MALFORMED_SHIT:::'", fn ->
      LogjamAgent.Config.current
    end
  end
end
