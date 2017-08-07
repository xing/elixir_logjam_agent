defmodule LogjamAgent.Plug.Register do
  require Logger

  alias Plug.Conn
  alias LogjamAgent.{Metadata, Buffer}
  alias Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _) do
    logjam_request_id = Metadata.new_request_id!

    env = %{
      request_headers:   conn.req_headers,
      query_string:      conn.query_string,
      method:            conn.method,
      request_path:      conn.request_path,
      action_started_at: :os.timestamp
    }
    Buffer.store_if_missing(logjam_request_id, env)

    Conn.register_before_send(conn, fn conn ->
      Metadata.store(%{code: conn.status, response_send_at: :os.timestamp})
      conn
        |> maybe_add_logjam_metadata(logjam_request_id)
        |> Conn.put_resp_header("x-logjam-request-id", Metadata.current_caller_id)
    end)
  end

  defp maybe_add_logjam_metadata(conn, logjam_request_id) do
    # sometimes conn does not contain info about action and controller
    try do
      module = Controller.controller_module(conn)
      action = Controller.action_name(conn)
      action_name = LogjamAgent.Transformer.logjam_action_name(module, action)
      Buffer.store_if_missing(logjam_request_id, %{module: module, function: action})
      Conn.put_resp_header(conn, "x-logjam-request-action", action_name)
    rescue
      KeyError -> conn
    end
  end
end
