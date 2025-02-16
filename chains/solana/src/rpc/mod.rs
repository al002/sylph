mod client;
mod error;
pub mod types;

pub use client::{SolanaRpcClient, SlotUpdate};
pub use error::{RpcError, RpcResult};
pub use types::{EnrichedTransaction, RpcConfig};
