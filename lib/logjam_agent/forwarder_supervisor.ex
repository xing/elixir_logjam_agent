defmodule LogjamAgent.ForwarderSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    opts = [
      name: {:local, :logjam_forwarder_pool},
      worker_module: LogjamAgent.Forwarder,
      max_overflow: config.pool_max_overflow,
      size: config.pool_size
    ]

    children = [
      :poolboy.child_spec(:logjam_forwarder_pool, opts, []),
      worker(LogjamAgent.ForwarderPool, []),
    ]

    supervise(children, strategy: :one_for_one)
  end

  defp config do
    LogjamAgent.Config.current
  end
end
