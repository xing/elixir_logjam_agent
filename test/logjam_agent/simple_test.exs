defmodule LogjamAgent.SimpleTest do
  use LogjamAgent.ForwarderTestCase, async: false

  require Logger

  defmodule TestSimple do
    use LogjamAgent.Simple

    def process(params, context)

    @logjam true
    def process(%{exception: true}, _context) do
      :timer.sleep(50)
      raise "BOOM"
    end

    @logjam true
    def process(params, context) do
      :timer.sleep(50)

      new = context
            |> put_in([:assigns, :request_id], LogjamAgent.Metadata.current_request_id)
            |> put_in([:assigns, :action], LogjamAgent.Metadata.fetch(:action))

      new
    end

    def other(_context) do
      :other
    end
  end

  def perform_action(opts \\ []) do
    params = Dict.get(opts, :params, %{})
    context = Dict.get(opts, :context, %{assigns: %{}})

    TestSimple.process(params, context)
  end

  test "clears request_id after process" do
    refute LogjamAgent.Metadata.current_request_id
    perform_action
    refute LogjamAgent.Metadata.current_request_id
  end

  test "instrumented actions publish to logjam" do
    perform_action
    assert [[msg]] = all_forwarded_log_messages
    assert {:log, %{action: "SimpleTest::TestSimple#process"}} = msg
  end

  test "successful runs are represented as 200 status code" do
    perform_action
    assert [[msg]] = all_forwarded_log_messages
    assert {:log, %{code: 200}} = msg
  end

  test "request_id and action are assigned to the process" do
    context = perform_action
    assert context.assigns.request_id
    assert context.assigns.action == "SimpleTest::TestSimple#process"
  end

  test "exceptions are represented as 500 status code" do
    assert :error = perform_action(params: %{exception: true})
    assert [[msg]] = all_forwarded_log_messages
    assert {:log, %{code: 500}} = msg
  end

  test "other functions stay uninstrumented" do
    assert :other = TestSimple.other(:nil)
    assert [[]] = all_forwarded_log_messages
  end
end
