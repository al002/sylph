defmodule Core.Connection.Manager do
  use GenServer
  require Logger

  @type state :: %{
          name: atom(),
          status: :connected | :disconnected | :connecting,
          connect_fn: (-> {:ok, any()} | {:error, any()}),
          disconnect_fn: (any() -> :ok),
          connection: any(),
          retry_count: non_neg_integer(),
          max_retries: pos_integer(),
          retry_timeout: pos_integer(),
          health_check_interval: pos_integer(),
          health_check_fn: (any() -> boolean())
        }

  @default_max_retries 5
  @default_initial_timeout 1_000
  @default_health_check_interval 10_000

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      name: Keyword.fetch!(opts, :name),
      status: :disconnected,
      connect_fn: Keyword.fetch!(opts, :connect_fn),
      disconnect_fn: Keyword.fetch!(opts, :disconnect_fn),
      connection: nil,
      retry_count: 0,
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      retry_timeout: Keyword.get(opts, :initial_timeout, @default_initial_timeout),
      health_check_interval:
        Keyword.get(opts, :health_check_interval, @default_health_check_interval),
      health_check_fn: Keyword.get(opts, :health_check_fn, &default_health_check/1)
    }

    send(self(), :connect)
    schedule_health_check(state.health_check_interval)

    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect(state) do
      {:ok, connection} ->
        report_status(state.name, :connected)
        {:noreply, %{state | connection: connection, status: :connected, retry_count: 0}}

      {:error, reason} ->
        Logger.error("Failed to connect #{state.name}: #{inspect(reason)}")
        report_status(state.name, :disconnected)

        if state.retry_count < state.max_retries do
          timeout = calculate_retry_timeout(state.retry_timeout, state.retry_count)
          Process.send_after(self(), :connect, timeout)

          {:noreply, %{state | status: :connecting, retry_count: state.retry_count + 1}}
        else
          Logger.error("Max retries reached for #{state.name}")
          {:noreply, %{state | status: :disconnected}}
        end
    end
  end

  def handle_info(:health_check, state) do
    if state.status == :connected do
      case state.health_check_fn.(state.connection) do
        true ->
          schedule_health_check(state.health_check_interval)
          {:noreply, state}

        false ->
          Logger.warning("Health check failed for #{state.name}, initiating reconnect")
          disconnect(state)
          send(self(), :connect)
          {:noreply, %{state | status: :disconnected, connection: nil}}
      end
    else
      schedule_health_check(state.health_check_interval)
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if state.status == :connected do
      disconnect(state)
    end
  end

  @spec get_connection(GenServer.server()) :: {:ok, any()} | {:error, :not_connected}
  def get_connection(server) do
    GenServer.call(server, :get_connection)
  end

  @spec get_status(GenServer.server()) :: :connected | :disconnected | :connecting
  def get_status(server) do
    GenServer.call(server, :get_status)
  end

  # Private functions

  defp connect(state) do
    start_time = System.monotonic_time()

    result = state.connect_fn.()

    duration = System.monotonic_time() - start_time
    report_connection_attempt(state.name, result, duration)

    result
  end

  defp disconnect(%{connection: nil}), do: :ok

  defp disconnect(%{connection: conn, disconnect_fn: fun}) do
    fun.(conn)
  end

  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end

  defp calculate_retry_timeout(initial_timeout, retry_count) do
    min(initial_timeout * :math.pow(2, retry_count), 30_000)
    |> round()
    |> add_jitter()
  end

  defp add_jitter(timeout) do
    jitter = round(timeout * 0.1)
    timeout + :rand.uniform(2 * jitter) - jitter
  end

  defp default_health_check(_conn), do: true

  defp report_status(name, status) do
    :telemetry.execute(
      [:core, :connection, :status],
      %{status: status_to_number(status)},
      %{name: name}
    )
  end

  defp report_connection_attempt(name, result, duration) do
    :telemetry.execute(
      [:core, :connection, :attempt],
      %{duration: duration},
      %{name: name, success: match?({:ok, _}, result)}
    )
  end

  defp status_to_number(:connecting), do: 0
  defp status_to_number(:connected), do: 1
  defp status_to_number(:disconnected), do: -1

  # GenServer callbacks for public API
  @impl true
  def handle_call(:get_connection, _from, %{status: :connected, connection: conn} = state) do
    {:reply, {:ok, conn}, state}
  end

  def handle_call(:get_connection, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end
end
