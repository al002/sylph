pub mod parser;

use std::collections::HashMap;

use crate::rpc::types::Block as RpcBlock;
use crate::rpc::RpcError;
use crate::{
    proto::solana::*,
    rpc::{RpcResult, SlotUpdate, SolanaRpcClient},
};
use parser::{InstructionParser, TokenType, TransactionCategory};
use solana_transaction_status::option_serializer::OptionSerializer;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{Request, Response, Status};

pub struct SolanaService {
    client: SolanaRpcClient,
}

impl SolanaService {
    pub fn new(client: SolanaRpcClient) -> Self {
        Self { client }
    }
}

impl SolanaService {
    fn convert_error(err: crate::rpc::RpcError) -> Status {
        match err {
            RpcError::BlockNotFound { slot } => {
                Status::not_found(format!("Block not found at slot {}", slot))
            }
            RpcError::RateLimitExceeded => Status::resource_exhausted("Rate limit exceeded"),
            RpcError::InvalidResponse(msg) => Status::internal(msg),
            _ => Status::internal("Internal RPC error"),
        }
    }

    fn convert_block_data(block: RpcBlock) -> RpcResult<BlockData> {
        let pb_block = Block {
            slot: block.slot as i64,
            blockhash: block.blockhash,
            parent_slot: block.parent_slot as i64,
            timestamp: block.timestamp as i64,
            previous_blockhash: block.previous_blockhash,
            leader: block.leader,
            leader_reward: match block.leader_reward {
                Some(reward) => reward as i64,
                None => 0,
            },
            total_compute_units: block.total_compute_units as i64,
            total_fee: block.total_fee.to_string(),
        };

        let mut pb_transactions = Vec::new();
        let mut pb_instructions = Vec::new();
        let mut pb_token_transfers = Vec::new();

        for tx in block.transactions {
            let category = InstructionParser::categorize_transaction(
                &tx.transaction.message,
                &tx.transaction.message.instructions,
            );

            let transaction_category = match category {
                TransactionCategory::SystemProgram(t) => format!("System_{:?}", t),
                TransactionCategory::TokenProgram(t) => format!("Token_{:?}", t),
                TransactionCategory::DexProgram(t) => format!("Dex_{:?}", t),
                TransactionCategory::NFTProgram(t) => format!("NFT_{:?}", t),
                TransactionCategory::Unknown => "Unknown".to_string(),
            };

            let compute_units_consumed = tx
                .meta
                .as_ref()
                .and_then(|meta| match meta.compute_units_consumed {
                    OptionSerializer::Some(units) => Some(units),
                    OptionSerializer::None | OptionSerializer::Skip => None,
                })
                .unwrap_or(0) as i64;

            let write_account_count = tx
                .meta
                .as_ref()
                .map(|m| {
                    let writable_accounts = tx
                        .transaction
                        .message
                        .account_keys
                        .iter()
                        .enumerate()
                        .filter(|(idx, _)| tx.transaction.message.is_maybe_writable(*idx, None))
                        .count();

                    let created_accounts =
                        m.post_balances.len().saturating_sub(m.pre_balances.len());

                    let token_accounts = m
                        .post_token_balances
                        .as_ref()
                        .map(|balances| balances.len())
                        .unwrap_or(0);

                    (writable_accounts + created_accounts + token_accounts) as i32
                })
                .unwrap_or(0);

            let read_account_count = tx
                .transaction
                .message
                .account_keys
                .iter()
                .enumerate()
                .filter(|(idx, _)| !tx.transaction.message.is_maybe_writable(*idx, None))
                .count() as i32;

            pb_transactions.push(Transaction {
                signature: tx.signature.clone(),
                success: tx.error.is_none(),
                fee: tx
                    .meta
                    .as_ref()
                    .map_or("0".to_string(), |m| m.fee.to_string()),
                compute_units_consumed,
                transaction_category,
                program_count: tx.transaction.message.instructions.len() as i32,
                write_account_count,
                read_account_count,
            });

            // handle instructions
            for (idx, ix) in tx.transaction.message.instructions.iter().enumerate() {
                let program_id =
                    tx.transaction.message.account_keys[ix.program_id_index as usize].to_string();

                let mut accounts = Vec::new();
                for (acc_idx, &account_idx) in ix.accounts.iter().enumerate() {
                    let account_key = &tx.transaction.message.account_keys[account_idx as usize];
                    accounts.push(InstructionAccount {
                        address: account_key.to_string(),
                        is_signer: tx.transaction.message.is_signer(account_idx as usize),
                        is_writable: tx
                            .transaction
                            .message
                            .is_maybe_writable(account_idx as usize, None),
                        order_index: acc_idx as i32,
                    });
                }

                let (instruction_type, parsed_data) =
                    InstructionParser::parse_instruction(ix, &tx.transaction.message);

                let mut pb_parsed_data = HashMap::new();
                for (k, v) in parsed_data {
                    pb_parsed_data.insert(k, v);
                }

                pb_instructions.push(Instruction {
                    program_id,
                    data: ix.data.clone(),
                    order_index: idx as i32,
                    instruction_type,
                    parsed_data: pb_parsed_data,
                    accounts,
                });
            }

            for (_, ix) in tx.transaction.message.instructions.iter().enumerate() {
                if let Some(transfer_info) = InstructionParser::parse_token_transfers(
                    &tx.transaction.message,
                    ix,
                    &tx.transaction.message.account_keys,
                    tx.meta
                        .as_ref()
                        .map(|m| match &m.pre_token_balances {
                            OptionSerializer::Some(v) => v.to_vec(),
                            OptionSerializer::None | OptionSerializer::Skip => Vec::new(),
                        })
                        .as_ref(),
                    tx.meta
                        .as_ref()
                        .map(|m| match &m.post_token_balances {
                            OptionSerializer::Some(v) => v.to_vec(),
                            OptionSerializer::None | OptionSerializer::Skip => Vec::new(),
                        })
                        .as_ref(),
                ) {
                    pb_token_transfers.push(TokenTransfer {
                        from_address: transfer_info.from_address,
                        to_address: transfer_info.to_address,
                        amount: transfer_info.amount.to_string(),
                        token_type: match transfer_info.token_type {
                            TokenType::SPL => "SPL".to_string(),
                            TokenType::NFT => "NFT".to_string(),
                        },
                        token_mint: transfer_info.mint,
                        transaction_signature: tx.signature.clone(),
                    });
                }
            }
        }

        Ok(BlockData {
            block: Some(pb_block),
            transactions: pb_transactions,
            instructions: pb_instructions,
            token_transfers: pb_token_transfers,
        })
    }
}

