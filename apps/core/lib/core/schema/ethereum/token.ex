defmodule Core.Schema.Ethereum.Token do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:address, :string, []}
  schema "eth_tokens" do
    field :name, :string
    field :symbol, :string
    field :decimals, :integer
    field :token_type, :string
    field :total_supply, :decimal

    has_many :transfers, Core.Schema.Ethereum.TokenTransfer,
      foreign_key: :token_address,
      references: :address

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:address, :name, :symbol, :decimals, :token_type, :total_supply])
    |> validate_required([:address, :token_type])
    |> unique_constraint(:address)
  end
end
