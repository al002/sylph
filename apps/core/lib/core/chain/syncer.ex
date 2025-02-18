defmodule Core.Chain.Syncer do
  @moduledoc """
  Chain synchronization manager that handles both historical and new block syncing.

  Responsibilities:
  - Manages sync state and progress
  - Coordinates historical and new block processing
  - Handles chain reorganizations
  - Records failed blocks for retry
  """

  use GenServer
  require Logger
  alias Core.Repo
  alias Core.Schema.{ChainSyncStatus, MissingBlock}
  alias Core.Telemetry.Events
  alias Core.Chain.BlockRange

  @type chain :: :ethereum | :solana
  @type sync_mode :: :historical | :realtime
  @type block_number :: non_neg_integer()

  defmodule State do
    @moduledoc false
    defstruct [
      :chain,
      :sync_status,
      :latest_block,
      :safe_block,
      :earliest_block,
      :historical_task,
      :realtime_task,
      :start_time,
      :last_progress_report,
      historical_running?: false,
      realtime_running?: false,
      initialized?: false
    ]
  end

  # Client API

  def start_link(opts) do
    chain = Keyword.fetch!(opts, :chain)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(chain))
  end

  @spec get_sync_status(chain()) :: {:ok, map()} | {:error, term()}
  def get_sync_status(chain) do
    GenServer.call(via_tuple(chain), :get_status)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    chain = Keyword.fetch!(opts, :chain)

    Logger.info("Starting chain syncer", chain: chain)

    state = %State{
      chain: chain,
      start_time: System.system_time(:second),
      last_progress_report: System.system_time(:second)
    }

    # Async initialization to not block startup
    send(self(), :initialize)

    {:ok, state}
  end

  @impl true
  def handle_info(:initialize, state) do
    with {:ok, sync_status} <- initialize_sync_status(state.chain),
         {:ok, updated_state} <- initialize_sync_state(state, sync_status) do
      # Start both sync modes
      send(self(), {:start_sync, :historical})
      # send(self(), {:start_sync, :realtime})

      {:noreply, updated_state}
    else
      {:error, reason} ->
        Logger.error(reason)

        Logger.error("Failed to initialize syncer",
          chain: state.chain,
          reason: reason
        )

        # Retry initialization after delay
        Process.send_after(self(), :initialize, :timer.seconds(10))
        {:noreply, state}
    end
  end

  def handle_info({:start_sync, mode}, state) do
    case start_sync_mode(mode, state) do
      {:ok, updated_state} ->
        {:noreply, updated_state}

      {:error, reason} ->
        Logger.error("Failed to start sync mode",
          chain: state.chain,
          mode: mode,
          reason: reason
        )

        # Retry after delay
        Process.send_after(self(), {:start_sync, mode}, :timer.seconds(5))
        {:noreply, state}
    end
  end

  def handle_info({:sync_progress, mode, block_number}, state) do
    # Update sync progress
    updated_state = update_sync_progress(state, mode, block_number)

    # Report progress periodically
    if should_report_progress?(updated_state) do
      report_sync_progress(updated_state)
    end

    {:noreply, updated_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      chain: state.chain,
      latest_block: state.latest_block,
      safe_block: state.safe_block,
      earliest_block: state.earliest_block,
      historical_running: state.historical_running?,
      realtime_running: state.realtime_running?,
      uptime: System.system_time(:second) - state.start_time
    }

    {:reply, {:ok, status}, state}
  end

  defp via_tuple(chain) do
    {:via, Registry, {Core.Chain.Registry, {__MODULE__, chain}}}
  end

  defp initialize_sync_status(chain) do
    case Repo.get(ChainSyncStatus, Atom.to_string(chain)) do
      nil ->
        # First time sync - create initial status
        create_initial_sync_status(chain)

      status ->
        {:ok, status}
    end
  end

  defp create_initial_sync_status(chain) do
    # Get latest block from chain
    case get_chain_latest_block(chain) do
      {:ok, latest_block} ->
        attrs = %{
          chain_name: Atom.to_string(chain),
          latest_block_number: latest_block.block_number,
          latest_block_hash: latest_block.hash,
          # Will be filled when block is processed
          earliest_block_number: latest_block.block_number,
          safe_block_number: latest_block.block_number,
          sync_status: "syncing"
        }

        %ChainSyncStatus{}
        |> ChainSyncStatus.changeset(attrs)
        |> Repo.insert()

      {:error, _} = error ->
        error
    end
  end

  defp initialize_sync_state(state, sync_status) do
    {:ok,
     %{
       state
       | sync_status: sync_status,
         latest_block: sync_status.latest_block_number,
         safe_block: sync_status.safe_block_number,
         earliest_block: sync_status.earliest_block_number,
         initialized?: true
     }}
  end

  defp start_sync_mode(:historical, %{initialized?: false} = state), do: {:ok, state}

  defp start_sync_mode(:historical, state) do
    if state.historical_running? do
      {:ok, state}
    else
      case start_historical_sync(state) do
        {:ok, task} ->
          {:ok, %{state | historical_task: task, historical_running?: true}}

        {:error, _} = error ->
          error
      end
    end
  end

  defp start_sync_mode(:realtime, %{initialized?: false} = state), do: {:ok, state}

  defp start_sync_mode(:realtime, state) do
    if state.realtime_running? do
      {:ok, state}
    else
      case start_realtime_sync(state) do
        {:ok, task} ->
          {:ok, %{state | realtime_task: task, realtime_running?: true}}

        {:error, _} = error ->
          error
      end
    end
  end

  defp start_historical_sync(state) do
    Task.start_link(fn ->
      historical_sync_loop(
        state.chain,
        state.earliest_block - 1,
        state.safe_block
      )
    end)
  end

  defp start_realtime_sync(state) do
    Task.start_link(fn ->
      realtime_sync_loop(
        state.chain,
        state.latest_block + 1
      )
    end)
  end

  defp historical_sync_loop(chain, current_block, target_block) when current_block >= 0 do
    case BlockRange.calculate_next_range(chain, current_block, target_block) do
      {:ok, {start_block, end_block}, batch_size} ->
        process_historical_batch(chain, start_block, end_block, batch_size)
        historical_sync_loop(chain, start_block - 1, target_block)

      {:error, :no_new_blocks} ->
        # Reached target, wait before checking again
        Process.sleep(:timer.seconds(5))
        historical_sync_loop(chain, current_block, target_block)

      {:error, reason} ->
        Logger.error("Historical sync error",
          chain: chain,
          reason: reason,
          current_block: current_block
        )

        # Retry after delay
        Process.sleep(:timer.seconds(5))
        historical_sync_loop(chain, current_block, target_block)
    end
  end

  defp realtime_sync_loop(chain, start_block) do
    # Subscribe to new blocks
    case subscribe_new_blocks(chain, start_block, &handle_new_block/2) do
      {:ok, subscription} ->
        # Keep task alive
        ref = Process.monitor(subscription)

        # 等待订阅终止或错误
        receive do
          {:DOWN, ^ref, :process, ^subscription, reason} ->
            Logger.warning("Block subscription terminated",
              chain: chain,
              reason: reason
            )

            Process.sleep(:timer.seconds(5))
            realtime_sync_loop(chain, start_block)
        end

      {:error, reason} ->
        Logger.error("Failed to subscribe to new blocks",
          chain: chain,
          reason: reason
        )

        # Retry after delay
        Process.sleep(:timer.seconds(5))
        realtime_sync_loop(chain, start_block)
    end
  end

  defp process_historical_batch(chain, start_block, end_block, batch_size) do
    # Submit batch to processor
    case Core.DataProcessor.WorkerPool.submit_task(
           Core.DataProcessor.WorkerPool,
           chain,
           :block,
           %{
             start_block: start_block,
             end_block: end_block,
             batch_size: batch_size
           }
         ) do
      :ok ->
        notify_progress(chain, :historical, start_block)

      {:error, reason} ->
        Logger.warning("Failed to process historical batch",
          chain: chain,
          start_block: start_block,
          end_block: end_block,
          reason: reason
        )

        # Record failed blocks
        Enum.each(start_block..end_block, fn block ->
          record_failed_block(chain, block, "batch_processing_failed")
        end)
    end
  end

  defp handle_new_block(chain, block) do
    case Core.DataProcessor.WorkerPool.submit_task(
           Core.DataProcessor.WorkerPool,
           chain,
           :block,
           %{
             number: block.number,
             hash: block.hash
           }
         ) do
      :ok ->
        notify_progress(chain, :realtime, block.number)

      {:error, reason} ->
        Logger.warning("Failed to process new block",
          chain: chain,
          block: block.number,
          reason: reason
        )

        record_failed_block(chain, block.number, "new_block_processing_failed")
    end
  end

  defp notify_progress(chain, mode, block_number) do
    if process_alive?(self()) do
      send(self(), {:sync_progress, mode, block_number})
    end
  end

  defp update_sync_progress(state, :historical, block_number) do
    if block_number < state.earliest_block do
      %{state | earliest_block: block_number}
    else
      state
    end
  end

  defp update_sync_progress(state, :realtime, block_number) do
    if block_number > state.latest_block do
      %{state | latest_block: block_number}
    else
      state
    end
  end

  defp should_report_progress?(state) do
    System.system_time(:second) - state.last_progress_report >= 60
  end

  defp report_sync_progress(state) do
    Logger.info("Sync progress",
      chain: state.chain,
      latest_block: state.latest_block,
      earliest_block: state.earliest_block,
      historical_running: state.historical_running?,
      realtime_running: state.realtime_running?
    )

    :telemetry.execute(
      Events.prefix() ++ [:chain, :sync_progress],
      %{
        latest_block: state.latest_block,
        earliest_block: state.earliest_block,
        safe_block: state.safe_block
      },
      %{
        chain: state.chain,
        historical_running: state.historical_running?,
        realtime_running: state.realtime_running?
      }
    )

    %{state | last_progress_report: System.system_time(:second)}
  end

  defp record_failed_block(chain, block_number, error_type) do
    MissingBlock.record_failure(chain, block_number, error_type)
  end

  defp get_chain_latest_block(chain) do
    case chain do
      :ethereum ->
        Core.GRPC.EthereumClient.get_latest_block()

      :solana ->
        # TODO: implement
        {:error, :not_implemented}
    end
  end

  defp subscribe_new_blocks(chain, start_block, callback) do
    case chain do
      :ethereum ->
        Core.GRPC.EthereumClient.subscribe_new_blocks(start_block, callback)

      :solana ->
        # TODO: implement
        {:error, :not_implemented}
    end
  end

  defp process_alive?(pid) do
    Process.alive?(pid)
  end
end
