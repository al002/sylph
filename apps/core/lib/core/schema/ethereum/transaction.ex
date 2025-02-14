defmodule Core.Schema.Ethereum.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:hash, :string, []}
  schema "eth_transactions" do
    field :from_address, :string
    field :to_address, :string
    field :value, :decimal
    field :gas, :integer
    field :gas_price, :decimal
    field :nonce, :integer
    field :input, :binary
    field :transaction_type, :integer
    field :max_fee_per_gas, :decimal
    field :max_priority_fee_per_gas, :decimal
    # success or fail
    field :status, :boolean

    # transfer/contract_call/contract_creation/etc
    field :transaction_category, :string

    # gas
    field :gas_used, :integer
    field :effective_gas_price, :decimal
    field :total_fee, :decimal

    # Contract
    field :contract_address, :string
    field :method_id, :string
    field :method_name, :string

    timestamps(type: :utc_datetime)

    belongs_to :block, Core.Schema.Ethereum.Block,
      foreign_key: :block_number,
      references: :block_number

    has_many :token_transfers, Core.Schema.Ethereum.TokenTransfer, foreign_key: :transaction_hash
    has_many :logs, Core.Schema.Ethereum.Log, foreign_key: :transaction_hash
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :hash,
      :from_address,
      :to_address,
      :value,
      :gas,
      :gas_price,
      :nonce,
      :input,
      :transaction_type,
      :max_fee_per_gas,
      :max_priority_fee_per_gas,
      :status,
      :transaction_category,
      :gas_used,
      :effective_gas_price,
      :total_fee,
      :contract_address,
      :method_id,
      :method_name,
      :block_number
    ])
    |> validate_required([:hash, :from_address, :value, :block_number])
    |> unique_constraint(:hash)
    |> foreign_key_constraint(:block_number)
  end
end
