defmodule LogjamAgent.Instrumentation.Action do
  def instrument(definition, _opts) do
    [conn | _] = definition.args

    quote do
      module = __ENV__.module
      action = unquote(definition.name)
      action_name = LogjamAgent.Transformer.logjam_action_name(module, action)
      env  = %{
        module:          module,
        function:        action,
        request_headers: unquote(conn).req_headers,
        query_string:    unquote(conn).query_string,
        method:          unquote(conn).method,
        request_path:    unquote(conn).request_path
      }

      LogjamAgent.Metadata.store(%{action: action_name})
      Kernel.var!(unquote(conn)) = Plug.Conn.put_resp_header(unquote(conn), "x-logjam-request-action", action_name)

      LogjamAgent.Buffer.instrument(
        LogjamAgent.Metadata.current_request_id,
        env,
        fn -> unquote(definition.body) end)
    end
  end
end
