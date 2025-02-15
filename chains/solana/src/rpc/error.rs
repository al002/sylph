use thiserror::Error;

#[derive(Error, Debug)]
pub enum RpcError {
    #[error("Client error: {0}")]
    ClientError(#[from] solana_client::client_error::ClientError),

    #[error("Transport error: {0}")]
    TransportError(String),

    #[error("Invalid response: {0}")]
    InvalidResponse(String),

    #[error("Rate limit exceeded")]
    RateLimitExceeded,

    #[error("Block not found: {slot}")]
    BlockNotFound { slot: u64 },
}

pub type RpcResult<T> = Result<T, RpcError>;
