defmodule Core.Schema.Solana.Block do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:slot, :integer, []}
  schema "sol_blocks" do
    field :blockhash, :string
    field :parent_slot, :integer
    field :timestamp, :integer
    field :previous_blockhash, :string
    field :leader, :string
    field :leader_reward, :integer

    # statistics
    field :total_compute_units, :integer
    field :total_fee, :decimal

    timestamps(type: :utc_datetime)

    has_many :transactions, Core.Schema.Solana.Transaction, foreign_key: :block_slot
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [
      :slot,
      :blockhash,
      :parent_slot,
      :timestamp,
      :previous_blockhash,
      :leader,
      :leader_reward,
      :transaction_count,
      :total_compute_units,
      :total_fee
    ])
    |> validate_required([:slot, :blockhash, :timestamp])
    |> unique_constraint(:blockhash)
  end
end
