defmodule LogjamAgent.Metadata do
  alias LogjamAgent.{Config, Buffer}

  def new_request_id! do
    rid = UUID.uuid4(:hex)
    current_request_id(rid)
    rid
  end

  def current_request_id, do: Logger.metadata[:logjam_request_id]
  def current_request_id(id), do: Logger.metadata(logjam_request_id: id)

  def store(dict), do: Buffer.store(current_request_id, dict)
  def fetch(field), do: Buffer.fetch(current_request_id, field)
  def delete(field), do: Buffer.delete(current_request_id, field)
  def update(field, inital, fun), do: Buffer.update(current_request_id, field, inital, fun)

  def current_caller_id do
    "#{Config.current.app_name}-#{logjam_env}-#{current_request_id}"
  end

  def increment_rest_calls_counter do
    Buffer.update(current_request_id, :rest_calls, 1, &(&1 + 1))
  end

  def collect_exception(name) do
    Buffer.update(current_request_id, :exceptions, [name], fn(old) -> [name | old] end)
  end

  def logjam_env do
    case Config.current.env do
      :prod -> :production
      :prev -> :preview
      env   -> env
    end
  end
end
