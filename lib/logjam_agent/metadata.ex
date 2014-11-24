defmodule LogjamAgent.Metadata do
  alias LogjamAgent.Config

  def new_request_id! do
    rid = UUID.uuid1() |> String.replace("-", "")
    current_request_id(rid)
    rid
  end

  def current_request_id, do: Logger.metadata[:logjam_request_id]
  def current_request_id(id), do: Logger.metadata(logjam_request_id: id)

  def store(dict), do: LogjamAgent.Buffer.store(current_request_id, dict)
  def fetch(field), do: LogjamAgent.Buffer.fetch(current_request_id, field)

  def current_caller_id do
    "#{Config.current.app_name}-#{logjam_env}-#{current_request_id}"
  end

  def logjam_env do
    case Mix.env do
      :prod -> :production
      env   -> env
    end
  end
end
