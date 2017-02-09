defmodule LogjamAgent.Instrumentation.Socket do
  alias LogjamAgent.{Buffer, Metadata, Instrumentation}
  alias __MODULE__
  require Logger

  def instrument(definition, _opts) do
    [params | _] = definition.args

    quote do
      env  = %{
        module:          __ENV__.module,
        function:        unquote(definition.name),
        request_headers: unquote(params)
      }

      request_id = Metadata.new_request_id!
      Metadata.current_request_id(request_id)

      result = Buffer.instrument(request_id, env, fn ->
        result      = unquote(Instrumentation.add_exception_guard(definition))
        result_code = Socket.result_code(result)
        Buffer.store(request_id, %{code: result_code, response_send_at: :os.timestamp})
        Socket.result(result)
      end)

      Logger.reset_metadata
      result
    end
  end

  def result_code(result)
  def result_code({:ok, _socket}), do: 200
  def result_code(:exception),     do: 500
  def result_code(_),              do: 401

  def result(result)
  def result(:exception), do: :error
  def result(result),     do: result
end
