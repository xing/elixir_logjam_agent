defmodule LogjamAgent do
  use Application
  alias LogjamAgent.Metadata, as: M

  @spec spawn_link((() -> any)) :: pid
  def spawn_link(fun) do
    request_id = M.current_request_id
    Kernel.spawn_link(fn ->
      M.current_request_id(request_id)
      fun.()
    end)
  end

  @spec spawn((() -> any)) :: pid
  def spawn(fun) do
    request_id = M.current_request_id
    Kernel.spawn(fn ->
      M.current_request_id(request_id)
      fun.()
    end)
  end

  def async_task(fun) do
    request_id = M.current_request_id
    Task.async(fn ->
      M.current_request_id(request_id)
      fun.()
    end)
  end

  def send_event(label) when is_list(label), do: label |> List.to_string |> send_event
  def send_event(label) do
    label
    |> LogjamAgent.Transformer.to_logjam_event
    |> LogjamAgent.Forwarders.forward_event
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(LogjamAgent.Forwarders.Supervisor, [], restart: :temporary),
      worker(LogjamAgent.SystemMetrics, []),
      worker(LogjamAgent.Buffer, [])
    ]

    opts = [strategy: :one_for_one, name: LogjamAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
