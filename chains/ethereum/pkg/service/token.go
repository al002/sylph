package service

import (
	"github.com/al002/sylph/chains/ethereum/pkg/pb"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

var (
	transferEventSig  = common.HexToHash("0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")
	transferSingleSig = common.HexToHash("0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62")
	transferBatchSig  = common.HexToHash("0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb")
)

func processTokenTransfer(log *types.Log) *pb.TokenTransfer {
	switch {
	case len(log.Topics) >= 3 && log.Topics[0] == transferEventSig:
		// ERC20/ERC721 Transfer
		return &pb.TokenTransfer{
			TokenType:       determineTokenType(log),
			FromAddress:     common.HexToAddress(log.Topics[1].Hex()).Hex(),
			ToAddress:       common.HexToAddress(log.Topics[2].Hex()).Hex(),
			Value:           getTransferValue(log),
			TokenId:         log.Address.Hex(),
			TransactionHash: log.TxHash.Hex(),
		}
	case log.Topics[0] == transferSingleSig:
		// ERC1155 TransferSingle
		return processERC1155SingleTransfer(log)
	case log.Topics[0] == transferBatchSig:
		// ERC1155 TransferBatch
		return processERC1155BatchTransfer(log)
	}
	return nil
}

func determineTokenType(log *types.Log) string {
	// Simple heuristic: if there's data, it's likely ERC20
	// If no data but 4 topics, it's likely ERC721
	if len(log.Data) > 0 {
		return "ERC20"
	}
	if len(log.Topics) == 4 {
		return "ERC721"
	}
	return "UNKNOWN"
}

func getTransferValue(log *types.Log) string {
	if len(log.Data) > 0 {
		// ERC20 value is in data
		return common.BytesToHash(log.Data).Big().String()
	}
	if len(log.Topics) == 4 {
		// ERC721 token ID is in topics[3]
		return log.Topics[3].Big().String()
	}
	return "0"
}

// Additional helper functions for ERC1155
func processERC1155SingleTransfer(log *types.Log) *pb.TokenTransfer {
	// Implementation for ERC1155 single transfer
	return nil
}

func processERC1155BatchTransfer(log *types.Log) *pb.TokenTransfer {
	// Implementation for ERC1155 batch transfer
	return nil
}
