defmodule Core.GRPC.ConnectionManager do
  alias Core.Connection.Manager
  require Logger

  @type connection_opts :: [
    endpoint: String.t(),
    max_retries: pos_integer(),
    health_check_interval: pos_integer()
  ]

  @spec start_link(atom(), connection_opts()) :: GenServer.on_start()
  def start_link(name, opts) do
    endpoint = Keyword.fetch!(opts, :endpoint)
    
    manager_opts = [
      name: name,
      connect_fn: fn -> connect_grpc(endpoint) end,
      disconnect_fn: &disconnect_grpc/1,
      health_check_fn: &health_check_grpc/1,
      max_retries: Keyword.get(opts, :max_retries, 5),
      health_check_interval: Keyword.get(opts, :health_check_interval, 10_000)
    ]
    
    Manager.start_link(manager_opts)
  end

  @spec get_channel(GenServer.server()) :: {:ok, GRPC.Channel.t()} | {:error, :not_connected}
  def get_channel(server) do
    Manager.get_connection(server)
  end

  @spec get_status(GenServer.server()) :: :connected | :disconnected | :connecting
  def get_status(server) do
    Manager.get_status(server)
  end

  # Private functions

  defp connect_grpc(endpoint) do
    Logger.debug("Connecting to GRPC endpoint: #{endpoint}")
    GRPC.Stub.connect(endpoint)
  end

  defp disconnect_grpc(channel) do
    Logger.debug("Disconnecting GRPC channel")
    GRPC.Stub.disconnect(channel)
  end

  defp health_check_grpc(channel) do
    true
  end
end
