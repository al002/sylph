defmodule Ethereum.GetLatestBlockResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :latest_block, 1, type: Ethereum.LatestBlock, json_name: "latestBlock"
end

defmodule Ethereum.GetBlockRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :block_number, 1, type: :int64, json_name: "blockNumber"
end

defmodule Ethereum.GetBlockResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :block_data, 1, type: Ethereum.BlockData, json_name: "blockData"
end

defmodule Ethereum.SubscribeNewBlocksRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :start_block, 1, type: :int64, json_name: "startBlock"
end

defmodule Ethereum.GetBlockRangeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :start_block, 1, type: :int64, json_name: "startBlock"
  field :end_block, 2, type: :int64, json_name: "endBlock"
end

defmodule Ethereum.EthereumService.Service do
  @moduledoc false

  use GRPC.Service, name: "ethereum.EthereumService", protoc_gen_elixir_version: "0.14.0"

  rpc :GetLatestBlock, Google.Protobuf.Empty, Ethereum.GetLatestBlockResponse

  rpc :GetBlock, Ethereum.GetBlockRequest, Ethereum.GetBlockResponse

  rpc :SubscribeNewBlocks, Ethereum.SubscribeNewBlocksRequest, stream(Ethereum.BlockData)

  rpc :GetBlockRange, Ethereum.GetBlockRangeRequest, stream(Ethereum.BlockData)
end

defmodule Ethereum.EthereumService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Ethereum.EthereumService.Service
end
