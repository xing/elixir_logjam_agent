defmodule LogjamAgent.Controller do
  defmacro __using__(_) do
    quote do
      require Logger
      import LogjamAgent.Action
    end
  end
end
