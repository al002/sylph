defmodule Core.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:eth_accounts, primary_key: false) do
      add :address, :string, primary_key: true
      add :balance, :decimal, null: false, default: 0
      add :nonce, :bigint, null: false, default: 0
      add :code_hash, :string
      add :is_contract, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create constraint("eth_accounts", :valid_eth_address, check: "address ~ '^0x[a-f0-9]{40}$'")

    create constraint("eth_accounts", :non_negative_balance, check: "balance >= 0")

    create constraint("eth_accounts", :non_negative_nonce, check: "nonce >= 0")

    create index(:eth_accounts, [:is_contract])
    create index(:eth_accounts, [:balance])

    # Solana accounts
    create table(:sol_accounts, primary_key: false) do
      add :address, :string, primary_key: true
      add :balance, :decimal, null: false, default: 0
      add :sequence, :bigint, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create constraint("sol_accounts", :valid_sol_address,
             check: "address ~ '^[1-9A-HJ-NP-Za-km-z]{32,44}$'"
           )

    create constraint("sol_accounts", :non_negative_sol_balance, check: "balance >= 0")

    create index(:sol_accounts, [:balance])
  end
end
