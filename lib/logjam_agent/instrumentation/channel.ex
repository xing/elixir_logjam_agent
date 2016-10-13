defmodule LogjamAgent.Instrumentation.Channel do
  alias LogjamAgent.{Buffer, Metadata, Instrumentation}
  alias __MODULE__
  require Logger

  def instrument(definition, opts) do
    socket = Enum.at(definition.args, 2)

    quote do
      env        = unquote(encode_env(definition, opts))
      request_id = Metadata.new_request_id!

      Buffer.instrument(request_id, env, fn ->
        result      = unquote(Instrumentation.add_exception_guard(definition))
        result_code = Channel.result_code(unquote(definition.name), result)
        Buffer.store(request_id, code: result_code, response_send_at: :os.timestamp)
        Channel.result(unquote(definition.name), result, unquote(socket))
      end)
    end
  end

  def encode_env(definition, opts) do
    params      = Enum.at(definition.args, 1)
    socket      = Enum.at(definition.args, 2)
    log_assigns = opts[:log_assigns]

    quote do
      %{
        module:          __ENV__.module,
        function:        unquote(definition.name),
        request_headers: Channel.merge_params(unquote(params), unquote(socket), unquote(log_assigns))
      }
    end
  end

  def merge_params(params, socket, log_assigns) when is_map(params) do
    Map.merge(params, Map.take(socket.assigns, log_assigns))
  end

  def merge_params(_params, socket, log_assigns) do
    merge_params(%{}, socket, log_assigns)
  end

  def result_code(function, result)
  def result_code(:join, {:ok, _socket}),           do: 200
  def result_code(:join, {:error, _}),              do: 401
  def result_code(_function, {:reply, _, _socket}), do: 200
  def result_code(_function, {:noreply, _socket}),  do: 200
  def result_code(_function, :exception),           do: 500
  def result_code(_function, _result),              do: 200

  def result(function, result, socket)
  def result(:join, :exception, _socket),    do: {:error,   %{error_type: :internal}}
  def result(_function, :exception, socket), do: {:noreply, socket}
  def result(_function, result, _socket),    do: result
end
