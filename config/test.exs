import Config

# Configure your database
config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sylph_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Ethereum test configuration
config :core, :ethereum,
  enabled: true,
  rpc_url: "http://localhost:8545",
  start_block: 0,
  batch_size: 10,
  grpc_port: 50061,
  network: "goerli"

# Solana test configuration
config :core, :solana,
  enabled: true,
  rpc_url: "http://localhost:8899",
  start_slot: 0,
  batch_size: 10,
  grpc_port: 50062,
  network: "devnet"

# Print only warnings and errors during test
config :logger, level: :warning
