defmodule Core.DataProcessor.State do
  use GenServer
  require Logger
  alias Core.Telemetry.Events

  @type chain :: :ethereum | :solana
  @type state :: %{
          ethereum: %{
            last_block: integer(),
            processing_blocks: MapSet.t(),
            failed_blocks: MapSet.t()
          },
          solana: %{
            last_slot: integer(),
            processing_slots: MapSet.t(),
            failed_slots: MapSet.t()
          },
          start_time: integer()
        }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Client API

  @spec mark_block_processing(chain(), integer()) :: :ok
  def mark_block_processing(chain, number) do
    GenServer.cast(__MODULE__, {:mark_processing, chain, number})
  end

  @spec mark_block_complete(chain(), integer()) :: :ok
  def mark_block_complete(chain, number) do
    GenServer.cast(__MODULE__, {:mark_complete, chain, number})
  end

  @spec mark_block_failed(chain(), integer()) :: :ok
  def mark_block_failed(chain, number) do
    GenServer.cast(__MODULE__, {:mark_failed, chain, number})
  end

  @spec get_processing_stats(chain()) :: map()
  def get_processing_stats(chain) do
    GenServer.call(__MODULE__, {:get_stats, chain})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting DataProcessor State")

    state = %{
      ethereum: %{
        last_block: 0,
        processing_blocks: MapSet.new(),
        failed_blocks: MapSet.new()
      },
      solana: %{
        last_slot: 0,
        processing_slots: MapSet.new(),
        failed_slots: MapSet.new()
      },
      start_time: System.system_time(:second)
    }

    schedule_metrics_report()

    {:ok, state}
  end

  @impl true
  def handle_cast({:mark_processing, chain, number}, state) do
    chain_state = Map.get(state, chain)
    updated_processing = MapSet.put(chain_state.processing_blocks, number)

    updated_chain = %{chain_state | processing_blocks: updated_processing}

    report_state_change(chain, :processing, number)

    {:noreply, Map.put(state, chain, updated_chain)}
  end

  def handle_cast({:mark_complete, chain, number}, state) do
    chain_state = Map.get(state, chain)

    updated_processing = MapSet.delete(chain_state.processing_blocks, number)
    updated_failed = MapSet.delete(chain_state.failed_blocks, number)
    last_number = max(chain_state.last_block, number)

    updated_chain = %{
      chain_state
      | processing_blocks: updated_processing,
        failed_blocks: updated_failed,
        last_block: last_number
    }

    report_state_change(chain, :complete, number)

    {:noreply, Map.put(state, chain, updated_chain)}
  end

  def handle_cast({:mark_failed, chain, number}, state) do
    chain_state = Map.get(state, chain)

    updated_processing = MapSet.delete(chain_state.processing_blocks, number)
    updated_failed = MapSet.put(chain_state.failed_blocks, number)

    updated_chain = %{
      chain_state
      | processing_blocks: updated_processing,
        failed_blocks: updated_failed
    }

    report_state_change(chain, :failed, number)

    {:noreply, Map.put(state, chain, updated_chain)}
  end

  @impl true
  def handle_call({:get_stats, chain}, _from, state) do
    chain_state = Map.get(state, chain)

    stats = %{
      last_processed: chain_state.last_block,
      processing_count: MapSet.size(chain_state.processing_blocks),
      failed_count: MapSet.size(chain_state.failed_blocks),
      uptime: System.system_time(:second) - state.start_time
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:report_metrics, state) do
    report_metrics(state)
    schedule_metrics_report()
    {:noreply, state}
  end

  defp schedule_metrics_report do
    Process.send_after(self(), :report_metrics, :timer.seconds(60))
  end

  defp report_metrics(state) do
    [:ethereum, :solana]
    |> Enum.each(fn chain ->
      chain_state = Map.get(state, chain)

      :telemetry.execute(
        Events.prefix() ++ [:data_processor, :state],
        %{
          last_processed: chain_state.last_block,
          processing_count: MapSet.size(chain_state.processing_blocks),
          failed_count: MapSet.size(chain_state.failed_blocks)
        },
        %{chain: chain}
      )
    end)
  end

  defp report_state_change(chain, status, number) do
    :telemetry.execute(
      Events.prefix() ++ [:data_processor, :block_status],
      %{timestamp: System.system_time()},
      %{
        chain: chain,
        status: status,
        number: number
      }
    )
  end
end
