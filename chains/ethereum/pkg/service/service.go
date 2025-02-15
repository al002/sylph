package service

import (
	"context"
	"math/big"

	"github.com/al002/sylph/chains/ethereum/pkg/pb"
	"github.com/al002/sylph/chains/ethereum/pkg/rpc"
	"github.com/ethereum/go-ethereum/core/types"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type EthereumService struct {
	pb.UnimplementedEthereumServiceServer
	client *rpc.Client
	signer types.Signer
}

func NewEthereumService(client *rpc.Client) *EthereumService {
	return &EthereumService{
		client: client,
		signer: types.NewLondonSigner(client.ChainID()),
	}
}

func (s *EthereumService) GetBlock(ctx context.Context, req *pb.GetBlockRequest) (*pb.GetBlockResponse, error) {
	blockData, err := s.fetchBlockData(ctx, big.NewInt(req.BlockNumber))

	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to fetch block: %v", err)
	}

	return &pb.GetBlockResponse{
		BlockData: blockData,
	}, nil
}

func (s *EthereumService) SubscribeNewBlocks(req *pb.SubscribeNewBlocksRequest, stream pb.EthereumService_SubscribeNewBlocksServer) error {
	ctx := stream.Context()
	headers := make(chan *types.Header)

	sub, err := s.client.CurrentClient().SubscribeNewHead(ctx, headers)
	if err != nil {
		return status.Errorf(codes.Internal, "failed to subscribe to new heads: %v", err)
	}
	defer sub.Unsubscribe()

	for {
		select {
		case err := <-sub.Err():
			return status.Errorf(codes.Internal, "subscription error: %v", err)
		case header := <-headers:
			blockData, err := s.fetchBlockData(ctx, header.Number)
			if err != nil {
				return status.Errorf(codes.Internal, "failed to fetch block data: %v", err)
			}

			if err := stream.Send(blockData); err != nil {
				return status.Errorf(codes.Internal, "failed to send block data: %v", err)
			}
		case <-ctx.Done():
			return ctx.Err()
		}
	}
}

func (s *EthereumService) GetBlockRange(req *pb.GetBlockRangeRequest, stream pb.EthereumService_GetBlockRangeServer) error {
	ctx := stream.Context()

	for blockNum := req.StartBlock; blockNum <= req.EndBlock; blockNum++ {
		blockData, err := s.fetchBlockData(ctx, big.NewInt(blockNum))
		if err != nil {
			return status.Errorf(codes.Internal, "failed to fetch block %d: %v", blockNum, err)
		}

		if err := stream.Send(blockData); err != nil {
			return status.Errorf(codes.Internal, "failed to send block data: %v", err)
		}
	}

	return nil
}

func (s *EthereumService) fetchBlockData(ctx context.Context, blockNum *big.Int) (*pb.BlockData, error) {
	client := s.client.CurrentClient()

	block, err := client.BlockByNumber(ctx, blockNum)
	if err != nil {
		return nil, err
	}

	pbBlock := &pb.Block{
		BlockNumber:      block.Number().Int64(),
		Hash:             block.Hash().Hex(),
		ParentHash:       block.ParentHash().Hex(),
		Timestamp:        int64(block.Time()),
		StateRoot:        block.Root().Hex(),
		TransactionsRoot: block.TxHash().Hex(),
		ReceiptsRoot:     block.ReceiptHash().Hex(),
		Miner:            block.Coinbase().Hex(),
		GasUsed:          int64(block.GasUsed()),
		GasLimit:         int64(block.GasLimit()),
		BaseFeePerGas:    block.BaseFee().String(),
		Difficulty:       block.Difficulty().String(),
	}

	pbTxs := make([]*pb.Transaction, 0, len(block.Transactions()))
	pbLogs := make([]*pb.Log, 0)
	pbTokenTransfers := make([]*pb.TokenTransfer, 0)

	for _, tx := range block.Transactions() {
		receipt, err := client.TransactionReceipt(ctx, tx.Hash())
		if err != nil {
			return nil, err
		}

		pbTx := &pb.Transaction{
			Hash:        tx.Hash().Hex(),
			FromAddress: s.getFromAddress(tx),
			ToAddress:   getToAddress(tx),
			Value:       tx.Value().String(),
			Gas:         int64(tx.Gas()),
			GasPrice:    tx.GasPrice().String(),
			Nonce:       int64(tx.Nonce()),
			Input:       tx.Data(),
			Status:      receipt.Status == 1,
			GasUsed:     int64(receipt.GasUsed),
		}

		// process logs
		for _, log := range receipt.Logs {
			pbLog := &pb.Log{
				Address:         log.Address.Hex(),
				Topics:          make([]string, len(log.Topics)),
				Data:            log.Data,
				Index:           int32(log.Index),
				TransactionHash: log.TxHash.Hex(),
			}

			for i, topic := range log.Topics {
				pbLog.Topics[i] = topic.Hex()
			}
			pbLogs = append(pbLogs, pbLog)

			// process token transfers
			if tokenTransfer := processTokenTransfer(log); tokenTransfer != nil {
				pbTokenTransfers = append(pbTokenTransfers, tokenTransfer)
			}
		}

		pbTxs = append(pbTxs, pbTx)
	}

	return &pb.BlockData{
		Block:          pbBlock,
		Transactions:   pbTxs,
		Logs:           pbLogs,
		TokenTransfers: pbTokenTransfers,
	}, nil
}

func (s *EthereumService) getFromAddress(tx *types.Transaction) string {
	from, err := types.Sender(s.signer, tx)
	if err != nil {
		return ""
	}
	return from.Hex()
}

func getToAddress(tx *types.Transaction) string {
	if tx.To() != nil {
		return tx.To().Hex()
	}

	return ""
}
