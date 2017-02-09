defmodule LogjamAgent.ForwarderTestCase do
  use ExUnit.CaseTemplate

  setup do
    :timer.sleep(500)
    LogjamAgent.Forwarders.Stub.clear_all
    Agent.update(LogjamAgent.Buffer, fn(_state) -> HashDict.new end)
    :ok
  end

  using do
    quote do
      def all_forwarded_log_messages do
        :timer.sleep(500)
        LogjamAgent.Forwarders.Stub.messages
      end

      def all_log_messages_forwarded? do
        buffer = Agent.get(LogjamAgent.Buffer, fn(state) -> state end)
        HashDict.size(buffer) == 0
      end
    end
  end
end
