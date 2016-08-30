defmodule LogjamAgent.Forwarders.PoolTest do
  use LogjamAgent.ForwarderTestCase, async: false

  alias LogjamAgent.Forwarders.Pool

  setup do
    {:ok, log_msg: %{action: "TestAction"}, event_msg: %{label: "SHA1"}}
  end

  test "forwards a log message to a forwarder process", %{log_msg: log_msg} do
    Pool.forward(log_msg)

    assert [worker_msgs] = all_forwarded_log_messages
    assert [{:log, ^log_msg}] = worker_msgs
  end

  test "forwards an event message to a forwarder process", %{event_msg: event_msg} do
    Pool.forward_event(event_msg)

    assert [worker_msgs] = all_forwarded_log_messages
    assert [{:event, ^event_msg}] = worker_msgs
  end

  test "doesn't forward messages when the logjam agent is disabled", %{log_msg: log_msg, event_msg: event_msg} do
    switch_config([enabled: false], fn ->
      Pool.forward(log_msg)
      Pool.forward_event(event_msg)

      assert [] = all_forwarded_log_messages
    end)
  end

  test "drops messages when high watermark is reached", %{log_msg: log_msg} do
    switch_config([message_high_water_mark: 2, enabled: true], fn ->
      forward_n_copies(log_msg, 10)

      assert [worker_msgs] = all_forwarded_log_messages
      assert Enum.count(worker_msgs) == 3
    end)
  end

  test "shuts down and re-opens forwarder connections on config reload" do
    forwarder_pids = LogjamAgent.Forwarders.Stub.all_forwarders

    switch_config([app_name: "THE_APP"], fn ->
      Pool.reload_config

      new_forwarder_pids = LogjamAgent.Forwarders.Stub.all_forwarders

      assert Enum.all?(forwarder_pids, fn(pid) -> !Process.alive?(pid) end)
      assert Enum.all?(new_forwarder_pids, fn(pid) -> Process.alive?(pid) end)
      assert [%{app_name: "THE_APP"}] = LogjamAgent.Forwarders.Stub.configs
    end)
  end

  test "workers check themselves in when they finished", %{log_msg: log_msg} do
    forward_n_copies(log_msg, 100)

    assert [] = GenServer.call(Pool.pool_name, :get_avail_workers)

    :timer.sleep(50)

    assert [_pid] = GenServer.call(Pool.pool_name, :get_avail_workers)
  end

  defp forward_n_copies(msg, n) do
    [msg]
      |> Stream.cycle
      |> Enum.take(n)
      |> Enum.map(&Pool.forward/1)
  end

  defp switch_config(opts, code_fn) do
    old = Application.get_env(:logjam_agent, :forwarder)

    try do
      Application.put_env(:logjam_agent, :forwarder, opts)
      Pool.reload_config
      code_fn.()
    after
      Application.put_env(:logjam_agent, :forwarder, old)
      Pool.reload_config
    end
  end
end
