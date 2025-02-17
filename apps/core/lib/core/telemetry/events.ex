defmodule Core.Telemetry.Events do
  @moduledoc """
  Define all telemetry event
  """

  def prefix, do: [:core]

  @doc "return all telemetry events"
  def all_events do
    [
      # Infra
      prefix() ++ [:infrastructure, :start],
      prefix() ++ [:infrastructure, :stop],

      # Database
      prefix() ++ [:repo, :query],
      prefix() ++ [:repo, :error],

      # GRPC
      prefix() ++ [:grpc, :request],
      prefix() ++ [:grpc, :error],

      # Cache
      prefix() ++ [:cache, :hit],
      prefix() ++ [:cache, :miss],
      prefix() ++ [:cache, :error],

      # Processor
      prefix() ++ [:processor, :start],
      prefix() ++ [:processor, :complete],
      prefix() ++ [:processor, :error],

      # System
      prefix() ++ [:system, :memory],
      prefix() ++ [:system, :cpu]
    ]
  end
end
