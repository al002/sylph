defmodule Core.DataProcessor.Worker do
  use GenServer
  require Logger
  alias Core.Telemetry.Events

  @type state :: %{
          pool: pid(),
          current_task: nil | map(),
          processed_count: non_neg_integer(),
          start_time: integer(),
          chain_clients: %{
            ethereum: pid() | nil,
            solana: pid() | nil
          }
        }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    pool = Keyword.fetch!(opts, :pool)

    Logger.debug("Starting worker process", worker: self())

    state = %{
      pool: pool,
      current_task: nil,
      processed_count: 0,
      start_time: System.system_time(:millisecond),
      chain_clients: %{
        ethereum: nil,
        solana: nil
      }
    }

    :telemetry.execute(
      Events.prefix() ++ [:worker, :start],
      %{timestamp: System.system_time()},
      %{worker: self()}
    )

    {:ok, state}
  end

  @impl true
  def handle_info({:process_task, task}, state) do
    Logger.debug("Received task",
      worker: self(),
      chain: task.chain,
      type: task.type
    )

    :telemetry.execute(
      Events.prefix() ++ [:worker, :task_start],
      %{timestamp: System.system_time()},
      %{
        worker: self(),
        chain: task.chain,
        type: task.type,
        attempt: task.attempt
      }
    )

    # process task
    {processing_result, updated_state} =
      state
      |> ensure_chain_client(task.chain)
      |> process_task(task)

    # Send result to state
    case processing_result do
      :ok ->
        Core.DataProcessor.State.mark_block_complete(task.chain, task.data.number)

      {:error, _reason} ->
        Core.DataProcessor.State.mark_block_failed(task.chain, task.data.number)
    end

    # Notify worker pool task complete
    send(state.pool, {:task_complete, self(), processing_result})

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    # handle client crash
    updated_state = handle_client_exit(pid, reason, state)
    {:noreply, updated_state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Worker terminating: #{inspect(reason)}", worker: self())

    cleanup_clients(state)

    :telemetry.execute(
      Events.prefix() ++ [:worker, :terminate],
      %{
        timestamp: System.system_time(),
        uptime: System.system_time(:millisecond) - state.start_time,
        processed_count: state.processed_count
      },
      %{
        worker: self(),
        reason: reason
      }
    )
  end

  defp process_task(state, task) do
    start_time = System.monotonic_time()

    try do
      result = do_process_task(task, state)
      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        Events.prefix() ++ [:worker, :task_complete],
        %{
          duration: duration,
          success: match?(:ok, result)
        },
        %{
          worker: self(),
          chain: task.chain,
          type: task.type,
          attempt: task.attempt
        }
      )

      {result, %{state | current_task: nil, processed_count: state.processed_count + 1}}
    catch
      kind, reason ->
        duration = System.monotonic_time() - start_time
        stack = __STACKTRACE__

        Logger.error("Task processing error",
          worker: self(),
          kind: kind,
          reason: reason,
          stack: stack
        )

        :telemetry.execute(
          Events.prefix() ++ [:worker, :task_error],
          %{duration: duration},
          %{
            worker: self(),
            chain: task.chain,
            type: task.type,
            attempt: task.attempt,
            error: Exception.format(kind, reason, stack)
          }
        )

        {{:error, reason}, %{state | current_task: nil}}
    end
  end

  defp do_process_task(%{chain: chain, type: :block} = task, state) do
    client = get_chain_client(state, chain)

    case process_block(client, task.data) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.warning("Block processing failed",
          chain: chain,
          number: task.data.number,
          reason: reason
        )

        error
    end
  end

  defp do_process_task(%{chain: chain, type: :transaction} = task, state) do
    client = get_chain_client(state, chain)

    case process_transaction(client, task.data) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.warning("Transaction processing failed",
          chain: chain,
          hash: task.data.hash,
          reason: reason
        )

        error
    end
  end

  defp process_block(client, %{chain: :ethereum} = block) do
    with :ok <- validate_ethereum_block(block),
         :ok <- store_ethereum_block(block),
         :ok <- process_ethereum_transactions(client, block) do
      :ok
    end
  end

  defp process_block(client, %{chain: :solana} = block) do
    with :ok <- validate_solana_block(block),
         :ok <- store_solana_block(block),
         :ok <- process_solana_transactions(client, block) do
      :ok
    end
  end

  defp validate_ethereum_block(block) do
    # TODO:
    :ok
  end

  defp validate_solana_block(block) do
    # TODO: 
    :ok
  end

  defp store_ethereum_block(block) do
    # TODO: 
    :ok
  end

  defp store_solana_block(block) do
    # TODO: 
    :ok
  end

  defp process_transaction(client, %{chain: :ethereum} = tx) do
    # TODO:
    :ok
    # with :ok <- validate_ethereum_transaction(tx),
    #      :ok <- store_ethereum_transaction(tx),
    #      :ok <- process_ethereum_token_transfers(tx),
    #      :ok <- process_ethereum_logs(tx) do
    #   :ok
    # end
  end

  defp process_transaction(client, %{chain: :solana} = tx) do
    # TODO:
    :ok
    # with :ok <- validate_solana_transaction(tx),
    #      :ok <- store_solana_transaction(tx),
    #      :ok <- process_solana_token_transfers(tx),
    #      :ok <- process_solana_instructions(tx) do
    #   :ok
    # end
  end

  defp process_ethereum_transactions(_client, _block) do
    # TODO: 
    :ok
  end

  defp process_solana_transactions(_client, _block) do
    # TODO: 
    :ok
  end

  defp ensure_chain_client(state, chain) do
    if get_chain_client(state, chain) do
      state
    else
      {:ok, client} = create_chain_client(chain)
      put_chain_client(state, chain, client)
    end
  end

  defp get_chain_client(state, chain) do
    state.chain_clients[chain]
  end

  defp put_chain_client(state, chain, client) do
    %{state | chain_clients: Map.put(state.chain_clients, chain, client)}
  end

  defp create_chain_client(:ethereum) do
    # TODO: 
    {:ok, nil}
  end

  defp create_chain_client(:solana) do
    # TODO: 
    {:ok, nil}
  end

  defp handle_client_exit(pid, reason, state) do
    case find_client_chain(pid, state) do
      nil ->
        state

      chain ->
        Logger.warning("Chain client crashed",
          chain: chain,
          reason: reason
        )

        # clear crashed client
        %{state | chain_clients: Map.put(state.chain_clients, chain, nil)}
    end
  end

  defp find_client_chain(pid, state) do
    Enum.find_value(state.chain_clients, fn {chain, client_pid} ->
      if client_pid == pid, do: chain
    end)
  end

  defp cleanup_clients(state) do
    state.chain_clients
    |> Enum.each(fn {_chain, client} ->
      if client && Process.alive?(client) do
        Process.exit(client, :shutdown)
      end
    end)
  end
end
