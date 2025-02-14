defmodule Core.Schema.Solana.Token do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:mint, :string, []}
  schema "sol_tokens" do
    field :name, :string
    field :symbol, :string
    field :decimals, :integer
    # SPL/NFT
    field :token_type, :string
    field :supply, :decimal

    timestamps(type: :utc_datetime)

    has_many :transfers, Core.Schema.Solana.TokenTransfer, foreign_key: :token_id
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:mint, :name, :symbol, :decimals, :token_type, :supply])
    |> validate_required([:mint, :token_type])
    |> unique_constraint(:mint)
  end
end
