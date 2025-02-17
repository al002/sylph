defmodule Core.Telemetry.Metrics do
  @moduledoc """
  Gather system metrics
  """

  alias Core.Telemetry.Events

  def dispatch_system_metrics do
    memory = :erlang.memory()

    :telemetry.execute(
      Events.prefix() ++ [:system, :memory],
      %{
        total: memory[:total],
        processes: memory[:processes],
        system: memory[:system],
        atom: memory[:atom],
        binary: memory[:binary],
        ets: memory[:ets]
      },
      %{}
    )

    cpu_stats = get_cpu_stats()

    :telemetry.execute(
      Events.prefix() ++ [:system, :cpu],
      cpu_stats,
      %{}
    )
  end

  def dispatch_process_metrics do
    Process.list()
    |> Enum.filter(&process_filter/1)
    |> Enum.each(&report_process_metrics/1)
  end

  defp get_cpu_stats do
    %{
      system: 0.0,
      user: 0.0,
      total: 0.0
    }
  end

  defp process_filter(pid) do
    case Process.info(pid, [:registered_name]) do
      [{:registered_name, name}] when name != nil ->
        true

      _ ->
        false
    end
  end

  defp report_process_metrics(pid) do
    case Process.info(pid, [:registered_name, :memory, :message_queue_len, :reductions]) do
      [
        {:registered_name, name},
        {:memory, memory},
        {:message_queue_len, queue_len},
        {:reductions, reductions}
      ] ->
        :telemetry.execute(
          Events.prefix() ++ [:process, :metrics],
          %{
            memory: memory,
            message_queue_len: queue_len,
            reductions: reductions
          },
          %{
            name: name
          }
        )

      _ ->
        nil
    end
  end
end
