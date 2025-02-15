import Config

# Database configuration
config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sylph_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Ethereum configuration
config :core, :ethereum,
  enabled: true,
  rpc_url: "http://localhost:8545",
  ws_url: "ws://localhost:8546",
  start_block: 0,
  batch_size: 100,
  grpc_port: 50051,
  network: "mainnet"

# Solana configuration
config :core, :solana,
  enabled: true,
  rpc_url: "http://localhost:8899",
  ws_url: "ws://localhost:8900",
  start_slot: 0,
  batch_size: 100,
  grpc_port: 50052,
  network: "mainnet-beta"

# NATS configuration
config :core, :nats,
  host: "localhost",
  port: 4222

# Logging
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  level: :debug
