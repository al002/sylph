defmodule Core.Schema.Solana.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:signature, :string, []}
  schema "sol_transactions" do
    field :success, :boolean
    field :fee, :decimal
    field :compute_units_consumed, :integer

    # transfer/program_interaction/etc
    field :transaction_category, :string

    field :program_count, :integer
    field :write_account_count, :integer
    field :read_account_count, :integer

    timestamps(type: :utc_datetime)

    belongs_to :block, Core.Schema.Solana.Block, foreign_key: :block_slot, references: :slot

    has_many :instructions, Core.Schema.Solana.Instruction,
      foreign_key: :transaction_id,
      references: :signature

    has_many :token_transfers, Core.Schema.Solana.TokenTransfer,
      foreign_key: :transaction_id,
      references: :signature
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :signature,
      :success,
      :fee,
      :compute_units_consumed,
      :transaction_category,
      :program_count,
      :write_account_count,
      :read_account_count,
      :slot
    ])
    |> validate_required([:signature, :slot])
    |> unique_constraint(:signature)
    |> foreign_key_constraint(:slot)
  end
end
