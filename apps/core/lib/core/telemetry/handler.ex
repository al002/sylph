defmodule Core.Telemetry.Handler do
  @moduledoc """
  Handle telemetry events
  """

  require Logger
  alias Core.Telemetry.Events

  def attach do
    events_with_handlers()
    |> Enum.each(fn {event, handler} ->
      :telemetry.attach(
        handler_id(event),
        event,
        &__MODULE__.handle_event/4,
        %{handler: handler}
      )
    end)
  end

  def handle_event(event_name, measurements, metadata, config) do
    start_time = System.monotonic_time()

    try do
      handler = Map.get(config, :handler)
      handler.(event_name, measurements, metadata)
    rescue
      e ->
        Logger.error("Telemetry handler error: #{inspect(e)}\nEvent: #{inspect(event_name)}")
        record_handler_error(event_name, e)
    after
      duration = System.monotonic_time() - start_time
      record_handler_duration(event_name, duration)
    end
  end

  defp events_with_handlers do
    [
      {Events.prefix() ++ [:infrastructure, :start], &handle_infrastructure_start/3},
      {Events.prefix() ++ [:infrastructure, :stop], &handle_infrastructure_stop/3},
      {Events.prefix() ++ [:repo, :query], &handle_repo_query/3},
      {Events.prefix() ++ [:repo, :error], &handle_repo_error/3},
      {Events.prefix() ++ [:grpc, :request], &handle_grpc_request/3},
      {Events.prefix() ++ [:grpc, :error], &handle_grpc_error/3},
      {Events.prefix() ++ [:cache, :hit], &handle_cache_hit/3},
      {Events.prefix() ++ [:cache, :miss], &handle_cache_miss/3},
      {Events.prefix() ++ [:cache, :error], &handle_cache_error/3},
      {Events.prefix() ++ [:processor, :start], &handle_processor_start/3},
      {Events.prefix() ++ [:processor, :complete], &handle_processor_complete/3},
      {Events.prefix() ++ [:processor, :error], &handle_processor_error/3},
      {Events.prefix() ++ [:system, :memory], &handle_system_memory/3},
      {Events.prefix() ++ [:system, :cpu], &handle_system_cpu/3}
    ]
  end

  defp handler_id(event_name) do
    {__MODULE__, event_name, :handler}
  end

  defp handle_infrastructure_start(_, measurements, metadata) do
    Logger.info("Infrastructure starting", measurements: measurements, metadata: metadata)
  end

  defp handle_infrastructure_stop(_, measurements, metadata) do
    Logger.info("Infrastructure stopping", measurements: measurements, metadata: metadata)
  end

  defp handle_repo_query(_, %{query_time: query_time} = measurements, metadata) do
    Logger.debug("Database query executed",
      query_time: query_time,
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_repo_error(_, measurements, metadata) do
    Logger.error("Database error occurred",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_grpc_request(_, measurements, metadata) do
    Logger.debug("GRPC request processed",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_grpc_error(_, measurements, metadata) do
    Logger.error("GRPC error occurred",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_cache_hit(_, measurements, metadata) do
    Logger.debug("Cache hit",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_cache_miss(_, measurements, metadata) do
    Logger.debug("Cache miss",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_cache_error(_, measurements, metadata) do
    Logger.error("Cache error occurred",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_processor_start(_, measurements, metadata) do
    Logger.debug("Processor started",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_processor_complete(_, measurements, metadata) do
    Logger.debug("Processor completed",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_processor_error(_, measurements, metadata) do
    Logger.error("Processor error occurred",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_system_memory(_, measurements, _metadata) do
    Logger.info("System memory stats", measurements: measurements)
  end

  defp handle_system_cpu(_, measurements, _metadata) do
    Logger.info("System CPU stats", measurements: measurements)
  end

  defp record_handler_error(event_name, error) do
    :telemetry.execute(
      Events.prefix() ++ [:telemetry, :handler_error],
      %{count: 1},
      %{event: event_name, error: inspect(error)}
    )
  end

  defp record_handler_duration(event_name, duration) do
    :telemetry.execute(
      Events.prefix() ++ [:telemetry, :handler_duration],
      %{duration: duration},
      %{event: event_name}
    )
  end
end
