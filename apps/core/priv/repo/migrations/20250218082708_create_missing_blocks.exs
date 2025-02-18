defmodule Core.Repo.Migrations.CreateMissingBlocks do
  use Ecto.Migration

  def change do
    create table(:missing_blocks) do
      add :chain, :string, null: false
      add :block_number, :bigint, null: false
      add :block_hash, :string
      add :error_type, :string, null: false
      add :error_message, :text
      add :attempts, :integer, null: false, default: 1
      add :last_attempt_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "pending"
      add :priority, :integer, null: false, default: 0
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:missing_blocks, [:chain, :block_number])
    create index(:missing_blocks, [:status])
    create index(:missing_blocks, [:chain, :status])
    create index(:missing_blocks, [:last_attempt_at])

    create constraint("missing_blocks", :valid_chain, check: "chain IN ('ethereum', 'solana')")

    create constraint("missing_blocks", :valid_status,
             check: "status IN ('pending', 'retrying', 'resolved', 'failed')"
           )

    create constraint("missing_blocks", :valid_attempts, check: "attempts >= 1")

    create constraint("missing_blocks", :valid_priority, check: "priority >= 0 AND priority <= 10")
  end
end
