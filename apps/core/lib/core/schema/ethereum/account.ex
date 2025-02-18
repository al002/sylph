defmodule Core.Schema.Ethereum.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:address, :string, []}
  schema "eth_accounts" do
    field :balance, :decimal
    field :nonce, :integer
    field :code_hash, :string
    field :is_contract, :boolean, default: false

    has_many :sent_transactions, Core.Schema.Ethereum.Transaction, foreign_key: :from_address

    has_many :received_transactions, Core.Schema.Ethereum.Transaction, foreign_key: :to_address

    timestamps(type: :utc_datetime)
  end

  @required_fields [:address, :balance, :nonce]
  @optional_fields [:code_hash, :is_contract]

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:address, ~r/^0x[a-fA-F0-9]{40}$/)
    |> validate_number(:nonce, greater_than_or_equal_to: 0)
    |> validate_code_hash()
  end

  defp validate_code_hash(changeset) do
    if get_field(changeset, :is_contract) do
      validate_required(changeset, [:code_hash])
    else
      changeset
    end
  end
end
