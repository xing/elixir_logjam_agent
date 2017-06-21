defmodule LogjamAgent.Handler do
  require Logger
  @moduledoc """
    `Exbeetle.Client.Handler` version that is has `Logjam` integration.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      require Logger
      require Exbeetle.Client.ResultCode

      use Exbeetle.Client.Handler

      alias Exbeetle.Client.{Message, ResultCode}
      alias LogjamAgent.{Metadata, Buffer, Transformer}

      @doc false
      def pre_process(message) do
        request_id = Metadata.new_request_id!
        msg        = Message.assign(message, :request_id, request_id)
        env        = create_env(msg)

        Metadata.current_request_id(request_id)
        Buffer.store(request_id, env)

        log_start(msg)

        {:ok, msg}
      end

      @doc false
      def completed(%{assigns: %{request_id: request_id}}, result) do
        status = if ResultCode.exception?(result), do: :internal_server_error, else: :ok
        log_completion(request_id, status)
        Buffer.finish_request(request_id, __MODULE__)
      end

      @logjam_action_name Transformer.logjam_action_name(__ENV__.module, :process)
      defp log_start(message) do
        Logger.info("Processing #{@logjam_action_name}")
        log_sender_id(message.headers)
        log_sender_action(message.headers)
        log_message_size(message)
      end

      defp log_sender_id(headers)
      defp log_sender_id(%{"sender_id" => sender_id}) do
        Logger.info("Sender id is #{sender_id}")
      end
      defp log_sender_id(_) do
      end

      defp log_sender_action(headers)
      defp log_sender_action(%{"sender_action" => sender_action}) do
        Logger.info("Sender action is #{sender_action}")
      end
      defp log_sender_action(_) do
      end

      defp log_completion(request_id, status) do
        status_code = Plug.Conn.Status.code(status)
        Buffer.store(request_id, %{code: status_code})
        Logger.info("Completed #{status_code} #{status}")
      end

      @module_info %{
        module:   __ENV__.module,
        function: :process,
      }
      defp create_env(message) do
        Map.merge(@module_info, %{
          action_started_at: :os.timestamp,
          request_headers:   message.headers,
          query_string:      "",
          method:            nil,
          request_path:      nil
        })
      end

      defp log_message_size(message) do
        size = String.length(message.raw_payload) / 1024.0
        formatted_size = "~.3.0f"
                            |> :io_lib.format([size])
                            |> List.to_string

        Logger.info("*** #{@logjam_action_name} received a payload with size: #{formatted_size} KB")
      end
    end
  end
end
