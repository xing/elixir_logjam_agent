defmodule LogjamAgent.Forwarders.ZMQForwarder do
  use GenServer
  require Logger

  alias LogjamAgent.Metadata
  alias Poison, as: JSON

  @sequence_start 0
  @default_port   9_604
  @snd_timeo      5_000
  @rcv_timeo      5_000
  @stop_timeo     5_000

  def default_endpoint, do: {:tcp, "localhost", @default_port}

  def start(config) do
    GenServer.start(__MODULE__, {self, config})
  end

  def forward(pid, msg)
  def forward(pid, {:log, _payload} = msg) do
    GenServer.cast(pid, {:forward, msg})
  end
  def forward(pid, {:event, _payload} = msg) do
    GenServer.call(pid, {:forward, msg})
  end

  def stop(pid) do
    GenServer.stop(pid, :normal, @stop_timeo)
  end

  def init({parent_pid, config}) do
    {:ok, socket} = create_socket
    :ok           = connect(socket, config)
    parent_ref    = Process.monitor(parent_pid)
    state         = %{socket: socket, config: config, sequence: @sequence_start, parent_ref: parent_ref}
    {:ok, state}
  end

  def handle_cast({:forward, msg}, %{config: config} = state) do
    {app_env, key, encoded_msg} = prepare_message(config, msg)
    publish(state, app_env, key, encoded_msg)
  end

  def handle_call({:forward, msg}, _from, %{config: config} = state) do
    {app_env, key, encoded_msg} = prepare_message(config, msg)
    send_receive(state, app_env, key, encoded_msg)
  end

  def handle_info({:DOWN, parent_ref, :process, _pid, _reason}, %{parent_ref: parent_ref} = state) do
    {:stop, :shutdown, state}
  end
  def handle_info({:DOWN, _reference, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  def terminate(reason, socket)
  def terminate(_reason, %{socket: socket}) do
    :ezmq.close(socket)
    :ok
  end
  def terminate(_reason, _state), do: :ok

  defp connect(socket, config) do
    config.endpoints
      |> Enum.map(&connect_host(socket, &1))
      |> Enum.uniq
      |> hd
  end

  defp create_socket do
    :ezmq.start(type: :dealer)
  end

  defp connect_host(socket, {proto, host, port}) do
    :ezmq.connect(socket, proto, String.to_charlist(host), port, send_timeout: @snd_timeo)
  end

  defp prepare_message(config, msg) do
    {
      app_env(config),
      routing_key(config, msg),
      encode_message(msg)
    }
  end

  defp app_env(config) do
    "#{config.app_name}-#{Metadata.logjam_env}"
  end

  defp routing_key(config, msg)
  defp routing_key(config, {:log, _payload}) do
    "logs.#{config.app_name}.#{Metadata.logjam_env}"
  end
  defp routing_key(config, {:event, _payload}) do
    "events.#{config.app_name}.#{Metadata.logjam_env}"
  end

  defp encode_message(msg)
  defp encode_message({_type, payload}) do
    JSON.encode!(payload)
  end

  defp publish(state, app_env, key, encoded_msg) do
    sequence = next_fixnum(state.sequence)
    info     = pack_info(sequence)
    parts    = [app_env, key, encoded_msg, info]

    case :ezmq.send(state.socket, parts) do
      :ok ->
        {:noreply, %{state| sequence: sequence}}
      _ ->
        {:stop, :shutdown, state}
    end
  end

  defp send_receive(state, app_env, key, encoded_msg) do
    sequence      = next_fixnum(state.sequence)
    info          = pack_info(state.sequence)
    request_parts = ["", app_env, key, encoded_msg, info]

    with :ok <- :ezmq.send(state.socket, request_parts),
         {:ok, answer_parts} <- :ezmq.recv(state.socket, @rcv_timeo) do
      inspect_response(answer_parts)
      {:reply, :ok, %{state| sequence: sequence}}
    else
      _ ->
        {:stop, :shutdown, state}
    end
  end

  defp inspect_response(response) do
    unless valid_response?(response) do
      Logger.warn("Unexpected answer from logjam broker: #{inspect(response)}")
    end
  end

  defp valid_response?(response)
  defp valid_response?([<<>>, "200" <> _rest]), do: true
  defp valid_response?([<<>>, "202" <> _rest]), do: true
  defp valid_response?(_),                      do: false

  @fixnum_max :math.pow(2, 64 - 2) - 1
  defp next_fixnum(i) do
    next = i + 1
    if next > @fixnum_max do
      1
    else
      next
    end
  end

  @lint {Credo.Check.Consistency.SpaceAroundOperators, false}
  @meta_info_version 1
  @meta_info_tag 0xcabd
  @meta_info_device_number 0
  @compression_method 0
  defp pack_info(sequence) do
    <<@meta_info_tag::big-integer-unsigned-size(16),
      @compression_method::big-integer-unsigned-size(8),
      @meta_info_version::integer-unsigned-size(8),
      @meta_info_device_number::big-integer-unsigned-size(32),
      zclock_time::big-integer-unsigned-size(64),
      sequence::big-integer-unsigned-size(64)>>
  end

  defp zclock_time do
    {mega, secs, ms} = :os.timestamp
    (mega * 1_000_000 + secs) * 1_000 + :erlang.round(ms / 1000)
  end
end
