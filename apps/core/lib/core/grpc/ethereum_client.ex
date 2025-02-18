defmodule Core.GRPC.EthereumClient do
  @moduledoc """
  Ethereum gRPC client for interacting with blockchain data.
  Provides block retrieval and subscription functionality with proper error handling and metrics.
  """

  require Logger
  alias Core.GRPC.ClientManager
  use Retry
  use Core.TelemetryUtils

  @type block_number :: non_neg_integer()
  @type callback_fn :: (map() -> any())
  @type error_reason :: :rpc_error | :connection_error | :stream_error | :unexpected_error

  @retry_config [
    attempts: 3,
    base_delay: 1_000,
    max_delay: 5_000
  ]

  @telemetry_prefix [:core, :grpc, :ethereum]
  
  @client_key :ethereum

  def get_latest_block() do
    with {:ok, channel} <- get_channel(),
         request <- build_latest_block_request(),
         {:ok, response} <-
           execute_with_retry(fn ->
             Ethereum.EthereumService.Stub.get_latest_block(channel, request)
           end) do
      {:ok, response.latest_block}
    else
      error ->
        Logger.error("Unexpected error getting latest block: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Retrieves a single block by number.

  ## Examples
      iex> get_block(14_000_000)
      {:ok, %{number: 14_000_000, hash: "0x...", ...}}
      
      iex> get_block(-1)
      {:error, :invalid_block_number}
  """
  @spec get_block(block_number()) :: {:ok, map()} | {:error, error_reason(), String.t()}
  def get_block(block_number) when is_integer(block_number) and block_number >= 0 do
    telemetry_wrapper @telemetry_prefix, "get_block", %{block_number: block_number} do
      with {:ok, channel} <- get_channel(),
           request <- build_block_request(block_number),
           {:ok, response} <-
             execute_with_retry(fn ->
               Ethereum.EthereumService.Stub.get_block(channel, request)
             end) do
        {:ok, response.block_data}
      else
        {:error, :not_connected} ->
          {:error, :connection_error, "No active gRPC connection"}

        {:error, %GRPC.RPCError{message: message}} ->
          {:error, :rpc_error, message}

        error ->
          Logger.error("Unexpected error getting block #{block_number}: #{inspect(error)}")
          {:error, :unexpected_error, "Internal error occurred"}
      end
    end
  end

  @doc """
  Subscribes to new blocks starting from the specified block number.
  Calls the provided callback function for each new block.

  ## Examples
      iex> subscribe_new_blocks(14_000_000, fn block -> IO.inspect(block) end)
      {:ok, #PID<0.123.0>}
  """
  @spec subscribe_new_blocks(block_number(), callback_fn()) ::
          {:ok, pid()} | {:error, error_reason()}
  def subscribe_new_blocks(start_block, callback) when is_function(callback, 1) do
    telemetry_wrapper @telemetry_prefix, "subscribe_blocks", %{start_block: start_block} do
      with {:ok, channel} <- get_channel(),
           request <- build_subscription_request(start_block) do
        Task.start_link(fn ->
          handle_subscription_stream(channel, request, callback)
        end)
      end
    end
  end

  @doc """
  Retrieves blocks within the specified range as a stream.
  The stream is automatically cleaned up when enumeration completes or fails.

  ## Examples
      iex> get_block_range(14_000_000, 14_000_100)
      |> Stream.map(&process_block/1)
      |> Stream.run()
  """
  @spec get_block_range(block_number(), block_number()) :: Enumerable.t()
  def get_block_range(start_block, end_block)
      when is_integer(start_block) and is_integer(end_block) and start_block <= end_block do
    Stream.resource(
      fn -> init_range_stream(start_block, end_block) end,
      &process_range_stream/1,
      &cleanup_range_stream/1
    )
  end

  defp get_channel do
    case Core.GRPC.Client.get_channel(@client_key) do
      {:ok, channel} -> {:ok, channel}
      {:error, :not_connected} = error -> error
      error ->
        Logger.error("Unexpected error getting channel: #{inspect(error)}")
        {:error, :connection_error}
    end
  end

  defp build_latest_block_request(), do: %Google.Protobuf.Empty{}

  defp build_block_request(block_number) do
    %Ethereum.GetBlockRequest{block_number: block_number}
  end

  defp build_subscription_request(start_block) do
    %Ethereum.SubscribeNewBlocksRequest{start_block: start_block}
  end

  defp execute_with_retry(fun) do
    retry with:
            exponential_backoff(@retry_config[:base_delay])
            |> cap(@retry_config[:max_delay])
            |> Stream.take(@retry_config[:attempts]) do
      fun.()
    after
      result -> result
    else
      error -> error
    end
  end

  defp handle_subscription_stream(channel, request, callback) do
    case Ethereum.EthereumService.Stub.subscribe_new_blocks(channel, request) do
      {:ok, stream} -> process_subscription(stream, callback)
      {:error, error} -> handle_subscription_error(error)
    end
  end

  defp process_subscription(stream, callback) do
    stream
    |> Stream.each(fn
      {:ok, block} -> execute_callback_safely(callback, block)
      {:error, error} -> Logger.error("Stream error: #{inspect(error)}")
    end)
    |> Stream.run()
  rescue
    error ->
      Logger.error("Subscription failed: #{Exception.format(:error, error, __STACKTRACE__)}")
      {:error, :stream_error}
  end

  defp execute_callback_safely(callback, block) do
    try do
      callback.(block)
    rescue
      error ->
        Logger.error("Callback error: #{Exception.format(:error, error, __STACKTRACE__)}")

        :telemetry.execute(
          @telemetry_prefix ++ [:callback_error],
          %{count: 1},
          %{error: inspect(error)}
        )
    end
  end

  defp init_range_stream(start_block, end_block) do
    request = %Ethereum.GetBlockRangeRequest{
      start_block: start_block,
      end_block: end_block
    }

    case get_channel() do
      {:ok, channel} ->
        case Ethereum.EthereumService.Stub.get_block_range(channel, request) do
          {:ok, stream} -> {:ok, stream, System.monotonic_time()}
          error -> {:error, error}
        end

      error ->
        error
    end
  end

  defp process_range_stream({:ok, stream, start_time}) do
    case GRPC.Stub.recv(stream) do
      {:ok, block} ->
        {[{:ok, block}], {:ok, stream, start_time}}

      {:error, error} ->
        report_stream_error(error, start_time)
        {:halt, {:error, stream}}
    end
  end

  defp process_range_stream(error), do: {:halt, error}

  defp cleanup_range_stream({:ok, stream, _}), do: GRPC.Stub.end_stream(stream)
  defp cleanup_range_stream({:error, stream}), do: GRPC.Stub.end_stream(stream)
  defp cleanup_range_stream(_), do: :ok

  defp handle_subscription_error(error) do
    Logger.error("Failed to subscribe: #{inspect(error)}")
    {:error, :subscription_failed}
  end

  defp report_stream_error(error, start_time) do
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      @telemetry_prefix ++ [:stream_error],
      %{duration: duration},
      %{error: inspect(error)}
    )
  end
end
