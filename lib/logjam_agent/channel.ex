defmodule LogjamAgent.Channel do
  alias LogjamAgent.Instrumentation

  @moduledoc """
  Use this module if you want to activate Logjam reporting for `Phoenix` channel implementations.
  This will automatically instrument the `join`, `handle_in` and `handle_out` functions.

  Join is called when a client attempts to "join" a channel. `handle_in` is called whenever
  a message is sent to a channel server from a socket client. `handle_out` is called
  after a channel broadcast in the `Phoenix` application and before a message is forwarded to a
  socket client.

  __Important !!!__: Please remove the `use Phoenix.Channel` from your module when using
  this functionality. This module takes care of the necessary code generation.

  ## Example:
  ```elixir
      defmodule UserChannel do
        use LogjamAgent.Channel

        def join(_topic, _params, socket) do
          {:ok, socket}
        end

        def handle_in(_topic, _payload, socket) do
          {:noreply, socket}
        end

        def handle_out(_topic, _payload, socket) do
          {:noreply, socket}
        end
      end
  ```
  """

  defmacro __using__(opts \\ []) do
    quote do
      opts = unquote(opts)
      @behaviour Phoenix.Channel
      @before_compile unquote(__MODULE__)
      @on_definition  unquote(__MODULE__)
      @phoenix_intercepts []
      @logjam_assigns_to_log []

      @phoenix_log_join Keyword.get(opts, :log_join, :info)
      @phoenix_log_handle_in Keyword.get(opts, :log_handle_in, :debug)

      import unquote(__MODULE__)
      import Phoenix.Socket, only: [assign: 3]
      import Phoenix.Channel, except: [intercept: 1]
      require Logger

      Module.register_attribute(__MODULE__, :logjam_enabled_functions, accumulate: true)

      def __socket__(:private) do
        %{log_join: @phoenix_log_join,
          log_handle_in: @phoenix_log_handle_in}
      end

      def code_change(_old, socket, _extra), do: {:ok, socket}

      def handle_info(_message, socket), do: {:noreply, socket}

      def terminate(_reason, _socket), do: :ok

      defoverridable code_change: 3, handle_info: 2, terminate: 2
    end
  end

  @supported_functions [:join, :handle_in, :handle_out]
  def __on_definition__(env, kind, name, args, guards, body)
  def __on_definition__(_env, :def, name, _args, _guards, nil) when name in @supported_functions, do: nil
  def __on_definition__(%{module: mod}, :def, name, args, guards, [do: body]) when name in @supported_functions and length(args) == 3 do
    definition = %Instrumentation.Definition{
                   name: name,
                   args: args,
                   guards: guards,
                   body: body
                 }

    Module.put_attribute(mod, :logjam_enabled_functions, definition)
  end
  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

  defmacro intercept(events) do
    quote do
      @phoenix_intercepts unquote(events)
    end
  end

  @doc """
    Allows to explicitly add values from
    the socket `assigns` map to the map
    of request headers which is sent to logjam.

    ## Example:
    ```elixir
        defmodule UserChannel do
          use LogjamAgent.Channel

          log_assigns [:auth_token]

          def handle_in(_topic, _payload, socket) do
            {:noreply, socket}
          end
        end
    ```
  """
  defmacro log_assigns(assigns) when is_list(assigns) do
    quote do
      @logjam_assigns_to_log unquote(assigns)
    end
  end

  defmacro __before_compile__(%{module: mod}) do
    logjam_enabled_functions = Module.get_attribute(mod, :logjam_enabled_functions)
    logjam_assigns_to_log    = Module.get_attribute(mod, :logjam_assigns_to_log)
    instrumented_functions   = Instrumentation.instrument_all(
                                 mod,
                                 logjam_enabled_functions,
                                 Instrumentation.Channel,
                                 log_assigns: logjam_assigns_to_log)

    quote do
      def __intercepts__, do: @phoenix_intercepts

      unquote_splicing(instrumented_functions)
    end
  end
end
