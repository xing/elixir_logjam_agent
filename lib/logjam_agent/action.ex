defmodule LogjamAgent.Action do
  alias LogjamAgent.Instrumentation

  @moduledoc """
  Use this module if you want to activate Logjam reporting for your
  Phoenix controllers. It automatically instruments all exported functions
  in your module to submit data to the logjam service.

  ## Example:
  ```elixir
      defmodule UsersController do
        use LogjamAgent.Action, except: [update: 2]

        def index(conn, params) do
          # information will be reported to logjam
        end

        def update(conn, params) do
          # this function will not report information to logjam
        end
      end
  ``
  Note that you can exclude actions from being instrumented by specifying the `:except` option.
  All actions that match the name and arity as defined in the `:except` keyword list will
  be excluded from instrumentation.

  Beside this local list of actions to be excluded you can also configure a global
  list of actions to be excluded in all modules. This is done via the `:instrumentation`
  configuration.

  ```elixir
  config :logjam_agent, :instrumentation,
         except: [show: 1]
  ```
  """
  defmacro __using__(opts \\ []) do
    quote do
      import LogjamAgent.Action
      Module.register_attribute(__MODULE__, :logjam_enabled_functions, accumulate: true)

      excluded_actions = Keyword.get(unquote(opts), :except, [])
      Module.register_attribute(__MODULE__, :logjam_excluded_functions, accumulate: false)
      Module.put_attribute(__MODULE__, :logjam_excluded_functions, excluded_actions)

      @before_compile LogjamAgent.Action
      @on_definition  LogjamAgent.Action
    end
  end

  def __on_definition__(env, kind, name, args, guards, body)
  def __on_definition__(%{module: mod}, :def, name, args, guards, [do: body]) do
    unless Instrumentation.exclude_action?(mod, name, Enum.count(args)) do
      Module.put_attribute(mod, :logjam_enabled_functions, %Instrumentation.Definition{name: name, args: args, guards: guards, body: body})
    end
  end
  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

  defmacro __before_compile__(%{module: mod}) do
    logjam_enabled_functions = Module.get_attribute(mod, :logjam_enabled_functions)
    instrumented_actions     = Instrumentation.instrument_all(mod, logjam_enabled_functions, Instrumentation.Action)

    quote do
      unquote_splicing(instrumented_actions)
    end
  end
end
