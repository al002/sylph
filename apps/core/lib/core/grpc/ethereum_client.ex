defmodule Core.GRPC.EthereumClient do
  require Logger
  alias Core.GRPC.ClientManager
  use Retry

  @retry_attempts 3
  @retry_delay 1000

  def get_block(block_number) do
    request = %Ethereum.GetBlockRequest{
      block_number: block_number
    }

    with channel <- ClientManager.get_ethereum_channel(),
         {:ok, response} <-
           do_with_retry(fn ->
             Ethereum.EthereumService.Stub.get_block(channel, request)
           end) do
      {:ok, response.block_data}
    else
      {:error, %GRPC.RPCError{} = error} ->
        Logger.error("Failed to get block #{block_number}: #{inspect(error)}")
        {:error, :rpc_error}

      error ->
        Logger.error("Unexpected error getting block #{block_number}: #{inspect(error)}")
        {:error, :unexpected_error}
    end
  end

  def subscribe_new_blocks(start_block, callback) when is_function(callback, 1) do
    request = %Ethereum.SubscribeNewBlocksRequest{start_block: start_block}
    channel = ClientManager.get_ethereum_channel()

    Task.start_link(fn ->
      case Ethereum.EthereumService.Stub.subscribe_new_blocks(channel, request) do
        {:ok, stream} ->
          Enum.each(stream, fn
            {:ok, block_data} ->
              try do
                callback.(block_data)
              rescue
                e ->
                  Logger.error("Error in block callback: #{inspect(e)}")
              end

            {:error, error} ->
              Logger.error("Stream error: #{inspect(error)}")
          end)

        {:error, error} ->
          Logger.error("Failed to subscribe to new blocks: #{inspect(error)}")
          {:error, :subscription_failed}
      end
    end)
  end

  def get_block_range(start_block, end_block) do
    request = %Ethereum.GetBlockRangeRequest{
      start_block: start_block,
      end_block: end_block
    }

    channel = ClientManager.get_ethereum_channel()

    Stream.resource(
      fn ->
        # Initialize the stream
        case Ethereum.EthereumService.Stub.get_block_range(channel, request) do
          {:ok, stream} ->
            stream

          error ->
            Logger.error("Failed to initialize block range stream: #{inspect(error)}")
            nil
        end
      end,
      fn
        nil ->
          {:halt, nil}

        stream ->
          case GRPC.Stub.recv(stream) do
            {:ok, block_data} ->
              {[block_data], stream}

            {:error, error} ->
              Logger.error("Error receiving block data: #{inspect(error)}")
              {:halt, stream}
          end
      end,
      fn
        nil -> :ok
        stream -> GRPC.Stub.end_stream(stream)
      end
    )
  end

  defp do_with_retry(fun) do
    retry with: exponential_backoff() |> cap(@retry_delay) |> Stream.take(@retry_attempts) do
      fun.()
    after
      result -> result
    else
      error -> error
    end
  end
end
