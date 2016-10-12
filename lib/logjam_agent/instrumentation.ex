defmodule LogjamAgent.Instrumentation do
  @default_excluded_functions [action: 2]
  alias LogjamAgent.Instrumentation.Definition

  def exclude_action?(mod, name, arity) do
    globally_excluded?(name, arity) || locally_excluded?(mod, name, arity)
  end

  def globally_excluded?(name, arity) do
    globally_excluded = :logjam_agent
                         |> Application.get_env(:instrumentation, [])
                         |> Keyword.get(:except, @default_excluded_functions)

    Keyword.get(globally_excluded, name) == arity
  end

  def locally_excluded?(mod, name, arity) do
    locally_excluded = Module.get_attribute(mod, :logjam_excluded_functions)

    Keyword.get(locally_excluded, name) == arity
  end

  def instrument_all(mod, definitions, instrumenter, opts \\ []) do
    definitions
      |> Enum.reverse
      |> Enum.map(&instrument(mod, &1, instrumenter, opts))
  end

  def add_exception_guard(definition) do
    quote do
      try do
        unquote(definition.body)
      catch
        kind, reason ->
          Logger.error(Exception.format(kind, reason, System.stacktrace))
          :exception
      end
    end
  end

  defp instrument(mod, definition, instrumenter, opts) do
    function_identifier = {definition.name, length(definition.args)}

    unless Module.overridable?(mod, function_identifier) do
      Module.make_overridable(mod, [function_identifier])
    end

    final_definition = rewrite_args(definition)
    body = instrumenter.instrument(final_definition, opts)

    if Enum.empty?(final_definition.guards) do
      quote do
        @compile :nowarn_unused_vars
        def unquote(final_definition.name)(unquote_splicing(final_definition.args)), do: unquote(body)
      end
    else
      quote do
        @compile :nowarn_unused_vars
        def unquote(final_definition.name)(unquote_splicing(final_definition.args)) when unquote_splicing(final_definition.guards), do: unquote(body)
      end
    end
  end

  defp rewrite_args(definition) do
    %Definition{definition | args: Enum.map(definition.args, &rewrite_arg/1)}
  end

  defp rewrite_arg(arg)
  defp rewrite_arg({name, _l, nil} = arg) when is_atom(name) do
    arg
  end
  defp rewrite_arg({:%{}, l, _data} = arg) do
    {:=, l, [arg, {:generated__, l, nil}]}
  end
  defp rewrite_arg(arg) do
    arg
  end
end
