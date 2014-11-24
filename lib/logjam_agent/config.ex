defmodule LogjamAgent.Config do
  def current do
    config = Application.get_env(:logjam_agent, :forwarder) || %{enabled: false}
    config |> Enum.into(%{})
  end
end
