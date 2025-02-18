defmodule Core.Repo.Migrations.CreateChainSyncStatus do
  use Ecto.Migration

  def change do
    create table(:chain_sync_status, primary_key: false) do
      add :chain_name, :string, primary_key: true
      add :latest_block_number, :bigint, null: false
      add :latest_block_hash, :string, null: false
      add :earliest_block_number, :bigint, null: false, default: 0
      add :earliest_block_hash, :string
      add :safe_block_number, :bigint, null: false
      add :sync_status, :string, null: false
      add :error_message, :text
      add :syncing_ranges, {:array, :map}, default: []

      timestamps(type: :utc_datetime)
    end

    create constraint("chain_sync_status", :valid_sync_status,
             check: "sync_status IN ('syncing', 'synced', 'error')"
           )

    create constraint("chain_sync_status", :valid_block_numbers,
             check:
               "earliest_block_number <= safe_block_number AND safe_block_number <= latest_block_number"
           )

    create index(:chain_sync_status, [:sync_status])
  end
end
