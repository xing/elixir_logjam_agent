defmodule LogjamAgent.Instrumentation.Simple do
  alias LogjamAgent.{Buffer, Metadata, Instrumentation}
  alias __MODULE__
  require Logger

  def instrument(definition, _opts) do
    quote do
      module = __ENV__.module
      action = unquote(definition.name)
      env  = %{
        module:          __ENV__.module,
        function:        unquote(definition.name)
      }
      action_name = LogjamAgent.Transformer.logjam_action_name(module, action)

      request_id = Metadata.new_request_id!
      Metadata.current_request_id(request_id)
      Metadata.store(%{action: action_name})

      result = Buffer.instrument(request_id, env, fn ->
        result      = unquote(Instrumentation.add_exception_guard(definition))
        result_code = Simple.result_code(result)
        Buffer.store(request_id, %{code: result_code, response_send_at: :os.timestamp})
        Simple.result(result)
      end)

      Logger.reset_metadata
      result
    end
  end

  def result_code(result)
  def result_code(:exception),     do: 500
  def result_code(_),              do: 200

  def result(result)
  def result(:exception), do: :error
  def result(result),     do: result
end
