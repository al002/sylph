defmodule Core.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Core.Worker.start_link(arg)
      # {Core.Worker, arg}
      Core.Infra.Supervisor,
      Core.GRPC.Supervisor,
      Core.Cache.Supervisor,
      Core.Chain.Supervisor,
      Core.DataProcessor.Supervisor,
      # Core.Telemetry.Supervisor,
      # Core.Repo,
      # Core.NatsHandler,
      # {Core.GRPC.ClientManager, [
      #   ethereum_endpoint: "localhost:50051",
      #   solana_endpoint: "localhost:50052",
      # ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
