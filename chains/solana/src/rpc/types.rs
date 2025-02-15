use serde::{Deserialize, Serialize};
use solana_sdk::commitment_config::CommitmentConfig;
use solana_transaction_status::UiTransactionStatusMeta;

#[derive(Debug, Clone)]
pub struct RpcConfig {
    pub url: String,
    pub commitment: CommitmentConfig,
    pub timeout: u64,
}

impl Default for RpcConfig {
    fn default() -> Self {
        Self {
            url: "https://api.mainnet-beta.solana.com".to_string(),
            commitment: CommitmentConfig::confirmed(),
            timeout: 30,
        }
    }
}

#[derive(Debug)]
pub struct Block {
    pub slot: u64,
    pub blockhash: String,
    pub parent_slot: u64,
    pub timestamp: i64,
    pub previous_blockhash: String,
    pub leader: String,
    pub leader_reward: Option<u64>,
    pub total_compute_units: u64,
    pub total_fee: u64,
    pub transactions: Vec<EnrichedTransaction>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EnrichedTransaction {
    pub signature: String,
    pub slot: u64,
    pub error: Option<String>,
    pub meta: Option<UiTransactionStatusMeta>,
    pub transaction: solana_sdk::transaction::Transaction,
}
