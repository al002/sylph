defmodule Core.Cache.Supervisor do
  use Supervisor
  require Logger
  alias Core.Telemetry.Events

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Cache Supervisor")

    :telemetry.execute(
      Events.prefix() ++ [:cache, :supervisor, :start],
      %{timestamp: System.system_time()},
      %{}
    )

    children = [
      {Core.Cache.Store, [name: :block_cache, ttl: :timer.minutes(30)]},
      {Core.Cache.Store, [name: :transaction_cache, ttl: :timer.minutes(15)]},
      {Core.Cache.Store, [name: :token_cache, ttl: :timer.hours(1)]},
      # # block cache
      # Supervisor.child_spec(
      #   {Core.Cache.Store,
      #    [
      #      name: :block_cache,
      #      ttl: :timer.minutes(30),
      #      max_size: 100_000
      #    ]},
      #   id: :block_cache_store
      # ),
      #
      # # transaction cache
      # Supervisor.child_spec(
      #   {Core.Cache.Store,
      #    [
      #      name: :transaction_cache,
      #      ttl: :timer.minutes(15),
      #      max_size: 500_000
      #    ]},
      #   id: :transaction_cache_store
      # ),
      #
      # # token cache
      # Supervisor.child_spec(
      #   {Core.Cache.Store,
      #    [
      #      name: :token_cache,
      #      ttl: :timer.hours(1),
      #      max_size: 50_000
      #    ]},
      #   id: :token_cache_store
      # ),

      # cache monitor
      Core.Cache.Monitor
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
