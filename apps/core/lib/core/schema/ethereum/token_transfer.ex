defmodule Core.Schema.Ethereum.TokenTransfer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "eth_token_transfers" do
    field :from_address, :string
    field :to_address, :string
    field :value, :decimal
    # ERC20/ERC721/ERC1155
    field :token_type, :string
    # For NFTs
    field :nft_token_id, :decimal

    timestamps(type: :utc_datetime)

    belongs_to :transaction, Core.Schema.Ethereum.Transaction,
      foreign_key: :transaction_hash,
      references: :hash

    belongs_to :token, Core.Schema.Ethereum.Token,
      foreign_key: :token_address,
      references: :address
  end

  def changeset(token_transfer, attrs) do
    token_transfer
    |> cast(attrs, [
      :from_address,
      :to_address,
      :value,
      :token_type,
      :nft_token_id,
      :transaction_id,
      :token_id
    ])
    |> validate_required([:from_address, :to_address, :token_type])
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:token_id)
  end
end
