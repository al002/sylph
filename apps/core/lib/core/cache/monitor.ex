defmodule Core.Cache.Monitor do
  @moduledoc """
  Monitor cache status and perf
  """
  
  use GenServer
  require Logger
  alias Core.Telemetry.Events

  @check_interval :timer.seconds(60)

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting cache monitor")
    schedule_check()
    {:ok, %{last_check: nil}}
  end

  @impl true
  def handle_info(:check_caches, state) do
    check_all_caches()
    schedule_check()
    {:noreply, %{state | last_check: System.system_time()}}
  end

  defp schedule_check do
    Process.send_after(self(), :check_caches, @check_interval)
  end

  defp check_all_caches do
    [:block_cache, :transaction_cache, :token_cache]
    |> Enum.each(&check_cache/1)
  end

  defp check_cache(cache_name) do
    case Core.Cache.Store.stats(cache_name) do
      %{hits: hits, misses: misses, memory: memory, size: size} = stats ->
        hit_rate = calculate_hit_rate(hits, misses)
        
        :telemetry.execute(
          Events.prefix() ++ [:cache, :stats],
          %{
            hit_rate: hit_rate,
            memory: memory,
            size: size
          },
          %{
            cache: cache_name,
            stats: stats
          }
        )

        if hit_rate < 0.5 and size > 1000 do
          Logger.warning("Low hit rate (#{hit_rate}) for cache #{cache_name}")
        end

        if memory > 1_000_000_000 do # 1GB
          Logger.warning("High memory usage (#{memory} bytes) for cache #{cache_name}")
        end

      error ->
        Logger.error("Failed to get stats for cache #{cache_name}: #{inspect(error)}")
    end
  rescue
    e ->
      Logger.error("Error checking cache #{cache_name}: #{Exception.message(e)}")
      :telemetry.execute(
        Events.prefix() ++ [:cache, :monitor_error],
        %{timestamp: System.system_time()},
        %{cache: cache_name, error: Exception.message(e)}
      )
  end

  defp calculate_hit_rate(hits, misses) do
    total = hits + misses
    if total > 0, do: hits / total, else: 0
  end
end
