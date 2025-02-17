defmodule Core.GRPC.Supervisor do
  @moduledoc """
  Supervise GRPC processes
  """

  use Supervisor
  require Logger
  alias Core.Telemetry.Events

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting GRPC Supervisor")

    :telemetry.execute(
      Events.prefix() ++ [:grpc, :supervisor, :start],
      %{timestamp: System.system_time()},
      %{}
    )

    children = [
      # process registry
      {Registry, keys: :unique, name: Core.GRPC.Registry},

      # # GRPC connection registry
      Core.GRPC.ConnectionRegistry,

      # Ethereum GRPC client
      Supervisor.child_spec(
        {Core.GRPC.Client,
         [
           key: :ethereum,
           endpoint: get_ethereum_endpoint(),
           max_retries: 5
         ]},
        id: :ethereum_grpc_client
      ),

      # Solana GRPC client
      Supervisor.child_spec(
        {Core.GRPC.Client,
         [
           key: :solana,
           endpoint: get_solana_endpoint(),
           max_retries: 5
         ]},
        id: :solana_grpc_client
      )
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp get_ethereum_endpoint do
    Application.get_env(:core, :grpc)[:ethereum][:endpoint] ||
      raise "Ethereum GRPC endpoint not configured"
  end

  defp get_solana_endpoint do
    Application.get_env(:core, :grpc)[:solana][:endpoint] ||
      raise "Solana GRPC endpoint not configured"
  end
end
