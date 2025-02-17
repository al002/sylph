import Config

config :core, Core.Repo,
  username: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASS"),
  hostname: System.get_env("DATABASE_HOST"),
  database: "sylph_prod",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :core, :nats,
  host: System.get_env("NATS_HOST") || "localhost",
  port: String.to_integer(System.get_env("NATS_PORT") || "4222")

config :logger,
  level: :info,
  backends: [:console, {LoggerFileBackend, :error_log}]

config :logger, :error_log, level: :info
