defmodule LogjamAgent.Action do
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

  defmodule Instrumentation do
    @default_excluded_actions [action: 2]

    defmodule Definition do
      defstruct name: nil, args: nil, guards: nil, body: nil
    end

    def exclude_action?(mod, name, arity) do
      globally_excluded?(name, arity) || locally_excluded?(mod, name, arity)
    end

    def globally_excluded?(name, arity) do
      globally_excluded = Application.get_env(:logjam_agent, :instrumentation, [])
                           |> Keyword.get(:except, @default_excluded_actions)

      Keyword.get(globally_excluded, name) == arity
    end

    def locally_excluded?(mod, name, arity) do
      locally_excluded = Module.get_attribute(mod, :logjam_excluded_actions)

      Keyword.get(locally_excluded, name) == arity
    end

    def instrument_actions(mod, actions) do
      actions
        |> Enum.reverse
        |> Enum.map(&inject_instrumentation(mod, &1))
    end

    defp inject_instrumentation(mod, action) do
      Module.make_overridable(mod, [{action.name, length(action.args)}])
      body = instrument_action(action)

      if Enum.empty?(action.guards) do
        quote do
          @compile :nowarn_unused_vars
          def unquote(action.name)(unquote_splicing(action.args)), do: unquote(body)
        end
      else
        quote do
          @compile :nowarn_unused_vars
          def unquote(action.name)(unquote_splicing(action.args)) when unquote_splicing(action.guards), do: unquote(body)
        end
      end
    end

    defp instrument_action(action) do
      [conn | _] = action.args

      quote do
        env  = %{
          module:          __ENV__.module,
          function:        unquote(action.name),
          request_headers: unquote(conn).req_headers,
          query_string:    unquote(conn).query_string,
          method:          unquote(conn).method
        }

        Kernel.var!(unquote(conn)) = Plug.Conn.put_resp_header(unquote(conn),
                                                               "x-logjam-request-action",
                                                               LogjamAgent.Transformer.logjam_action_name(env.module, env.function))

        LogjamAgent.Buffer.instrument(
          LogjamAgent.Metadata.current_request_id,
          env,
          fn -> unquote(action.body) end)
      end
    end
  end

  defmacro __using__(opts \\ []) do
    quote do
      import LogjamAgent.Action
      Module.register_attribute(__MODULE__, :logjam_enabled_actions, accumulate: true)

      excluded_actions = Keyword.get(unquote(opts), :except, [])
      Module.register_attribute(__MODULE__, :logjam_excluded_actions, accumulate: false)
      Module.put_attribute(__MODULE__, :logjam_excluded_actions, excluded_actions)

      @before_compile LogjamAgent.Action
      @on_definition  LogjamAgent.Action
    end
  end

  def __on_definition__(env, kind, name, args, guards, body)
  def __on_definition__(%{module: mod}, :def, name, args, guards, body) do
    unless Instrumentation.exclude_action?(mod, name, Enum.count(args)) do
      Module.put_attribute(mod, :logjam_enabled_actions, %Instrumentation.Definition{name: name, args: args, guards: guards, body: body})
    end
  end
  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

  defmacro __before_compile__(%{module: mod}) do
    logjam_enabled_actions = Module.get_attribute(mod, :logjam_enabled_actions)
    instrumented_actions   = Instrumentation.instrument_actions(mod, logjam_enabled_actions)

    quote do
      unquote_splicing(instrumented_actions)
    end
  end
end
