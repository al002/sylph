package pb

import (
	pb "github.com/al002/sylph/chains/ethereum/proto/ethereum"
)

// Service interfaces
type (
	EthereumServiceServer = pb.EthereumServiceServer
	EthereumServiceClient = pb.EthereumServiceClient
)

// Message types
type (
	Block         = pb.Block
	Transaction   = pb.Transaction
	Log           = pb.Log
	TokenTransfer = pb.TokenTransfer
	BlockData     = pb.BlockData
)

// Request/Response types
type (
	GetBlockRequest           = pb.GetBlockRequest
	GetBlockResponse          = pb.GetBlockResponse
	SubscribeNewBlocksRequest = pb.SubscribeNewBlocksRequest
	GetBlockRangeRequest      = pb.GetBlockRangeRequest
)

// Service methods
var (
	RegisterEthereumServiceServer = pb.RegisterEthereumServiceServer
)

// Stream types
type (
	EthereumService_SubscribeNewBlocksServer = pb.EthereumService_SubscribeNewBlocksServer
	EthereumService_GetBlockRangeServer      = pb.EthereumService_GetBlockRangeServer
)

type (
	UnimplementedEthereumServiceServer = pb.UnimplementedEthereumServiceServer
)
