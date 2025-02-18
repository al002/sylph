defmodule Core.Repo.Migrations.CreateIndexerTasks do
  use Ecto.Migration

  def change do
    create table(:indexer_tasks) do
      add :chain, :string, null: false
      add :task_type, :string, null: false
      add :status, :string, null: false
      add :data, :map, null: false
      add :attempts, :integer, null: false, default: 0
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create constraint("indexer_tasks", :valid_chain, check: "chain IN ('ethereum', 'solana')")

    create constraint("indexer_tasks", :valid_task_type,
             check: "task_type IN ('block', 'transaction', 'token', 'contract')"
           )

    create constraint("indexer_tasks", :valid_status,
             check: "status IN ('pending', 'processing', 'completed', 'failed')"
           )

    create constraint("indexer_tasks", :non_negative_attempts, check: "attempts >= 0")

    create index(:indexer_tasks, [:chain])
    create index(:indexer_tasks, [:task_type])
    create index(:indexer_tasks, [:status])
    create index(:indexer_tasks, [:inserted_at])
    create index(:indexer_tasks, [:chain, :status])
  end
end
