defmodule LogjamAgent.Action do
  @moduledoc """
  Use this module if you want to activate Logjam reporting for your
  Phoenix controllers. It automatically prepares all exported functions
 in your module to submit data to the logjam service.

  ## Example:
      defmodule UsersController do
        use LogjamAgent.Action

        def index(conn, params) do
          # information will be reported to logjam
        end

        @logjam false
        def update(conn, params) do
          # this function will not report information to logjam
        end
      end

  Note thate the `@logjam` module attribute can be used to control whether an exported function
  shall be wired up to report to logjam. If it's set to false it will not expose logjam data.
  """
  defmodule Definition do
    defstruct name: nil, args: nil, guards: nil, body: nil

    def instrument_actions(mod, actions) do
      actions
        |> Enum.reverse
        |> Enum.map(&augment_action(mod, &1))
    end

    defp augment_action(mod, action) do
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

  defmacro __using__(_mod) do
    quote do
      import LogjamAgent.Action
      Module.register_attribute(__MODULE__, :logjam_enabled_actions, accumulate: true)

      @before_compile LogjamAgent.Action
      @on_definition  LogjamAgent.Action
    end
  end

  def __on_definition__(env, kind, name, args, guards, body)
  def __on_definition__(%{module: mod}, :def, name, args, guards, body) do
    unless Module.get_attribute(mod, :logjam) == false do
      Module.put_attribute(mod, :logjam_enabled_actions, %Definition{name: name, args: args, guards: guards, body: body})
    end

    Module.delete_attribute(mod, :logjam)
  end
  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

  defmacro __before_compile__(%{module: mod}) do
    logjam_enabled_actions = Module.get_attribute(mod, :logjam_enabled_actions)
    instrumented_actions   = Definition.instrument_actions(mod, logjam_enabled_actions)

    quote do
      unquote_splicing(instrumented_actions)
    end
  end
end
