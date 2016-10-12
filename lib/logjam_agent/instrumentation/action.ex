defmodule LogjamAgent.Instrumentation.Action do
  def instrument(definition, _opts) do
    [conn | _] = definition.args

    quote do
      env  = %{
        module:          __ENV__.module,
        function:        unquote(definition.name),
        request_headers: unquote(conn).req_headers,
        query_string:    unquote(conn).query_string,
        method:          unquote(conn).method
      }

      Kernel.var!(unquote(conn)) = Plug.Conn.put_resp_header(unquote(conn),
                                                             "x-logjam-request-action",
                                                             LogjamAgent.Transformer.logjam_action_name(env.module, env.function))

      LogjamAgent.Buffer.instrument(
        LogjamAgent.Metadata.current_request_id,
        env,
        fn -> unquote(definition.body) end)
    end
  end
end
