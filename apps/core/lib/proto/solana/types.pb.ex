defmodule Solana.Block do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :slot, 1, type: :int64
  field :blockhash, 2, type: :string
  field :parent_slot, 3, type: :int64, json_name: "parentSlot"
  field :timestamp, 4, type: :int64
  field :previous_blockhash, 5, type: :string, json_name: "previousBlockhash"
  field :leader, 6, type: :string
  field :leader_reward, 7, type: :int64, json_name: "leaderReward"
  field :total_compute_units, 8, type: :int64, json_name: "totalComputeUnits"
  field :total_fee, 9, type: :string, json_name: "totalFee"
end

defmodule Solana.Transaction do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :signature, 1, type: :string
  field :success, 2, type: :bool
  field :fee, 3, type: :string
  field :compute_units_consumed, 4, type: :int64, json_name: "computeUnitsConsumed"
  field :transaction_category, 5, type: :string, json_name: "transactionCategory"
  field :program_count, 6, type: :int32, json_name: "programCount"
  field :write_account_count, 7, type: :int32, json_name: "writeAccountCount"
  field :read_account_count, 8, type: :int32, json_name: "readAccountCount"
end

defmodule Solana.Instruction.ParsedDataEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Solana.Instruction do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :program_id, 1, type: :string, json_name: "programId"
  field :data, 2, type: :bytes
  field :order_index, 3, type: :int32, json_name: "orderIndex"
  field :instruction_type, 4, type: :string, json_name: "instructionType"

  field :parsed_data, 5,
    repeated: true,
    type: Solana.Instruction.ParsedDataEntry,
    json_name: "parsedData",
    map: true

  field :accounts, 6, repeated: true, type: Solana.InstructionAccount
end

defmodule Solana.InstructionAccount do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :address, 1, type: :string
  field :is_signer, 2, type: :bool, json_name: "isSigner"
  field :is_writable, 3, type: :bool, json_name: "isWritable"
  field :order_index, 4, type: :int32, json_name: "orderIndex"
end

defmodule Solana.TokenTransfer do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :from_address, 1, type: :string, json_name: "fromAddress"
  field :to_address, 2, type: :string, json_name: "toAddress"
  field :amount, 3, type: :string
  field :token_type, 4, type: :string, json_name: "tokenType"
  field :token_mint, 5, type: :string, json_name: "tokenMint"
  field :transaction_signature, 6, type: :string, json_name: "transactionSignature"
end

defmodule Solana.BlockData do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :block, 1, type: Solana.Block
  field :transactions, 2, repeated: true, type: Solana.Transaction
  field :instructions, 3, repeated: true, type: Solana.Instruction

  field :token_transfers, 4,
    repeated: true,
    type: Solana.TokenTransfer,
    json_name: "tokenTransfers"
end
