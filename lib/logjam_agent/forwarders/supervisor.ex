defmodule LogjamAgent.Forwarders.Supervisor do
  use Supervisor

  alias LogjamAgent.Config
  alias LogjamAgent.Forwarders.{Proxy, Pool}

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    opts = [
      name: {:local, Pool.pool_name},
      worker_module: Proxy,
      max_overflow: config.pool_max_overflow,
      size: config.pool_size
    ]

    children = [
      :poolboy.child_spec(Pool.pool_name, opts, []),
      worker(Pool, []),
    ]

    supervise(children, strategy: :one_for_one)
  end

  defp config, do: Config.current
end
