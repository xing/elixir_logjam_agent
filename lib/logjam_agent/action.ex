defmodule LogjamAgent.Action do
  defmacro defaction(head, body) do
    {fun_name, [conn, _]} = name_and_args(head)

    quote do
      def unquote(head) do
        env  = %{
          module:           __ENV__.module,
          function:         unquote(fun_name),
          request_headers:  unquote(conn).req_headers,
          query_string:     unquote(conn).query_string,
          method:           unquote(conn).method
        }

        Kernel.var!(unquote(conn)) = Plug.Conn.put_resp_header(unquote(conn), "x-logjam-request-action", LogjamAgent.Transformer.logjam_action_name(env.module, env.function))

        LogjamAgent.Buffer.instrument(env, fn ->
          unquote(body[:do])
        end)
      end
    end
  end

  defp name_and_args({:when, _, [short_head | _]}), do: name_and_args(short_head)
  defp name_and_args(short_head), do: Macro.decompose_call(short_head)
end

