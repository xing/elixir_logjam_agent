defmodule LogjamAgent.Plug do
  require Logger

  alias Plug.Conn
  alias LogjamAgent.Metadata
  alias Timex.Time

  def init(opts), do: opts

  def call(conn, _) do
    logjam_request_id = M.new_request_id!

    conn
     |> Conn.put_resp_header("X-Logjam-Request-Id", logjam_request_id)
     |> Conn.register_before_send(fn conn ->
          Metadata.store(code: conn.status, response_send_at: Time.now)
          Logger.info("Response send with code #{conn.status}")
          conn
        end)
  end
end
