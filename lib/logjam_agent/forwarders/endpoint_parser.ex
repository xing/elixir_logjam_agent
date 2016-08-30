defmodule LogjamAgent.Forwarders.EndpointParser do
  import LogjamAgent.Forwarders.ZMQForwarder, only: [default_endpoint: 0]

  def parse!(raw) do
    raw
      |> String.split(",")
      |> Enum.map(&String.strip/1)
      |> Enum.map(&to_endpoint!/1)
  end

  @endpoint_captures ~r{\A(?:([^:]+)://)?([^:]+)(?::(\d+))?\z}
  defp to_endpoint!(raw_endpoint) do
    case Regex.run(@endpoint_captures, raw_endpoint, capture: :all_but_first) do
      ["", host] ->
        {:tcp, host, default_port}
      ["", host, port] ->
        {:tcp, host, String.to_integer(port)}
      [proto, host] ->
        {String.to_atom(proto), host, default_port}
      [proto, host, port] ->
        {String.to_atom(proto), host, String.to_integer(port)}
        _ ->
          raise "Invalid endpoint specified: '#{raw_endpoint}'"
    end
  end

  defp default_port do
    elem(default_endpoint, 2)
  end
end
