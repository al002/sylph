# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :core, ecto_repos: [Core.Repo]

config :core, :telemetry,
  report_interval: 10_000,
  disabled_metrics: [],
  log_level: :info

config :core, :grpc,
  ethereum: [
    endpoint: System.get_env("ETH_GRPC_ENDPOINT", "localhost:50051"),
    max_retries: 5
  ],
  solana: [
    endpoint: System.get_env("SOLANA_GRPC_ENDPOINT", "localhost:50052"),
    max_retries: 5
  ]

config :core, :cache,
  block_cache: [
    ttl: :timer.minutes(30),
    max_size: 100_000
  ],
  transaction_cache: [
    ttl: :timer.minutes(15),
    max_size: 500_000
  ],
  token_cache: [
    ttl: :timer.hours(1),
    max_size: 50_000
  ]

config :core, :data_processor,
  pool_size: 10,
  monitor_interval: :timer.seconds(30),
  performance_threshold_ms: 5_000,
  error_threshold: 0.1,
  queue_size_threshold: 1000

import_config "#{config_env()}.exs"

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
