defmodule Core.Telemetry.Supervisor do
  use Supervisor
  require Logger

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    Logger.info("Starting Telemetry Supervisor")

    # attach telemetry handler
    Core.Telemetry.Handler.attach()

    children = [
      # Telemetry
      {:telemetry_poller, measurements: periodic_measurements(), period: get_report_interval()}

      # Can add prometheus metrics
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp periodic_measurements do
    [
      {Core.Telemetry.Metrics, :dispatch_system_metrics, []},
      {Core.Telemetry.Metrics, :dispatch_process_metrics, []}
    ]
  end

  defp get_report_interval do
    Application.get_env(:core, :telemetry)[:report_interval] || 10_000
  end
end

