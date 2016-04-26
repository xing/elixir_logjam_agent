defmodule LogjamAgent.Plug do
  require Logger

  alias Plug.Conn
  alias LogjamAgent.Metadata

  def init(opts), do: opts

  def call(conn, _) do
    logjam_request_id = Metadata.new_request_id!

    conn
     |> Conn.put_resp_header("x-logjam-request-id", logjam_request_id)
     |> Conn.register_before_send(fn conn ->
          Metadata.store(code: conn.status, response_send_at: :os.timestamp)
          conn
        end)
  end
end
