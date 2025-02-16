defmodule Solana.GetBlockRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :slot, 1, type: :int64
end

defmodule Solana.GetBlockResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :block_data, 1, type: Solana.BlockData, json_name: "blockData"
end

defmodule Solana.SubscribeNewBlocksRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :start_slot, 1, type: :int64, json_name: "startSlot"
end

defmodule Solana.GetBlockRangeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :start_slot, 1, type: :int64, json_name: "startSlot"
  field :end_slot, 2, type: :int64, json_name: "endSlot"
end

defmodule Solana.SolanaService.Service do
  @moduledoc false

  use GRPC.Service, name: "solana.SolanaService", protoc_gen_elixir_version: "0.14.0"

  rpc :GetBlock, Solana.GetBlockRequest, Solana.GetBlockResponse

  rpc :SubscribeNewBlocks, Solana.SubscribeNewBlocksRequest, stream(Solana.BlockData)

  rpc :GetBlockRange, Solana.GetBlockRangeRequest, stream(Solana.BlockData)
end

defmodule Solana.SolanaService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Solana.SolanaService.Service
end
