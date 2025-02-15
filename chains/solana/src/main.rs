mod proto;
mod rpc;
//mod service;

pub use proto::*;

#[tokio::main]
async fn main() -> Result<(), async_nats::Error> {
    let client = async_nats::connect("127.0.0.1").await?;
    client.publish("tx.sol", "SOL data sample".into()).await?;

    client.flush().await?;
    Ok(())
}

