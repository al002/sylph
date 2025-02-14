defmodule Core.Repo.Migrations.CreateSolanaTables do
  use Ecto.Migration

  def change do
    # Blocks table
    create table(:sol_blocks, primary_key: false) do
      add :slot, :bigint, primary_key: true
      add :blockhash, :string, null: false
      add :parent_slot, :bigint
      add :timestamp, :bigint, null: false
      add :previous_blockhash, :string
      add :leader, :string
      add :leader_reward, :bigint

      add :total_compute_units, :bigint
      add :total_fee, :decimal

      timestamps(type: :utc_datetime)
    end

    create index(:sol_blocks, [:timestamp])
    create unique_index(:sol_blocks, [:blockhash])

    # Tokens table
    create table(:sol_tokens, primary_key: false) do
      add :mint, :string, primary_key: true
      add :name, :string
      add :symbol, :string
      add :decimals, :integer
      add :token_type, :string, null: false
      add :supply, :decimal

      timestamps(type: :utc_datetime)
    end

    create index(:sol_tokens, [:token_type])

    # Transactions table
    create table(:sol_transactions, primary_key: false) do
      add :signature, :string, primary_key: true
      add :success, :boolean, null: false
      add :fee, :decimal
      add :compute_units_consumed, :bigint
      add :transaction_category, :string
      add :program_count, :integer
      add :write_account_count, :integer
      add :read_account_count, :integer

      add :slot, references(:sol_blocks, column: :slot, type: :bigint), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sol_transactions, [:slot])
    create index(:sol_transactions, [:transaction_category])

    # Instructions table
    create table(:sol_instructions) do
      add :program_id, :string, null: false
      add :data, :binary
      add :order_index, :integer, null: false
      add :instruction_type, :string
      add :parsed_data, :map

      add :transaction_id, references(:sol_transactions, column: :signature, type: :string),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sol_instructions, [:transaction_id])
    create index(:sol_instructions, [:program_id])

    # Instruction Accounts table
    create table(:sol_instruction_accounts) do
      add :address, :string, null: false
      add :is_signer, :boolean, null: false
      add :is_writable, :boolean, null: false
      add :order_index, :integer, null: false

      add :instruction_id, references(:sol_instructions), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sol_instruction_accounts, [:instruction_id])
    create index(:sol_instruction_accounts, [:address])

    # Token Transfers table
    create table(:sol_token_transfers) do
      add :from_address, :string, null: false
      add :to_address, :string, null: false
      add :amount, :decimal
      add :token_type, :string, null: false

      add :transaction_id, references(:sol_transactions, column: :signature, type: :string),
        null: false

      add :token_id, references(:sol_tokens, column: :mint, type: :string), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sol_token_transfers, [:transaction_id])
    create index(:sol_token_transfers, [:token_id])
    create index(:sol_token_transfers, [:from_address])
    create index(:sol_token_transfers, [:to_address])
  end
end
