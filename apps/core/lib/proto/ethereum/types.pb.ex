defmodule Ethereum.LatestBlock do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :block_number, 1, type: :int64, json_name: "blockNumber"
  field :hash, 2, type: :string
end

defmodule Ethereum.Block do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :block_number, 1, type: :int64, json_name: "blockNumber"
  field :hash, 2, type: :string
  field :parent_hash, 3, type: :string, json_name: "parentHash"
  field :timestamp, 4, type: :int64
  field :state_root, 5, type: :string, json_name: "stateRoot"
  field :transactions_root, 6, type: :string, json_name: "transactionsRoot"
  field :receipts_root, 7, type: :string, json_name: "receiptsRoot"
  field :miner, 8, type: :string
  field :gas_used, 9, type: :int64, json_name: "gasUsed"
  field :gas_limit, 10, type: :int64, json_name: "gasLimit"
  field :base_fee_per_gas, 11, type: :string, json_name: "baseFeePerGas"
  field :difficulty, 12, type: :string
  field :total_difficulty, 13, type: :string, json_name: "totalDifficulty"
end

defmodule Ethereum.Transaction do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :hash, 1, type: :string
  field :from_address, 2, type: :string, json_name: "fromAddress"
  field :to_address, 3, type: :string, json_name: "toAddress"
  field :value, 4, type: :string
  field :gas, 5, type: :int64
  field :gas_price, 6, type: :string, json_name: "gasPrice"
  field :nonce, 7, type: :int64
  field :input, 8, type: :bytes
  field :transaction_type, 9, type: :int32, json_name: "transactionType"
  field :max_fee_per_gas, 10, type: :string, json_name: "maxFeePerGas"
  field :max_priority_fee_per_gas, 11, type: :string, json_name: "maxPriorityFeePerGas"
  field :status, 12, type: :bool
  field :transaction_category, 13, type: :string, json_name: "transactionCategory"
  field :gas_used, 14, type: :int64, json_name: "gasUsed"
  field :effective_gas_price, 15, type: :string, json_name: "effectiveGasPrice"
  field :total_fee, 16, type: :string, json_name: "totalFee"
  field :contract_address, 17, type: :string, json_name: "contractAddress"
  field :method_id, 18, type: :string, json_name: "methodId"
  field :method_name, 19, type: :string, json_name: "methodName"
end

defmodule Ethereum.Log do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :address, 1, type: :string
  field :topics, 2, repeated: true, type: :string
  field :data, 3, type: :bytes
  field :index, 4, type: :int32
  field :transaction_hash, 5, type: :string, json_name: "transactionHash"
end

defmodule Ethereum.TokenTransfer do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :from_address, 1, type: :string, json_name: "fromAddress"
  field :to_address, 2, type: :string, json_name: "toAddress"
  field :value, 3, type: :string
  field :token_type, 4, type: :string, json_name: "tokenType"
  field :token_id, 5, type: :string, json_name: "tokenId"
  field :transaction_hash, 6, type: :string, json_name: "transactionHash"
end

defmodule Ethereum.BlockData do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :block, 1, type: Ethereum.Block
  field :transactions, 2, repeated: true, type: Ethereum.Transaction
  field :logs, 3, repeated: true, type: Ethereum.Log

  field :token_transfers, 4,
    repeated: true,
    type: Ethereum.TokenTransfer,
    json_name: "tokenTransfers"
end
