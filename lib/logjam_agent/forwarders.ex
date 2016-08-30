defmodule LogjamAgent.Forwarders do
  def forward(msg) do
    LogjamAgent.Forwarders.Pool.forward(msg)
  end

  def forward_event(msg) do
    LogjamAgent.Forwarders.Pool.forward_event(msg)
  end
end
