defmodule LogjamAgent.Forwarders.Stub do
  use GenServer
  alias LogjamAgent.Forwarders.{Pool, Proxy}

  @stop_timeo 2_000

  def start(config) do
    GenServer.start(__MODULE__, config)
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

  def messages(pid) do
    GenServer.call(pid, :messages)
  end

  def all_forwarders do
    Pool.pool_name
      |> GenServer.call(:get_all_workers)
      |> Enum.map(fn {_, proxy, _, _} -> Proxy.forwarder_pid(proxy) end)
      |> Enum.reject(&is_nil/1)
  end

  def configs do
    Enum.map(all_forwarders(), &__MODULE__.config/1)
  end

  def config(pid) do
    GenServer.call(pid, :config)
  end

  def messages do
    Enum.map(all_forwarders(), &__MODULE__.messages/1)
  end

  def clear(pid) do
    GenServer.call(pid, :clear)
  end

  def clear_all do
    Enum.map(all_forwarders(), &__MODULE__.clear/1)
  end

  def init(config) do
    {:ok, Map.put(config, :messages, [])}
  end

  def handle_cast({:forward, msg}, state) do
    next = update_in(state, [:messages], fn(old) -> [msg | old] end)
    {:noreply, next}
  end

  def handle_call({:forward, msg}, _from, state) do
    next = update_in(state, [:messages], fn(old) -> [msg | old] end)
    {:reply, :ok, next}
  end

  def handle_call(:messages, _from, state) do
    {:reply, Enum.reverse(state.messages), state}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state| messages: []}}
  end

  def handle_call(:config, _from, state) do
    {:reply, state, state}
  end
end
