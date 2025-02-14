import Config

config :core, Core.Repo,
  username: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASS"),
  hostname: System.get_env("DATABASE_HOST"),
  database: "sylph_prod",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :core, :ethereum,
  enabled: true,
  rpc_url: System.get_env("ETH_RPC_URL"),
  ws_url: System.get_env("ETH_WS_URL"),
  start_block: String.to_integer(System.get_env("ETH_START_BLOCK") || "0"),
  batch_size: String.to_integer(System.get_env("ETH_BATCH_SIZE") || "100"),
  grpc_port: String.to_integer(System.get_env("ETH_GRPC_PORT") || "50051"),
  network: System.get_env("ETH_NETWORK") || "mainnet"

config :core, :solana,
  enabled: true,
  rpc_url: System.get_env("SOL_RPC_URL"),
  ws_url: System.get_env("SOL_WS_URL"),
  start_slot: String.to_integer(System.get_env("SOL_START_SLOT") || "0"),
  batch_size: String.to_integer(System.get_env("SOL_BATCH_SIZE") || "100"),
  grpc_port: String.to_integer(System.get_env("SOL_GRPC_PORT") || "50052"),
  network: System.get_env("SOL_NETWORK") || "mainnet-beta"

config :core, :nats,
  host: System.get_env("NATS_HOST") || "localhost",
  port: String.to_integer(System.get_env("NATS_PORT") || "4222")

config :logger,
  level: :info,
  backends: [:console, {LoggerFileBackend, :error_log}]

config :logger, :error_log, level: :info
