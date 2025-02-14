defmodule Core.Schema.Solana.TokenTransfer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sol_token_transfers" do
    field :from_address, :string
    field :to_address, :string
    field :amount, :decimal
    # SPL/NFT
    field :token_type, :string

    timestamps(type: :utc_datetime)

    belongs_to :transaction, Core.Schema.Solana.Transaction,
      references: :signature,
      type: :string

    belongs_to :token, Core.Schema.Solana.Token, references: :mint, type: :string
  end

  def changeset(token_transfer, attrs) do
    token_transfer
    |> cast(attrs, [
      :from_address,
      :to_address,
      :amount,
      :token_type,
      :transaction_id,
      :token_id
    ])
    |> validate_required([:from_address, :to_address, :token_type])
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:token_id)
  end
end
