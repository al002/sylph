defmodule Core.Schema.Ethereum.Block do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:block_number, :integer, []}
  schema "eth_blocks" do
    field :hash, :string
    field :parent_hash, :string
    field :timestamp, :integer
    field :state_root, :string
    field :receipts_root, :string
    field :miner, :string
    field :gas_used, :integer
    field :base_fee_per_gas, :decimal
    field :difficulty, :decimal
    field :total_difficulty, :decimal

    # statistics
    field :total_value, :decimal
    field :total_gas_used, :decimal

    timestamps(type: :utc_datetime)

    has_many :transactions, Core.Schema.Ethereum.Transaction, foreign_key: :block_number
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [
      :block_number,
      :hash,
      :parent_hash,
      :timestamp,
      :state_root,
      :transactions_root,
      :receipts_root,
      :miner,
      :gas_used,
      :gas_limit,
      :base_fee_per_gas,
      :difficulty,
      :total_difficulty,
      :total_value,
      :total_gas_used
    ])
    |> validate_required([:block_number, :hash, :timestamp])
    |> unique_constraint(:hash)
  end
end
