defmodule LogjamAgent.Plug do
  alias Plug.Conn
  alias LogjamAgent.Metadata, as: M

  def init(opts), do: opts

  def call(conn, _) do
    logjam_request_id = M.new_request_id!

    conn
     |> Conn.put_resp_header("X-Logjam-Request-Id", logjam_request_id)
     |> Conn.register_before_send(fn conn ->
          M.store(code: conn.status)
          conn
        end)
  end
end
