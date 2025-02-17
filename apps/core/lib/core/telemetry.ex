defmodule Core.Telemetry do
  import Telemetry.Metrics

  def metrics do
    [
      # GRPC connection metrics
      last_value("core.grpc.connection.status",
        event_name: [:core, :grpc, :connection, :status],
        description: "GRPC connection status (1: connected, 0: disconnected)"
      ),

      # request delay
      summary("core.grpc.request.duration",
        unit: {:native, :millisecond},
        tags: [:service, :method],
        description: "GRPC request duration"
      ),

      # error counter
      counter("core.grpc.error.count",
        tags: [:service, :method, :reason],
        description: "GRPC error count"
      ),

      # block process
      counter("core.blockchain.blocks.processed",
        tags: [:chain],
        description: "Number of blocks processed"
      ),
      summary("core.blockchain.block.processing_time",
        unit: {:native, :millisecond},
        tags: [:chain],
        description: "Block processing duration"
      ),

      # resource usage
      last_value("core.memory.total",
        event_name: [:core, :memory, :total],
        description: "Total memory usage"
      ),
      last_value("core.memory.process",
        event_name: [:core, :memory, :process],
        tags: [:pid],
        description: "Process memory usage"
      )
    ]
  end

  def handle_periodic_measurements do
    memory = :erlang.memory()

    :telemetry.execute(
      [:core, :memory, :total],
      %{
        total: memory[:total],
        processes: memory[:processes],
        atom: memory[:atom],
        binary: memory[:binary]
      },
      %{}
    )

    # process memory usage
    for {pid, name} <- process_whitelist() do
      if Process.alive?(pid) do
        case Process.info(pid, :memory) do
          {:memory, memory} ->
            :telemetry.execute([:core, :memory, :process], %{memory: memory}, %{pid: name})

          _ ->
            :ok
        end
      end
    end
  end

  defp process_whitelist do
    [
      {Process.whereis(Core.GRPC.ClientManager), "grpc_client_manager"},
      {Process.whereis(Core.NatsHandler), "nats_handler"},
      {Process.whereis(Core.Repo), "repo"}
    ]
    |> Enum.reject(fn {pid, _} -> is_nil(pid) end)
  end
end

