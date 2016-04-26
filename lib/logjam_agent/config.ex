defmodule LogjamAgent.Config do
  def current do
    Application.get_env(:logjam_agent, :forwarder, %{})
      |> Enum.into(%{})
      |> set_default_if_missing
      |> update_settings_from_environment
  end

  defp set_default_if_missing(config), do: Map.merge(default_values, config)

  defp default_values do
    %{
      enabled: false,
      env: :preview,
      initial_connect_delay: 1000,
      debug_to_stdout: true,
      app_name: nil,
      amqp: [],
      pool_size: 1,
      pool_max_overflow: 1,
      forwarder_high_water_mark: nil
    }
  end

  defp update_settings_from_environment(settings) do
    case System.get_env("LOGJAM_BROKER") do
      nil  -> settings
      ""   -> settings
      host -> put_in(settings, [:amqp, :host], host)
    end
  end
end
