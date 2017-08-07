defmodule LogjamAgent.Forwarders.Pool do
  use GenServer

  alias LogjamAgent.Config
  alias LogjamAgent.Forwarders.Proxy

  @pool_name :logjam_forwarder_pool

  def pool_name, do: @pool_name

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def forward(msg),       do: do_cast({:forward, :log, msg})
  def forward_event(msg), do: do_cast({:forward, :event, msg})
  def reload_config,      do: GenServer.call(__MODULE__, :reload_config)

  def checkin(worker) do
    :poolboy.checkin(@pool_name, worker)
  end

  def init(_) do
    {:ok, %{config: Config.current}}
  end

  def handle_cast({:forward, _type, _msg}, %{config: %{enabled: false}} = state) do
    {:noreply, state}
  end

  def handle_cast({:forward, type, msg}, state) do
    if message_high_water_mark?(state.config.message_high_water_mark) do
      {:noreply, state}
    else
      worker = :poolboy.checkout(@pool_name)
      Proxy.forward(worker, {type, msg})
      {:noreply, state}
    end
  end

  def handle_call(:reload_config, _from, state) do
    config = Config.current

    pool_name()
      |> GenServer.call(:get_all_workers)
      |> Enum.each(fn({_, worker_pid, _, _}) ->
          Proxy.reload_config(worker_pid, config)
        end)

    new_state = %{state | config: config}

    {:reply, new_state, new_state}
  end

  defp do_cast(msg) do
    try do
      GenServer.cast(__MODULE__, msg)
    rescue
      ArgumentError -> :noproc
    end
  end

  defp message_high_water_mark?(nil), do: false
  defp message_high_water_mark?(high_water_mark) do
    {:message_queue_len, len} = Process.info(self(), :message_queue_len)
    len > high_water_mark
  end
end
