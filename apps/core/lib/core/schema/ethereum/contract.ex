defmodule Core.Schema.Ethereum.Contract do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:address, :string, []}
  schema "eth_contracts" do
    field :creator, :string
    field :creation_tx, :string
    field :bytecode, :binary
    field :abi, :map
    field :contract_type, :string
    field :verified, :boolean, default: false

    belongs_to :creator_account, Core.Schema.Ethereum.Account,
      foreign_key: :creator,
      references: :address,
      define_field: false

    timestamps(type: :utc_datetime)
  end

  @required_fields [:address, :creator, :creation_tx, :bytecode]
  @optional_fields [:abi, :contract_type, :verified]
  @contract_types ["ERC20", "ERC721", "ERC1155", "OTHER"]

  @doc false
  def changeset(contract, attrs) do
    contract
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:address, ~r/^0x[a-fA-F0-9]{40}$/)
    |> validate_format(:creator, ~r/^0x[a-fA-F0-9]{40}$/)
    |> validate_format(:creation_tx, ~r/^0x[a-fA-F0-9]{64}$/)
    |> validate_inclusion(:contract_type, @contract_types)
    |> validate_abi()
    |> foreign_key_constraint(:creator)
  end

  defp validate_abi(changeset) do
    case get_field(changeset, :abi) do
      nil -> changeset
      abi when is_map(abi) -> changeset
      _ -> add_error(changeset, :abi, "must be a valid JSON object")
    end
  end
end
