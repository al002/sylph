mod client;
mod error;
pub mod types;

pub use client::SolanaRpcClient;
pub use error::{RpcError, RpcResult};
pub use types::{EnrichedTransaction, RpcConfig};