#[tonic::async_trait]
impl solana_service_server::SolanaService for SolanaService {
    async fn get_block(
        &self,
        request: Request<GetBlockRequest>,
    ) -> Result<Response<GetBlockResponse>, Status> {
        let slot = request.into_inner().slot;

        let block = self
            .client
            .get_block(slot as u64)
            .await
            .map_err(|e| Status::internal(format!("Failed to fetch block: {}", e)))?;

        let block_data = Self::convert_block_data(block)
            .map_err(|e| Status::internal(format!("Failed to convert block data: {}", e)))?;

        Ok(Response::new(GetBlockResponse {
            block_data: Some(block_data),
        }))
    }

    type GetBlockRangeStream = ReceiverStream<Result<BlockData, Status>>;

    async fn get_block_range(
        &self,
        request: Request<GetBlockRangeRequest>,
    ) -> Result<Response<Self::GetBlockRangeStream>, Status> {
        let req = request.into_inner();
        let start_slot = req.start_slot;
        let end_slot = req.end_slot;

        if start_slot > end_slot {
            return Err(Status::invalid_argument(
                "start_slot must be less than or equal to end_slot",
            ));
        }

        const MAX_RANGE: i64 = 1000;
        if end_slot - start_slot > MAX_RANGE {
            return Err(Status::invalid_argument(format!(
                "slot range too large, maximum is {}",
                MAX_RANGE
            )));
        }

        let (tx, rx) = mpsc::channel(100);
        let client = self.client.clone();

        tokio::spawn(async move {
            match client
                .get_blocks(start_slot as u64, Some(end_slot as u64))
                .await
            {
                Ok(slots) => {
                    for slot in slots {
                        match client.get_block(slot).await {
                            Ok(block) => match Self::convert_block_data(block) {
                                Ok(block_data) => {
                                    if tx.send(Ok(block_data)).await.is_err() {
                                        break;
                                    }
                                }
                                Err(e) => {
                                    let status = Status::internal(e.to_string());
                                    if tx.send(Err(status)).await.is_err() {
                                        break;
                                    }
                                }
                            },
                            Err(e) => {
                                let status = Status::internal(e.to_string());
                                if tx.send(Err(status)).await.is_err() {
                                    break;
                                }
                            }
                        }
                    }
                }
                Err(e) => {
                    let status = Status::internal(format!("Failed to get block range: {}", e));
                    let _ = tx.send(Err(status)).await;
                }
            }
        });

        Ok(Response::new(ReceiverStream::new(rx)))
    }

    type SubscribeNewBlocksStream = ReceiverStream<Result<BlockData, Status>>;

    async fn subscribe_new_blocks(
        &self,
        request: Request<SubscribeNewBlocksRequest>,
    ) -> Result<Response<Self::SubscribeNewBlocksStream>, Status> {
        let start_slot = request.into_inner().start_slot;

        let (tx, rx) = mpsc::channel(100);
        let client = self.client.clone();

        // handle subscribe in background
        tokio::spawn(async move {
            match client.subscribe_slots().await {
                Ok(mut subscription) => {
                    while let Some(update) = subscription.rx.recv().await {
                        match update {
                            SlotUpdate::NewBlock(block) => {
                                if block.slot as i64 >= start_slot {
                                    match Self::convert_block_data(block) {
                                        Ok(block_data) => {
                                            if tx.send(Ok(block_data)).await.is_err() {
                                                break;
                                            }
                                        }
                                        Err(e) => {
                                            let status = Status::internal(e.to_string());
                                            if tx.send(Err(status)).await.is_err() {
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                            SlotUpdate::Error(e) => {
                                let status = Status::internal(e.to_string());
                                if tx.send(Err(status)).await.is_err() {
                                    break;
                                }
                            }
                            _ => continue,
                        }
                    }
                }
                Err(e) => {
                    let status = Status::internal(format!("Failed to subscribe: {}", e));
                    let _ = tx.send(Err(status)).await;
                }
            }
        });

        Ok(Response::new(ReceiverStream::new(rx)))
    }
}
