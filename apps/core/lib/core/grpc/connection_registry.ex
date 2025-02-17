defmodule Core.GRPC.ConnectionRegistry do
  @moduledoc """
  Manage GRPC connections
  """

  use GenServer
  require Logger
  alias Core.Telemetry.Events

  @type connection_key :: :ethereum | :solana
  @type connection_info :: %{
          endpoint: String.t(),
          status: :connected | :disconnected | :connecting,
          last_connected: DateTime.t() | nil,
          reconnect_attempts: non_neg_integer()
        }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting GRPC Registry")

    :telemetry.execute(
      Events.prefix() ++ [:grpc, :registry, :start],
      %{timestamp: System.system_time()},
      %{}
    )

    {:ok, %{connections: %{}}}
  end

  @doc """
  register new connection
  """
  @spec register(connection_key(), String.t()) :: :ok | {:error, term()}
  def register(key, endpoint) do
    GenServer.call(__MODULE__, {:register, key, endpoint})
  end

  @doc """
  get connection info
  """
  @spec get_connection(connection_key()) :: {:ok, connection_info()} | {:error, :not_found}
  def get_connection(key) do
    GenServer.call(__MODULE__, {:get_connection, key})
  end

  @doc """
  update connection status
  """
  @spec update_status(connection_key(), :connected | :disconnected | :connecting) ::
          :ok | {:error, :not_found}
  def update_status(key, status) do
    GenServer.cast(__MODULE__, {:update_status, key, status})
  end

  @doc """
  list all connections
  """
  @spec list_connections() :: [{connection_key(), connection_info()}]
  def list_connections do
    GenServer.call(__MODULE__, :list_connections)
  end

  # Server Callbacks

  @impl true
  def handle_call({:register, key, endpoint}, _from, %{connections: connections} = state) do
    if Map.has_key?(connections, key) do
      {:reply, {:error, :already_registered}, state}
    else
      connection_info = %{
        endpoint: endpoint,
        status: :disconnected,
        last_connected: nil,
        reconnect_attempts: 0
      }

      :telemetry.execute(
        Events.prefix() ++ [:grpc, :connection, :registered],
        %{timestamp: System.system_time()},
        %{key: key, endpoint: endpoint}
      )

      {:reply, :ok, %{state | connections: Map.put(connections, key, connection_info)}}
    end
  end

  @impl true
  def handle_call({:get_connection, key}, _from, %{connections: connections} = state) do
    case Map.fetch(connections, key) do
      {:ok, connection} -> {:reply, {:ok, connection}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_connections, _from, %{connections: connections} = state) do
    {:reply, Enum.into(connections, []), state}
  end

  @impl true
  def handle_cast({:update_status, key, new_status}, %{connections: connections} = state) do
    case Map.fetch(connections, key) do
      {:ok, connection} ->
        updated_connection = %{
          connection
          | status: new_status,
            last_connected:
              if(new_status == :connected,
                do: DateTime.utc_now(),
                else: connection.last_connected
              ),
            reconnect_attempts:
              if(new_status == :connecting, do: connection.reconnect_attempts + 1, else: 0)
        }

        :telemetry.execute(
          Events.prefix() ++ [:grpc, :connection, :status_changed],
          %{timestamp: System.system_time()},
          %{key: key, status: new_status, attempts: updated_connection.reconnect_attempts}
        )

        {:noreply, %{state | connections: Map.put(connections, key, updated_connection)}}

      :error ->
        Logger.warning("Attempted to update status for unknown connection: #{inspect(key)}")
        {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("GRPC Registry terminating: #{inspect(reason)}")

    :telemetry.execute(
      Events.prefix() ++ [:grpc, :registry, :terminate],
      %{timestamp: System.system_time()},
      %{reason: reason}
    )
  end
end
