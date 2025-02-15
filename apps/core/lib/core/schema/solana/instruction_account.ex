defmodule Core.Schema.Solana.InstructionAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sol_instruction_accounts" do
    field :address, :string
    field :is_signer, :boolean
    field :is_writable, :boolean
    field :order_index, :integer

    timestamps(type: :utc_datetime)

    belongs_to :instruction, Core.Schema.Solana.Instruction
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:address, :is_signer, :is_writable, :order_index, :instruction_id])
    |> validate_required([:address, :is_signer, :is_writable, :instruction_id])
    |> foreign_key_constraint(:instruction_id)
  end
end
