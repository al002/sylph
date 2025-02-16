package service

import (
	"context"
	"fmt"
	"math/big"
	"sync"

	"github.com/al002/sylph/chains/ethereum/pkg/pb"
	"github.com/al002/sylph/chains/ethereum/pkg/rpc"
	"github.com/ethereum/go-ethereum/common"
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

	wsClient, err := s.client.WSClient()
	if err != nil {
		return err
	}

	if wsClient == nil {
		return status.Error(codes.Unavailable, "no WebSocket endpoints available")
	}

	sub, err := wsClient.SubscribeNewHead(ctx, headers)
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
	sem := make(chan struct{}, 10)
	var wg sync.WaitGroup
	var errCh = make(chan error, 1)

	for blockNum := req.StartBlock; blockNum <= req.EndBlock; blockNum++ {
		sem <- struct{}{}
		wg.Add(1)

		go func(num int64) {
			defer func() { <-sem; wg.Done() }()

			blockData, err := s.fetchBlockData(stream.Context(), big.NewInt(num))
			if err != nil {
				select {
				case errCh <- err:
				default:
				}
				return
			}

			if err := stream.Send(blockData); err != nil {
				select {
				case errCh <- err:
				default:
				}
			}
		}(blockNum)
	}

	wg.Wait()
	close(sem)

	select {
	case err := <-errCh:
		return status.Error(codes.Internal, err.Error())
	default:
		return nil
	}
}

func (s *EthereumService) fetchBlockData(ctx context.Context, blockNum *big.Int) (*pb.BlockData, error) {
	client, err := s.client.CurrentClient()
	if err != nil {
		return nil, err
	}

	block, err := client.BlockByNumber(ctx, blockNum)
	if err != nil {
		return nil, err
	}

	receipts, err := s.getBlockReceipts(ctx, block.Hash())
	if err != nil {
		return nil, fmt.Errorf("failed to get block receipts: %v", err)
	}

	if len(receipts) != len(block.Transactions()) {
		return nil, fmt.Errorf("receipts count mismatch")
	}

	pbBlock := convertBlockToPB(block)

	var (
		pbTxs            []*pb.Transaction
		pbLogs           []*pb.Log
		pbTokenTransfers []*pb.TokenTransfer
	)

	for i, tx := range block.Transactions() {
		receipt := receipts[i]
		pbTx := convertTransactionToPB(tx, receipt, s.signer)
		pbTxs = append(pbTxs, pbTx)

		logs, tokenTransfers := processLogs(receipt.Logs)
		pbLogs = append(pbLogs, logs...)
		pbTokenTransfers = append(pbTokenTransfers, tokenTransfers...)
	}

	return &pb.BlockData{
		Block:          pbBlock,
		Transactions:   pbTxs,
		Logs:           pbLogs,
		TokenTransfers: pbTokenTransfers,
	}, nil
}

func (s *EthereumService) getBlockReceipts(ctx context.Context, blockHash common.Hash) ([]*types.Receipt, error) {
	var receipts []*types.Receipt
	client, err := s.client.CurrentClient()

	if err != nil {
		return nil, err
	}

	client.Client().CallContext(
		ctx,
		&receipts,
		"eth_getBlockReceipts",
		blockHash.Hex(),
	)

	if err != nil {
		return nil, err
	}

	return receipts, nil
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

func convertBlockToPB(block *types.Block) *pb.Block {
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

	return pbBlock
}

func convertTransactionToPB(tx *types.Transaction, receipt *types.Receipt, signer types.Signer) *pb.Transaction {
	from, _ := types.Sender(signer, tx)
	to := ""
	if tx.To() != nil {
		to = tx.To().Hex()
	}

	return &pb.Transaction{
		Hash:        tx.Hash().Hex(),
		FromAddress: from.Hex(),
		ToAddress:   to,
		Value:       tx.Value().String(),
		Gas:         int64(tx.Gas()),
		GasPrice:    tx.GasPrice().String(),
		Nonce:       int64(tx.Nonce()),
		Input:       tx.Data(),
		Status:      receipt.Status == types.ReceiptStatusSuccessful,
		GasUsed:     int64(receipt.GasUsed),
	}
}

func processLogs(logs []*types.Log) ([]*pb.Log, []*pb.TokenTransfer) {
	var pbLogs []*pb.Log
	var transfers []*pb.TokenTransfer

	for _, log := range logs {
		pbLog := convertLogToPB(log)
		pbLogs = append(pbLogs, pbLog)

		if transfer := processTokenTransfer(log); transfer != nil {
			transfers = append(transfers, transfer)
		}
	}
	return pbLogs, transfers
}

func convertLogToPB(log *types.Log) *pb.Log {
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

	return pbLog
}
