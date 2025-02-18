defmodule Core.Repo.Migrations.CreateContracts do
  use Ecto.Migration

  def change do
    create table(:eth_contracts, primary_key: false) do
      add :address, :string, primary_key: true
      add :creator, references(:eth_accounts, type: :string, column: :address)
      add :creation_tx, :string, null: false
      add :bytecode, :binary, null: false
      add :abi, :map
      add :contract_type, :string
      add :verified, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create constraint("eth_contracts", :valid_contract_address,
             check: "address ~ '^0x[a-f0-9]{40}$'"
           )

    create constraint("eth_contracts", :valid_creation_tx,
             check: "creation_tx ~ '^0x[a-f0-9]{64}$'"
           )

    create constraint("eth_contracts", :valid_contract_type,
             check: "contract_type IN ('ERC20', 'ERC721', 'ERC1155', 'OTHER')"
           )

    create index(:eth_contracts, [:creator])
    create index(:eth_contracts, [:contract_type])
    create index(:eth_contracts, [:verified])
    create index(:eth_contracts, [:creation_tx])
  end
end
