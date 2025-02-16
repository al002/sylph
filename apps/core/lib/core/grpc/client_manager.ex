defmodule Core.GRPC.ClientManager do
  use GenServer

  require Logger

  defstruct [:ethereum_channel, :solana_channel]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_ethereum_channel do
    GenServer.call(__MODULE__, :get_ethereum_channel)
  end

  def get_solana_channel do
    GenServer.call(__MODULE__, :get_solana_channel)
  end

  def init(opts) do
    eth_endpoint = Keyword.get(opts, :ethereum_endpoint, "localhost:50051")
    # sol_endpoint = Keyword.get(opts, :solana_endpoint, "localhost:50052")

    {:ok, eth_channel} = GRPC.Stub.connect(eth_endpoint)
    # {:ok, sol_channel} = GRPC.Stub.connect(sol_endpoint)

    state = %__MODULE__{
      ethereum_channel: eth_channel,
      # solana_channel: sol_channel
    }

    {:ok, state}
  end

  def handle_call(:get_ethereum_channel, _from, state) do
    {:reply, state.ethereum_channel, state}
  end

  def handle_call(:get_solana_channel, _from, state) do
    {:reply, state.solana_channel, state}
  end

  def terminate(_reason, state) do
    GRPC.Stub.disconnect(state.ethereum_channel)
    # GRPC.Stub.disconnect(state.solana_channel)
  end
end
