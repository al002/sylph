defmodule Core.TelemetryUtils do
  defmacro __using__(_opts) do
    quote do
      import Core.TelemetryUtils, only: [telemetry_wrapper: 4]
    end
  end

  defmacro telemetry_wrapper(prefix, name, metadata, do: block) do
    quote do
      start_time = System.monotonic_time()
      result = unquote(block)
      duration = System.monotonic_time() - start_time
      success = Core.TelemetryUtils.success?(result)

      :telemetry.execute(
        unquote(prefix) ++ [unquote(name)],
        %{duration: duration},
        Map.merge(unquote(metadata), %{
          success: success,
          error_type: Core.TelemetryUtils.error_type(result)
        })
      )

      result
    end
  end

  @doc "Helper to determine operation success"
  def success?({:ok, _}), do: true
  def success?(_), do: false

  @doc "Extracts error type from result"
  def error_type({:error, type, _}), do: inspect(type)
  def error_type({:error, _}), do: "unknown"
  def error_type(_), do: nil
end
