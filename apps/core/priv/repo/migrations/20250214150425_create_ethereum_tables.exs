defmodule Core.Repo.Migrations.CreateEthereumTables do
  use Ecto.Migration

  def change do
    # Blocks table
    create table(:eth_blocks, primary_key: false) do
      add :number, :bigint, primary_key: true
      add :hash, :string, null: false
      add :parent_hash, :string, null: false
      add :timestamp, :bigint, null: false
      add :state_root, :string
      add :transactions_root, :string
      add :receipts_root, :string
      add :miner, :string
      add :gas_used, :bigint
      add :gas_limit, :bigint
      add :base_fee_per_gas, :decimal
      add :difficulty, :decimal
      add :total_difficulty, :decimal

      add :total_value, :decimal
      add :total_gas_used, :decimal

      timestamps(type: :utc_datetime)
    end

    create index(:eth_blocks, [:timestamp])
    create unique_index(:eth_blocks, [:hash])

    # Tokens table
    create table(:eth_tokens, primary_key: false) do
      add :address, :string, primary_key: true
      add :name, :string
      add :symbol, :string
      add :decimals, :integer
      add :token_type, :string, null: false
      add :total_supply, :decimal

      timestamps(type: :utc_datetime)
    end

    create index(:eth_tokens, [:token_type])

    # Transactions table
    create table(:eth_transactions, primary_key: false) do
      add :hash, :string, primary_key: true
      add :from_address, :string, null: false
      add :to_address, :string
      add :value, :decimal, null: false
      add :gas, :bigint
      add :gas_price, :decimal
      add :nonce, :integer
      add :input, :binary
      add :transaction_type, :integer
      add :max_fee_per_gas, :decimal
      add :max_priority_fee_per_gas, :decimal
      add :status, :boolean
      add :transaction_category, :string
      add :gas_used, :bigint
      add :effective_gas_price, :decimal
      add :total_fee, :decimal
      add :contract_address, :string
      add :method_id, :string
      add :method_name, :string

      add :block_number, references(:eth_blocks, column: :number, type: :bigint), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:eth_transactions, [:block_number])
    create index(:eth_transactions, [:from_address])
    create index(:eth_transactions, [:to_address])
    create index(:eth_transactions, [:contract_address])
    create index(:eth_transactions, [:transaction_category])

    # Token Transfers table
    create table(:eth_token_transfers) do
      add :from_address, :string, null: false
      add :to_address, :string, null: false
      add :value, :decimal
      add :token_type, :string, null: false
      add :nft_token_id, :decimal

      add :transaction_id, references(:eth_transactions, column: :hash, type: :string),
        null: false

      add :token_id, references(:eth_tokens, column: :address, type: :string), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:eth_token_transfers, [:transaction_id])
    create index(:eth_token_transfers, [:token_id])
    create index(:eth_token_transfers, [:from_address])
    create index(:eth_token_transfers, [:to_address])

    # Logs table
    create table(:eth_logs) do
      add :address, :string, null: false
      add :topics, {:array, :string}
      add :data, :binary
      add :index, :integer

      add :transaction_id, references(:eth_transactions, column: :hash, type: :string),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:eth_logs, [:transaction_id])
    create index(:eth_logs, [:address])
  end
end
