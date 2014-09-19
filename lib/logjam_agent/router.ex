defmodule LogjamAgent.Router do
  defmacro __using__(_) do
    quote do
      use Phoenix.Router
      plug LogjamAgent.Plug
    end
  end
end
