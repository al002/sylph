defmodule Core.GRPC.ClientManager do
  use GenServer
  require Logger

  @ethereum_manager_name :ethereum_grpc_manager

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, _pid} =
      Core.GRPC.ConnectionManager.start_link(@ethereum_manager_name,
        endpoint: Keyword.fetch!(opts, :ethereum_endpoint),
        max_retries: 5,
        health_check_interval: 10_000
      )

    {:ok, %{}}
  end

  def get_ethereum_channel do
    case Core.GRPC.ConnectionManager.get_channel(@ethereum_manager_name) do
      {:ok, _channel} = success -> success
      {:error, :not_connected} = error -> error
    end
  end

  def get_ethereum_status do
    Core.GRPC.ConnectionManager.get_status(@ethereum_manager_name)
  end
end

