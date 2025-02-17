defmodule Core.DataProcessor.Monitor do
  use GenServer
  require Logger
  alias Core.Telemetry.Events

  @check_interval :timer.seconds(30)
  # task process time threshold
  @performance_threshold_ms 5_000
  # 10%
  @error_threshold 0.1
  @queue_size_threshold 1000

  @type state :: %{
          pool: atom(),
          interval: pos_integer(),
          last_check: integer() | nil,
          metrics: %{
            # recent tasks time
            task_times: [integer()],
            error_counts: %{atom() => integer()},
            throughput: [integer()]
          },
          alerts: [atom()]
        }

  def start_link(opts) do
    pool = Keyword.fetch!(opts, :pool)
    GenServer.start_link(__MODULE__, opts, name: name(pool))
  end

  def get_health_status(pool) do
    GenServer.call(name(pool), :get_health_status)
  end

  def get_performance_metrics(pool) do
    GenServer.call(name(pool), :get_performance_metrics)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    pool = Keyword.fetch!(opts, :pool)
    interval = Keyword.get(opts, :interval, @check_interval)

    Logger.info("Starting DataProcessor Monitor for pool #{inspect(pool)}")

    # subscribe telemetry events
    subscribe_to_events()

    state = %{
      pool: pool,
      interval: interval,
      last_check: nil,
      metrics: initialize_metrics(),
      alerts: []
    }

    schedule_health_check(interval)

    {:ok, state}
  end

  @impl true
  def handle_info(:check_health, state) do
    {alerts, metrics} = perform_health_check(state.pool)

    handle_alert_changes(state.alerts, alerts)

    :telemetry.execute(
      Events.prefix() ++ [:data_processor, :health_check],
      %{timestamp: System.system_time()},
      %{
        pool: state.pool,
        alerts: alerts,
        metrics: metrics
      }
    )

    schedule_health_check(state.interval)

    {:noreply, %{state | last_check: System.system_time(), alerts: alerts}}
  end

  @impl true
  def handle_info({:telemetry_event, event_name, measurements, metadata}, state) do
    # update metrics
    updated_metrics = update_metrics(state.metrics, event_name, measurements, metadata)

    case check_immediate_alerts(updated_metrics) do
      [] ->
        {:noreply, %{state | metrics: updated_metrics}}

      immediate_alerts ->
        handle_immediate_alerts(immediate_alerts, metadata)
        {:noreply, %{state | metrics: updated_metrics}}
    end
  end

  @impl true
  def handle_call(:get_health_status, _from, state) do
    status = %{
      healthy: Enum.empty?(state.alerts),
      alerts: state.alerts,
      last_check: state.last_check
    }

    {:reply, status, state}
  end

  def handle_call(:get_performance_metrics, _from, state) do
    metrics = calculate_performance_metrics(state.metrics)
    {:reply, metrics, state}
  end

  defp name(pool) do
    :"#{pool}.Monitor"
  end

  defp initialize_metrics do
    %{
      task_times: [],
      error_counts: %{},
      throughput: []
    }
  end

  defp subscribe_to_events do
    :telemetry.attach_many(
      "data-processor-monitor",
      [
        Events.prefix() ++ [:worker_pool, :task_submitted],
        Events.prefix() ++ [:worker_pool, :task_complete],
        Events.prefix() ++ [:worker_pool, :task_failed],
        Events.prefix() ++ [:worker, :task_error],
        Events.prefix() ++ [:worker, :task_complete]
      ],
      &handle_telemetry_event/4,
      nil
    )
  end

  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    if Process.alive?(self()) do
      send(self(), {:telemetry_event, event_name, measurements, metadata})
    end
  end

  defp perform_health_check(pool) do
    # get pool stats
    pool_stats = Core.DataProcessor.WorkerPool.get_stats(pool)

    processing_stats = %{
      ethereum: Core.DataProcessor.State.get_processing_stats(:ethereum),
      solana: Core.DataProcessor.State.get_processing_stats(:solana)
    }

    alerts =
      []
      |> check_worker_count(pool_stats)
      |> check_queue_size(pool_stats)
      |> check_error_rates(processing_stats)
      |> check_processing_delays(processing_stats)
      |> Enum.uniq()

    {alerts, %{pool_stats: pool_stats, processing_stats: processing_stats}}
  end

  defp check_worker_count(alerts, %{worker_count: count, processing_count: processing}) do
    cond do
      count == 0 ->
        [:no_workers | alerts]

      processing / count > 0.9 ->
        [:high_worker_utilization | alerts]

      true ->
        alerts
    end
  end

  defp check_queue_size(alerts, %{queue_size: size}) do
    if size > @queue_size_threshold do
      [:queue_backlog | alerts]
    else
      alerts
    end
  end

  defp check_error_rates(alerts, processing_stats) do
    Enum.reduce(processing_stats, alerts, fn {chain, stats}, acc ->
      error_rate = stats.failed_count / max(stats.processing_count, 1)

      if error_rate > @error_threshold do
        ["#{chain}_high_error_rate" | acc]
      else
        acc
      end
    end)
  end

  defp check_processing_delays(alerts, processing_stats) do
    Enum.reduce(processing_stats, alerts, fn {chain, stats}, acc ->
      if Map.get(stats, :processing_delay, 0) > @performance_threshold_ms do
        ["#{chain}_processing_delay" | acc]
      else
        acc
      end
    end)
  end

  defp update_metrics(metrics, [:core, :worker, :task_complete], measurements, metadata) do
    %{
      metrics
      | task_times: [measurements.duration | Enum.take(metrics.task_times, 99)],
        throughput: [System.system_time(:second) | Enum.take(metrics.throughput, 99)]
    }
  end

  defp update_metrics(metrics, [:core, :worker, :task_error], _measurements, metadata) do
    error_type = get_error_type(metadata)
    current_count = Map.get(metrics.error_counts, error_type, 0)

    %{metrics | error_counts: Map.put(metrics.error_counts, error_type, current_count + 1)}
  end

  defp update_metrics(metrics, _event, _measurements, _metadata) do
    metrics
  end

  defp get_error_type(metadata) do
    cond do
      Map.has_key?(metadata, :error_type) -> metadata.error_type
      Map.has_key?(metadata, :error) -> classify_error(metadata.error)
      true -> :unknown
    end
  end

  defp classify_error(error) when is_exception(error), do: error.__struct__
  defp classify_error(_), do: :unknown

  defp check_immediate_alerts(metrics) do
    recent_times = Enum.take(metrics.task_times, 10)

    avg_time =
      if Enum.empty?(recent_times), do: 0, else: Enum.sum(recent_times) / length(recent_times)

    cond do
      avg_time > @performance_threshold_ms * 2 ->
        [:critical_performance_degradation]

      map_size(metrics.error_counts) > 100 ->
        [:high_error_volume]

      true ->
        []
    end
  end

  defp handle_immediate_alerts(alerts, metadata) do
    Enum.each(alerts, fn alert ->
      Logger.warning("Immediate alert triggered",
        alert: alert,
        metadata: metadata
      )

      :telemetry.execute(
        Events.prefix() ++ [:data_processor, :immediate_alert],
        %{timestamp: System.system_time()},
        %{alert: alert, metadata: metadata}
      )
    end)
  end

  defp handle_alert_changes(old_alerts, new_alerts) do
    Enum.each(new_alerts -- old_alerts, fn alert ->
      Logger.warning("New alert triggered: #{alert}")

      :telemetry.execute(
        Events.prefix() ++ [:data_processor, :alert_triggered],
        %{timestamp: System.system_time()},
        %{alert: alert}
      )
    end)

    Enum.each(old_alerts -- new_alerts, fn alert ->
      Logger.info("Alert resolved: #{alert}")

      :telemetry.execute(
        Events.prefix() ++ [:data_processor, :alert_resolved],
        %{timestamp: System.system_time()},
        %{alert: alert}
      )
    end)
  end

  defp calculate_performance_metrics(metrics) do
    %{
      average_processing_time: calculate_average(metrics.task_times),
      error_distribution: metrics.error_counts,
      throughput: calculate_throughput(metrics.throughput),
      recent_error_rate: calculate_error_rate(metrics)
    }
  end

  defp calculate_average([]), do: 0
  defp calculate_average(values), do: Enum.sum(values) / length(values)

  defp calculate_throughput(timestamps) do
    case timestamps do
      [] ->
        0

      timestamps ->
        time_span = List.first(timestamps) - List.last(timestamps)

        if time_span > 0 do
          length(timestamps) / (time_span / 1_000)
        else
          0
        end
    end
  end

  defp calculate_error_rate(%{task_times: times, error_counts: errors}) do
    total_errors = Enum.sum(Map.values(errors))
    total_tasks = length(times) + total_errors

    if total_tasks > 0 do
      total_errors / total_tasks
    else
      0
    end
  end

  defp schedule_health_check(interval) do
    Process.send_after(self(), :check_health, interval)
  end
end
