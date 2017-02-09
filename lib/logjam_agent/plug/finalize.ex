defmodule LogjamAgent.Plug.Finalize do
  alias Plug.Conn
  alias LogjamAgent.{Metadata, Buffer}

  def init(opts), do: opts

  def call(conn, _) do
    Conn.register_before_send(conn, fn conn ->
      logjam_request_id = Metadata.current_request_id
      if(logjam_request_id, do: Buffer.finish_request(logjam_request_id, __MODULE__))
      conn
    end)
  end
end
