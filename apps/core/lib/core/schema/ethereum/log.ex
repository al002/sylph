defmodule Core.Schema.Ethereum.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "eth_logs" do
    field :address, :string
    field :topics, {:array, :string}
    field :data, :binary
    field :index, :integer

    timestamps(type: :utc_datetime)

    belongs_to :transaction, Core.Schema.Ethereum.Transaction,
      foreign_key: :transaction_hash,
      references: :hash
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:address, :topics, :data, :index, :transaction_id])
    |> validate_required([:address, :transaction_id])
    |> foreign_key_constraint(:transaction_id)
  end
end
