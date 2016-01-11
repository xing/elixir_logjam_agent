defmodule LogjamAgent.Config do
  def current do
    config = Application.get_env(:logjam_agent, :forwarder) || default_config
    config |> Enum.into(%{})
  end

  defp default_config do
    %{
      enabled: false,
      debug_to_stdout: true
    }
  end
end
