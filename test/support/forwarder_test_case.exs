defmodule LogjamAgent.ForwarderTestCase do
  use ExUnit.CaseTemplate

  setup do
    :timer.sleep(500)
    LogjamAgent.Forwarders.Stub.clear_all
    :ok
  end

  using do
    quote do
      def all_forwarded_log_messages do
        :timer.sleep(500)
        LogjamAgent.Forwarders.Stub.messages
      end
    end
  end
end
