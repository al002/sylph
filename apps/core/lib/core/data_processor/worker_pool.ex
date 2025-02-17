defmodule Core.DataProcessor.WorkerPool do
  use GenServer
  require Logger
  alias Core.Telemetry.Events

  @type task :: %{
          chain: :ethereum | :solana,
          type: :block | :transaction | :token,
          data: map(),
          attempt: non_neg_integer(),
          started_at: integer()
        }

  @type state :: %{
          name: atom(),
          size: pos_integer(),
          workers: %{pid() => reference()},
          tasks: :queue.queue(task()),
          processing: %{pid() => task()},
          worker_module: module()
        }

  @max_attempts 3
  @shutdown_timeout 30_000

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec submit_task(GenServer.server(), atom(), atom(), map()) :: :ok | {:error, term()}
  def submit_task(server, chain, type, data) do
    task = %{
      chain: chain,
      type: type,
      data: data,
      attempt: 1,
      started_at: System.system_time(:millisecond)
    }

    GenServer.call(server, {:submit_task, task})
  end

  @spec get_stats(GenServer.server()) :: map()
  def get_stats(server) do
    GenServer.call(server, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %{
      name: Keyword.fetch!(opts, :name),
      size: Keyword.fetch!(opts, :size),
      workers: %{},
      tasks: :queue.new(),
      processing: %{},
      worker_module: Keyword.get(opts, :worker_module, Core.DataProcessor.Worker)
    }

    Logger.info("Starting worker pool #{state.name} with size #{state.size}")

    :telemetry.execute(
      Events.prefix() ++ [:worker_pool, :start],
      %{timestamp: System.system_time()},
      %{name: state.name, size: state.size}
    )

    send(self(), :start_workers)

    {:ok, state}
  end

  @impl true
  def handle_call({:submit_task, task}, _from, state) do
    case validate_task(task) do
      :ok ->
        # Add task to queue
        updated_state = enqueue_and_process(task, state)
        {:reply, :ok, updated_state}

      {:error, reason} = error ->
        Logger.warning("Invalid task submitted: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      worker_count: map_size(state.workers),
      queue_size: :queue.len(state.tasks),
      processing_count: map_size(state.processing)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:start_workers, state) do
    Logger.debug("Starting #{state.size} workers")
    updated_state = start_workers(state)
    {:noreply, updated_state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    case handle_worker_exit(pid, reason, state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:shutdown, new_state} ->
        {:stop, :shutdown, new_state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Worker pool #{state.name} terminating: #{inspect(reason)}")

    :telemetry.execute(
      Events.prefix() ++ [:worker_pool, :terminate],
      %{timestamp: System.system_time()},
      %{name: state.name, reason: reason}
    )

    # 优雅关闭所有工作进程
    state.workers
    |> Enum.each(fn {pid, _ref} ->
      Process.exit(pid, :shutdown)
    end)

    # wait worker close or timeout
    wait_for_workers(Map.keys(state.workers), @shutdown_timeout)
  end

  defp validate_task(%{chain: chain, type: type, data: data})
       when chain in [:ethereum, :solana] and
              type in [:block, :transaction, :token] and
              is_map(data) do
    :ok
  end

  defp validate_task(_invalid) do
    {:error, :invalid_task_format}
  end

  defp enqueue_and_process(task, state) do
    :telemetry.execute(
      Events.prefix() ++ [:worker_pool, :task_submitted],
      %{timestamp: System.system_time()},
      %{
        chain: task.chain,
        type: task.type,
        attempt: task.attempt
      }
    )

    state = %{state | tasks: :queue.in(task, state.tasks)}
    assign_pending_tasks(state)
  end

  defp assign_pending_tasks(state) do
    case find_available_worker(state) do
      nil ->
        state

      worker_pid ->
        case :queue.out(state.tasks) do
          {{:value, task}, remaining_tasks} ->
            assign_task(worker_pid, task, %{state | tasks: remaining_tasks})

          {:empty, _} ->
            state
        end
    end
  end

  defp find_available_worker(state) do
    busy_workers = Map.keys(state.processing)

    state.workers
    |> Map.keys()
    |> Enum.find(fn pid -> pid not in busy_workers end)
  end

  defp assign_task(worker_pid, task, state) do
    # send task to worker process
    send(worker_pid, {:process_task, task})

    %{state | processing: Map.put(state.processing, worker_pid, task)}
  end

  defp start_workers(state) do
    Enum.reduce(1..state.size, state, fn _, acc ->
      case start_worker(acc) do
        {:ok, pid, ref} ->
          %{acc | workers: Map.put(acc.workers, pid, ref)}

        {:error, reason} ->
          Logger.error("Failed to start worker: #{inspect(reason)}")
          acc
      end
    end)
  end

  defp start_worker(state) do
    case state.worker_module.start_link(pool: self()) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        {:ok, pid, ref}

      error ->
        error
    end
  end

  defp handle_worker_exit(pid, reason, state) do
    Process.demonitor(Map.get(state.workers, pid), [:flush])

    failed_task = Map.get(state.processing, pid)

    state = %{
      state
      | workers: Map.delete(state.workers, pid),
        processing: Map.delete(state.processing, pid)
    }

    :telemetry.execute(
      Events.prefix() ++ [:worker_pool, :worker_exit],
      %{timestamp: System.system_time()},
      %{reason: reason, worker: pid}
    )

    case {reason, map_size(state.workers), failed_task} do
      {:normal, count, _} when count > 0 ->
        {:ok, maybe_restart_worker(state)}

      {_abnormal, count, task} when count > 0 ->
        state = maybe_restart_worker(state)
        state = maybe_retry_task(task, state)
        {:ok, state}

      {_reason, 0, _task} ->
        Logger.error("All workers have terminated, shutting down pool")
        {:shutdown, state}
    end
  end

  defp maybe_restart_worker(state) when map_size(state.workers) < state.size do
    case start_worker(state) do
      {:ok, pid, ref} ->
        %{state | workers: Map.put(state.workers, pid, ref)}

      {:error, reason} ->
        Logger.error("Failed to restart worker: #{inspect(reason)}")
        state
    end
  end

  defp maybe_restart_worker(state), do: state

  defp maybe_retry_task(nil, state), do: state

  defp maybe_retry_task(task, state) do
    if task.attempt < @max_attempts do
      retried_task = %{task | attempt: task.attempt + 1}

      :telemetry.execute(
        Events.prefix() ++ [:worker_pool, :task_retry],
        %{timestamp: System.system_time()},
        %{
          chain: task.chain,
          type: task.type,
          attempt: retried_task.attempt
        }
      )

      # enqueue again
      %{state | tasks: :queue.in(retried_task, state.tasks)}
    else
      :telemetry.execute(
        Events.prefix() ++ [:worker_pool, :task_failed],
        %{timestamp: System.system_time()},
        %{
          chain: task.chain,
          type: task.type,
          attempts: task.attempt
        }
      )

      state
    end
  end

  defp wait_for_workers([], _timeout), do: :ok

  defp wait_for_workers(workers, timeout) do
    receive do
      {:EXIT, pid, _} ->
        wait_for_workers(List.delete(workers, pid), timeout)
    after
      timeout ->
        Logger.warning("Timeout waiting for workers to terminate")
        :timeout
    end
  end
end
