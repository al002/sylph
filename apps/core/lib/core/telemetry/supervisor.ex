defmodule Core.Telemetry.Supervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller
      {:telemetry_poller, 
        measurements: periodic_measurements(),
        period: 10_000
      }
      
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp periodic_measurements do
    [
      {Core.Telemetry, :handle_periodic_measurements, []}
    ]
  end
end
