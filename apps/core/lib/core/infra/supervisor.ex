defmodule Core.Infra.Supervisor do
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.info("Starting Infra Supervisor")
    
    children = [
      Core.Repo,
      Core.Telemetry.Supervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
