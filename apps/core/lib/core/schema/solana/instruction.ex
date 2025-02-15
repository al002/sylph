defmodule Core.Schema.Solana.Instruction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sol_instructions" do
    field :program_id, :string
    field :data, :binary
    field :order_index, :integer

    # parsed data
    field :instruction_type, :string
    field :parsed_data, :map
    timestamps(type: :utc_datetime)

    belongs_to :transaction, Core.Schema.Solana.Transaction,
      references: :signature,
      type: :string

    has_many :account_inputs, Core.Schema.Solana.InstructionAccount, foreign_key: :instruction_id
  end

  def changeset(instruction, attrs) do
    instruction
    |> cast(attrs, [
      :program_id,
      :data,
      :order_index,
      :instruction_type,
      :parsed_data,
      :transaction_id
    ])
    |> validate_required([:program_id, :order_index, :transaction_id])
    |> foreign_key_constraint(:transaction_id)
  end
end
