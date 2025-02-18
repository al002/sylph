defmodule Core.Chain.State do
  @moduledoc """
  Manages chain sync state including latest blocks, sync status and reorg handling.

  Responsibilities:
  - Track sync progress
  - Detect and handle chain reorganizations
  - Provide consistent state access
  """

  use GenServer
  require Logger
  alias Core.Schema.ChainSyncStatus
  alias Core.Repo
  alias Core.Telemetry.Events

  @type chain :: :ethereum | :solana
  @type sync_status :: :syncing | :synced | :error
  @type state :: %{
          ethereum: %{
            latest_block: non_neg_integer(),
            safe_block: non_neg_integer(),
            status: sync_status(),
            last_update: DateTime.t()
          },
          solana: %{
            latest_slot: non_neg_integer(),
            safe_slot: non_neg_integer(),
            status: sync_status(),
            last_update: DateTime.t()
          }
        }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec get_sync_status(chain()) :: {:ok, ChainSyncStatus.t()} | {:error, term()}
  def get_sync_status(chain) do
    GenServer.call(__MODULE__, {:get_status, chain})
  end

  @spec update_sync_status(chain(), map()) :: :ok | {:error, term()}
  def update_sync_status(chain, params) do
    GenServer.call(__MODULE__, {:update_status, chain, params})
  end

  @spec mark_block_processed(chain(), non_neg_integer(), String.t()) :: :ok | {:error, term()}
  def mark_block_processed(chain, number, hash) do
    GenServer.cast(__MODULE__, {:mark_processed, chain, number, hash})
  end

  @spec detect_reorg(chain(), non_neg_integer(), String.t()) ::
          {:ok, boolean()} | {:error, term()}
  def detect_reorg(chain, number, hash) do
    GenServer.call(__MODULE__, {:detect_reorg, chain, number, hash})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting Chain State")

    # Load initial state from database
    state = %{
      ethereum: load_chain_state(:ethereum),
      solana: load_chain_state(:solana)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_status, chain}, _from, state) do
    case Map.get(state, chain) do
      nil ->
        {:reply, {:error, :invalid_chain}, state}

      chain_state ->
        {:reply, {:ok, chain_state}, state}
    end
  end

  def handle_call({:update_status, chain, params}, _from, state) do
    case update_chain_status(chain, params, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:detect_reorg, chain, number, hash}, _from, state) do
    case detect_chain_reorg(chain, number, hash, state) do
      {:ok, reorg, new_state} ->
        {:reply, {:ok, reorg}, new_state}
    end
  end

  @impl true
  def handle_cast({:mark_processed, chain, number, hash}, state) do
    new_state = do_mark_processed(chain, number, hash, state)
    {:noreply, new_state}
  end

  defp load_chain_state(chain) do
    case Repo.get(ChainSyncStatus, Atom.to_string(chain)) do
      nil ->
        # Initialize new chain state
        %{
          latest_block: 0,
          safe_block: 0,
          status: :syncing,
          last_update: DateTime.utc_now()
        }

      status ->
        # Convert database record to runtime state
        %{
          latest_block: status.latest_block_number,
          safe_block: status.safe_block_number,
          status: String.to_atom(status.sync_status),
          last_update: status.updated_at
        }
    end
  end

  defp update_chain_status(chain, params, state) do
    chain_state = Map.get(state, chain)

    changeset =
      %ChainSyncStatus{}
      |> ChainSyncStatus.changeset(%{
        chain_name: Atom.to_string(chain),
        latest_block_number: params.latest_block,
        latest_block_hash: params.block_hash,
        safe_block_number: params.safe_block,
        sync_status: Atom.to_string(params.status)
      })

    case Repo.insert_or_update(changeset) do
      {:ok, _record} ->
        new_state = %{
          chain_state
          | latest_block: params.latest_block,
            safe_block: params.safe_block,
            status: params.status,
            last_update: DateTime.utc_now()
        }

        :telemetry.execute(
          Events.prefix() ++ [:chain, :sync_status_updated],
          %{timestamp: System.system_time()},
          %{
            chain: chain,
            latest_block: params.latest_block,
            safe_block: params.safe_block,
            status: params.status
          }
        )

        {:ok, Map.put(state, chain, new_state)}

      {:error, changeset} ->
        Logger.error("Failed to update chain status: #{inspect(changeset.errors)}")
        {:error, :invalid_status_update}
    end
  end

  defp detect_chain_reorg(chain, number, hash, state) do
    # Query stored block hash at given number
    case get_stored_block_hash(chain, number) do
      {:ok, ^hash} ->
        # Hashes match - no reorg
        {:ok, false, state}

      {:ok, different_hash} when not is_nil(different_hash) ->
        # Different hash detected - reorg
        handle_reorg_detected(chain, number, hash, state)

      {:ok, nil} ->
        # No stored hash - not a reorg
        {:ok, false, state}
    end
  end

  defp get_stored_block_hash(:ethereum, number) do
    case Repo.get_by(Core.Schema.Ethereum.Block, number: number) do
      nil -> {:ok, nil}
      block -> {:ok, block.hash}
    end
  end

  defp get_stored_block_hash(:solana, slot) do
    case Repo.get_by(Core.Schema.Solana.Block, slot: slot) do
      nil -> {:ok, nil}
      block -> {:ok, block.blockhash}
    end
  end

  defp handle_reorg_detected(chain, number, new_hash, state) do
    Logger.warning("Chain reorganization detected",
      chain: chain,
      block_number: number,
      new_hash: new_hash
    )

    :telemetry.execute(
      Events.prefix() ++ [:chain, :reorg_detected],
      %{timestamp: System.system_time()},
      %{
        chain: chain,
        block_number: number,
        new_hash: new_hash
      }
    )

    # Update state to handle reorg
    chain_state = Map.get(state, chain)
    new_chain_state = %{chain_state | safe_block: min(chain_state.safe_block, number - 1)}
    new_state = Map.put(state, chain, new_chain_state)

    {:ok, true, new_state}
  end

  defp do_mark_processed(chain, number, hash, state) do
    chain_state = Map.get(state, chain)

    if number > chain_state.latest_block do
      %{
        chain_state
        | latest_block: number,
          last_update: DateTime.utc_now()
      }
      |> then(&Map.put(state, chain, &1))
    else
      state
    end
  end
end
