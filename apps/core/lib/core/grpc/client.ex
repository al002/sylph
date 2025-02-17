defmodule Core.GRPC.Client do
  @moduledoc """
  Manage gRPC client and retry
  """

  use GenServer
  require Logger
  alias Core.Telemetry.Events

  @default_retry_count 3
  @default_backoff_ms 1000
  @max_backoff_ms 30_000

  defmodule State do
    @moduledoc false
    defstruct [
      :key,
      :endpoint,
      :channel,
      :status,
      :retry_count,
      :max_retries,
      :backoff_ms,
      :timer_ref
    ]
  end

  def start_link(opts) do
    key = Keyword.fetch!(opts, :key)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(key))
  end

  @impl true
  def init(opts) do
    key = Keyword.fetch!(opts, :key)
    endpoint = Keyword.fetch!(opts, :endpoint)

    state = %State{
      key: key,
      endpoint: endpoint,
      channel: nil,
      status: :disconnected,
      retry_count: 0,
      max_retries: Keyword.get(opts, :max_retries, @default_retry_count),
      backoff_ms: @default_backoff_ms,
      timer_ref: nil
    }

    :ok = Core.GRPC.ConnectionRegistry.register(key, endpoint)

    # start connect
    send(self(), :connect)

    {:ok, state}
  end

  @doc """
  get connection channel
  """
  def get_channel(key) do
    GenServer.call(via_tuple(key), :get_channel)
  end

  @doc """
  get connection status
  """
  def get_status(key) do
    GenServer.call(via_tuple(key), :get_status)
  end

  # Server Callbacks

  @impl true
  def handle_call(:get_channel, _from, %{channel: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:get_channel, _from, %{channel: channel} = state) do
    {:reply, {:ok, channel}, state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect(state.endpoint) do
      {:ok, channel} ->
        Logger.info("Successfully connected to GRPC endpoint: #{state.endpoint}")

        :telemetry.execute(
          Events.prefix() ++ [:grpc, :client, :connected],
          %{timestamp: System.system_time()},
          %{key: state.key, endpoint: state.endpoint}
        )

        Core.GRPC.ConnectionRegistry.update_status(state.key, :connected)

        {:noreply,
         %{
           state
           | channel: channel,
             status: :connected,
             retry_count: 0,
             backoff_ms: @default_backoff_ms,
             timer_ref: nil
         }}

      {:error, reason} ->
        Logger.error(
          "Failed to connect to GRPC endpoint: #{state.endpoint}, reason: #{inspect(reason)}"
        )

        :telemetry.execute(
          Events.prefix() ++ [:grpc, :client, :connection_error],
          %{timestamp: System.system_time()},
          %{key: state.key, endpoint: state.endpoint, error: reason}
        )

        if state.retry_count < state.max_retries do
          timer_ref = schedule_reconnect(state.backoff_ms)
          next_backoff = min(state.backoff_ms * 2, @max_backoff_ms)

          Core.GRPC.ConnectionRegistry.update_status(state.key, :connecting)

          {:noreply,
           %{
             state
             | status: :connecting,
               retry_count: state.retry_count + 1,
               backoff_ms: next_backoff,
               timer_ref: timer_ref
           }}
        else
          Logger.error("Max retry attempts reached for GRPC endpoint: #{state.endpoint}")

          Core.GRPC.ConnectionRegistry.update_status(state.key, :disconnected)

          {:noreply, %{state | status: :disconnected, timer_ref: nil}}
        end
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("GRPC Client terminating: #{inspect(reason)}")

    if state.channel do
      GRPC.Stub.disconnect(state.channel)
    end

    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    :telemetry.execute(
      Events.prefix() ++ [:grpc, :client, :terminate],
      %{timestamp: System.system_time()},
      %{key: state.key, reason: reason}
    )
  end

  defp via_tuple(key) do
    {:via, Registry, {Core.GRPC.Registry, {__MODULE__, key}}}
  end

  defp connect(endpoint) do
    start_time = System.monotonic_time()

    result = GRPC.Stub.connect(endpoint)

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      Events.prefix() ++ [:grpc, :client, :connect_attempt],
      %{duration: duration},
      %{endpoint: endpoint, success: match?({:ok, _}, result)}
    )

    result
  end

  defp schedule_reconnect(backoff_ms) do
    Process.send_after(self(), :connect, backoff_ms)
  end
end
