Code.require_file("test_consumer.exs", "test/support")

defmodule LogjamAgent.IntegratedTestCase do
  defmodule Helpers do
    def consume_message(func, options \\ []) do
      case consume_messages(func, options) do
        []       -> nil
        [m | _]  -> m
      end
    end

    def consume_messages(func, options \\ []) do
      {:ok, _} = LogjamAgent.TestConsumer.start_link(options)

      func.()

      :timer.sleep(100)

      LogjamAgent.TestConsumer.messages
    end

    def create_producer do
      {:ok, producer} = LogjamAgent.Producer.connect(amqp_options: [host: "localhost"],
                                                     exchange: LogjamAgent.TestConsumer.exchange)
      producer
    end

    def unique_message do
      "MSG_#{inspect(make_ref)}"
    end
  end

  defmacro __using__(_) do
    quote do
      use ExUnit.Case, async: true
      import Helpers

      alias LogjamAgent.Producer
    end
  end
end
