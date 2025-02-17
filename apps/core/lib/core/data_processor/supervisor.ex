defmodule Core.DataProcessor.Supervisor do
  use Supervisor
  require Logger
  alias Core.Telemetry.Events

  @pool_size 10

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting DataProcessor Supervisor")

    :telemetry.execute(
      Events.prefix() ++ [:data_processor, :supervisor, :start],
      %{timestamp: System.system_time()},
      %{}
    )

    children = [
      # State
      {Core.DataProcessor.State, []},

      # Worker pool
      {Core.DataProcessor.WorkerPool,
       [
         size: get_pool_size(),
         name: Core.DataProcessor.WorkerPool
       ]},

      # Monitor
      {Core.DataProcessor.Monitor,
       [
         pool: Core.DataProcessor.WorkerPool,
         interval: get_monitor_interval()
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp get_pool_size do
    Application.get_env(:core, :data_processor, [])
    |> Keyword.get(:pool_size, @pool_size)
  end

  defp get_monitor_interval do
    Application.get_env(:core, :data_processor, [])
    |> Keyword.get(:monitor_interval, :timer.seconds(30))
  end
end
