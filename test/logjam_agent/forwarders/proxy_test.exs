defmodule LogjamAgent.Forwarders.ProxyTest do
  use ExUnit.Case

  alias LogjamAgent.Config
  alias LogjamAgent.Forwarders.Proxy

  setup do
    config = Config.current
    {:ok, proxy_pid} = Proxy.start_link
    wait_for_forwarder_to_start(config)

    {:ok, %{config: config, proxy_pid: proxy_pid}}
  end

  defp wait_for_forwarder_to_start(config) do
    :timer.sleep(config.initial_connect_delay + 5)
  end

  test "starts a forwarder after a connect delay", %{proxy_pid: proxy_pid} do
    forwarder_pid = Proxy.forwarder_pid(proxy_pid)

    assert Process.alive?(forwarder_pid)
    assert proxy_pid != forwarder_pid
  end

  test "restarts forwarder when it crashes or is killed", %{proxy_pid: proxy_pid} do
    old_forwarder_pid = Proxy.forwarder_pid(proxy_pid)
    Process.exit(old_forwarder_pid, :kill)

    refute Process.alive?(old_forwarder_pid)
    new_forwarder_pid = Proxy.forwarder_pid(proxy_pid)
    assert Process.alive?(new_forwarder_pid)
    assert old_forwarder_pid != new_forwarder_pid
  end

  test "doesn't restart forwarder when it was normally shut down", %{proxy_pid: proxy_pid} do
    old_forwarder_pid = Proxy.forwarder_pid(proxy_pid)
    LogjamAgent.Forwarders.Stub.stop(old_forwarder_pid)

    refute Process.alive?(old_forwarder_pid)
    refute Proxy.forwarder_pid(proxy_pid)
  end

  test "can disable a running forwarder", %{proxy_pid: proxy_pid, config: config} do
    Proxy.reload_config(proxy_pid, %{config | enabled: false})

    refute Proxy.forwarder_pid(proxy_pid)
  end

  test "can still send messages to a forwarder when disabled", %{proxy_pid: proxy_pid, config: config} do
    Proxy.reload_config(proxy_pid, %{config | enabled: false})

    [{:log, :should_not_blow_up}]
      |> Stream.cycle
      |> Enum.take(10)
      |> Enum.map(&Proxy.forward(proxy_pid, &1))
  end
end
