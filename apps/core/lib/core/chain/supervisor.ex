defmodule Core.Chain.Supervisor do
  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Chain Supervisor")

    children = [
      # Process Registry
      {Registry, keys: :unique, name: Core.Chain.Registry},

      # Chain State
      Core.Chain.State,

      # Chain Syncers
      Supervisor.child_spec(
        {Core.Chain.Syncer, [chain: :ethereum]},
        id: :ethereum_syncer
      ),
      Supervisor.child_spec(
        {Core.Chain.Syncer, [chain: :solana]},
        id: :solana_syncer
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
