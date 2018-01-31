defmodule LogjamAgent.Socket do
  alias LogjamAgent.Instrumentation

  @moduledoc """
  Use this module if you want to activate Logjam reporting for `Phoenix` socket implementations.
  This will automatically instrument the `connect` function.

  ## Example:
  ```elixir
      defmodule UserSocket do
        use Phoenix.Socket
        use LogjamAgent.Socket

        #will be automatically logged
        def connect(_params, _socket) do
          :ok
        end
      end
  ```
  """
  defmacro __using__(_) do
    quote do
      import LogjamAgent.Socket
      require Logger

      Module.register_attribute(__MODULE__, :logjam_enabled_functions, accumulate: true)

      @before_compile LogjamAgent.Socket
      @on_definition  LogjamAgent.Socket
    end
  end

  def __on_definition__(env, kind, name, args, guards, body)
  def __on_definition__(_env, :def, :connect, _args, _guards, nil), do: nil
  def __on_definition__(%{module: mod}, :def, :connect, args, guards, [do: body]) do
    definition = %Instrumentation.Definition{
                   name: :connect,
                   args: args,
                   guards: guards,
                   body: body
                 }

    Module.put_attribute(mod, :logjam_enabled_functions, definition)
  end
  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

  defmacro __before_compile__(%{module: mod}) do
    logjam_enabled_functions = Module.get_attribute(mod, :logjam_enabled_functions)
    instrumented_actions     = Instrumentation.instrument_all(mod, logjam_enabled_functions, Instrumentation.Socket)

    quote do
      unquote_splicing(instrumented_actions)
    end
  end
end
