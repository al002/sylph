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
  disabled_metrics: [],
  report_interval: 10_000

config :core, :grpc,
  ethereum: [
    endpoint: System.get_env("ETH_GRPC_ENDPOINT", "localhost:50051"),
    max_retries: 5,
    health_check_interval: 10_000
  ]

import_config "#{config_env()}.exs"

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
