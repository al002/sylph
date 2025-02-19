defmodule Core.Chain.BlockRange do
  @moduledoc """
  Handles block range calculations and batch processing logic.

  Responsibilities:
  - Calculate optimal batch sizes
  - Track processed ranges
  - Handle range splitting and merging
  """

  @type chain :: :ethereum | :solana
  @type range :: {non_neg_integer(), non_neg_integer()}
  @type batch_size :: pos_integer()

  @default_batch_size 500
  @max_batch_size 1000
  @min_batch_size 10

  @doc """
  Calculates the next block range to process based on current sync state.
  Adjusts batch size based on network conditions and processing speed.
  """
  @spec calculate_next_range(chain(), non_neg_integer(), non_neg_integer()) ::
          {:ok, range(), batch_size()} | {:error, term()}
  def calculate_next_range(chain, current_block, target_block) do
    with {:ok, batch_size} <- get_optimal_batch_size(chain),
         {:ok, range} <- do_calculate_range(current_block, target_block, batch_size) do
      {:ok, range, batch_size}
    end
  end

  @doc """
  Splits a range into smaller chunks if needed, based on processing requirements.
  """
  @spec split_range(range(), pos_integer()) :: [range()]
  def split_range({start_block, end_block}, chunk_size) when chunk_size > 0 do
    if end_block - start_block > chunk_size do
      start_block
      |> Stream.iterate(&(&1 + chunk_size))
      |> Stream.take_while(&(&1 <= end_block))
      |> Enum.map(fn chunk_start ->
        chunk_end = min(chunk_start + chunk_size - 1, end_block)
        {chunk_start, chunk_end}
      end)
    else
      [{start_block, end_block}]
    end
  end

  @doc """
  Validates if a block range is valid for processing.
  """
  @spec validate_range(range()) :: :ok | {:error, term()}
  def validate_range({start_block, end_block}) do
    cond do
      start_block < 0 ->
        {:error, :invalid_start_block}

      end_block < start_block ->
        {:error, :invalid_range}

      end_block - start_block > @max_batch_size ->
        {:error, :range_too_large}

      true ->
        :ok
    end
  end

  # Private Functions

  defp get_optimal_batch_size(chain) do
    # TODO: Implement dynamic batch size based on:
    # - Network conditions
    # - Processing speed
    # - Error rates
    {:ok, @default_batch_size}
  end

  defp do_calculate_range(current_block, target_block, batch_size) do
    cond do
      current_block >= target_block ->
        {:error, :no_new_blocks}

      target_block - current_block > @max_batch_size ->
        {:ok, {current_block, current_block + @max_batch_size - 1}}

      true ->
        next_block = min(current_block + batch_size - 1, target_block)
        {:ok, {current_block, next_block}}
    end
  end
end
