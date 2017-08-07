defmodule LogjamAgent.Config do
  alias LogjamAgent.Forwarders.{EndpointParser, ZMQForwarder}

  @default_values %{
    enabled: true,
    env: :preview,
    initial_connect_delay: 0,
    app_name: nil,
    endpoints: [ZMQForwarder.default_endpoint],
    pool_size: 1,
    pool_max_overflow: 0,
    message_high_water_mark: nil
  }

  def current do
    Application.get_env(:logjam_agent, :forwarder, %{})
      |> Enum.into(%{})
      |> set_default_if_missing
      |> update_settings_from_environment!
  end

  defp set_default_if_missing(config) do
    Map.merge(@default_values, config)
  end

  defp update_settings_from_environment!(settings) do
    parse_endpoints!(raw_endpoints(), settings)
  end

  defp raw_endpoints do
    get_env("LOGJAM_AGENT_ZMQ_ENDPOINTS") || get_env("LOGJAM_BROKER")
  end

  defp parse_endpoints!(raw, settings)
  defp parse_endpoints!(nil, settings), do: settings
  defp parse_endpoints!(raw, settings) do
    %{settings | endpoints: EndpointParser.parse!(raw)}
  end

  defp get_env(env_variable) do
    case System.get_env(env_variable) do
      nil  -> nil
      ""   -> nil
      host -> host
    end
  end
end
