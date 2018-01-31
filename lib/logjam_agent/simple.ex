defmodule LogjamAgent.Simple do
  alias LogjamAgent.Instrumentation

  @moduledoc """
  Use this module if you want to activate Logjam reporting for any plain
  module/function.

  The functions that are to be instrumented should be annotated by `@logjam true`
  module attribute.

  ## Example:
  ```elixir
      defmodule MyModule do
        use LogjamAgent.Simple

        # will be automatically logged
        @logjam true
        def my_function do
          :ok
        end
      end
  ```
  """
  defmacro __using__(_opts \\ []) do
    quote do
      import LogjamAgent.Simple
      require Logger
      Module.register_attribute(__MODULE__, :logjam, accumulate: false)
      Module.register_attribute(__MODULE__, :logjam_enabled_functions, accumulate: true)

      @before_compile LogjamAgent.Simple
      @on_definition  LogjamAgent.Simple
    end
  end

  def __on_definition__(env, kind, name, args, guards, body)
  def __on_definition__(%{module: mod}, :def, name, args, guards, [do: body]) do
    if Module.get_attribute(mod, :logjam) do
      Module.put_attribute(mod, :logjam_enabled_functions, %Instrumentation.Definition{name: name, args: args, guards: guards, body: body})
      Module.delete_attribute(mod, :logjam)
    end
  end
  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

  defmacro __before_compile__(%{module: mod}) do
    logjam_enabled_functions = Module.get_attribute(mod, :logjam_enabled_functions)
    instrumented_actions     = Instrumentation.instrument_all(mod, logjam_enabled_functions, Instrumentation.Simple)

    quote do
      unquote_splicing(instrumented_actions)
    end
  end
end
