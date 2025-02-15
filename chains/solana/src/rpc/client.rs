use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use std::{
    collections::HashSet,
    sync::{Arc, RwLock},
    time::Duration,
};
use tokio::{sync::{mpsc, oneshot, Mutex}, time::sleep};
use tokio_stream::StreamExt;

use solana_client::{
    nonblocking::{pubsub_client::PubsubClient, rpc_client::RpcClient},
    rpc_config::RpcBlockConfig,
    rpc_response::SlotInfo,
};
use solana_sdk::clock::Slot;
use solana_transaction_status::{EncodedTransaction, EncodedTransactionWithStatusMeta};

use super::{
    error::{RpcError, RpcResult},
    types::{Block, EnrichedTransaction, RpcConfig},
};

#[derive(Clone)]
pub struct MultiClient {
    endpoints: Vec<String>,
    clients: Vec<Arc<RpcClient>>,
    current: Arc<RwLock<usize>>,
    config: RpcConfig,
}

impl MultiClient {
    pub fn new(endpoints: Vec<String>, config: RpcConfig) -> RpcResult<Self> {
        if endpoints.is_empty() {
            return Err(RpcError::InvalidResponse(
                "no rpc endpoints provided".to_string(),
            ));
        }

        let mut clients = Vec::with_capacity(endpoints.len());

        for endpoint in &endpoints {
            let client = Arc::new(RpcClient::new_with_timeout_and_commitment(
                endpoint.clone(),
                Duration::from_secs(config.timeout),
                config.commitment,
            ));
            clients.push(client);
        }

        Ok(Self {
            endpoints,
            clients,
            current: Arc::new(RwLock::new(0)),
            config,
        })
    }

    pub fn default_block_config(&self) -> RpcBlockConfig {
        RpcBlockConfig {
            encoding: Some(solana_transaction_status::UiTransactionEncoding::Base64),
            transaction_details: Some(solana_transaction_status::TransactionDetails::Full),
            rewards: Some(true),
            commitment: Some(self.config.commitment),
            max_supported_transaction_version: Some(0),
        }
    }

    pub fn current_client(&self) -> RpcResult<Arc<RpcClient>> {
        let current = self.current.read().map_err(|e| {
            RpcError::InvalidResponse(format!("Failed to acquire read lock: {}", e))
        })?;
        Ok(self.clients[*current].clone())
    }

    pub fn next_client(&self) -> RpcResult<Arc<RpcClient>> {
        let mut current = self.current.write().map_err(|e| {
            RpcError::InvalidResponse(format!("Failed to acquire write lock: {}", e))
        })?;
        *current = (*current + 1) % self.clients.len();
        Ok(self.clients[*current].clone())
    }

    pub fn endpoints(&self) -> &[String] {
        &self.endpoints
    }

    pub fn config(&self) -> &RpcConfig {
        &self.config
    }

    async fn execute_with_failover<F, Fut, T>(&self, operation: F) -> RpcResult<T>
    where
        F: Fn(Arc<RpcClient>) -> Fut,
        Fut: std::future::Future<Output = RpcResult<T>>,
    {
        let mut attempts = 0;
        let max_attempts = self.clients.len();

        loop {
            let client = if attempts == 0 {
                self.current_client()?
            } else {
                self.next_client()?
            };

            match operation(client).await {
                Ok(result) => return Ok(result),
                Err(e) => {
                    attempts += 1;
                    if attempts >= max_attempts {
                        return Err(e);
                    }
                    // println!("RPC call failed, trying next endpoint. Error: {}", e);
                }
            }
        }
    }
}

impl Drop for MultiClient {
    fn drop(&mut self) {}
}

#[derive(Debug)]
pub enum SlotUpdate {
    NewSlot(SlotInfo),
    NewBlock(Block),
    Error(RpcError),
}

pub struct Subscription {
    id: String,
    rx: mpsc::Receiver<SlotUpdate>,
    cancel: Option<oneshot::Sender<()>>,
}

impl Drop for Subscription {
    fn drop(&mut self) {
        if let Some(cancel) = self.cancel.take() {
            let _ = cancel.send(());
        }
    }
}

#[derive(Clone)]
pub struct SolanaRpcClient {
    client: MultiClient,
    ws_endpoints: Vec<String>,
    active_subscriptions: Arc<Mutex<HashSet<String>>>,
}

impl SolanaRpcClient {
    pub fn new(
        rpc_endpoints: Vec<String>,
        ws_endpoints: Vec<String>,
        config: RpcConfig,
    ) -> RpcResult<Self> {
        Ok(Self {
            client: MultiClient::new(rpc_endpoints, config)?,
            ws_endpoints,
            active_subscriptions: Arc::new(Mutex::new(HashSet::new())),
        })
    }

    pub async fn get_block(&self, slot: Slot) -> RpcResult<Block> {
        let block = self
            .client
            .execute_with_failover(|client| async move {
                client
                    .get_block_with_config(slot, self.client.default_block_config())
                    .await
                    .map_err(|e| match e.kind() {
                        solana_client::client_error::ClientErrorKind::RpcError(
                            solana_client::rpc_request::RpcError::ForUser(msg),
                        ) if msg.contains("Block not available") => {
                            RpcError::BlockNotFound { slot }
                        }
                        _ => RpcError::ClientError(e),
                    })
            })
            .await?;

        let timestamp = self.get_block_time(slot).await?;

        let transactions = convert_transactions(slot, block.transactions)?;

        Ok(Block {
            slot,
            blockhash: block.blockhash,
            parent_slot: block.parent_slot,
            timestamp,
            transactions,
        })
    }

    pub async fn get_latest_slot(&self) -> RpcResult<Slot> {
        self.client
            .execute_with_failover(|client| async move {
                client
                    .get_slot_with_commitment(self.client.config().commitment)
                    .await
                    .map_err(RpcError::ClientError)
            })
            .await
    }

    pub async fn get_block_time(&self, slot: Slot) -> RpcResult<i64> {
        self.client
            .execute_with_failover(|client| async move {
                client
                    .get_block_time(slot)
                    .await
                    .map_err(|e| match e.kind() {
                        solana_client::client_error::ClientErrorKind::RpcError(
                            solana_client::rpc_request::RpcError::ForUser(msg),
                        ) if msg.contains("Block not available") => {
                            RpcError::BlockNotFound { slot }
                        }
                        _ => RpcError::ClientError(e),
                    })
            })
            .await
    }

    pub async fn get_blocks(
        &self,
        start_slot: Slot,
        end_slot: Option<Slot>,
    ) -> RpcResult<Vec<Slot>> {
        let end_slot = end_slot.unwrap_or_else(|| start_slot + 1000);

        self.client
            .execute_with_failover(|client| async move {
                client
                    .get_blocks_with_commitment(
                        start_slot,
                        Some(end_slot),
                        self.client.config().commitment,
                    )
                    .await
                    .map_err(RpcError::ClientError)
            })
            .await
    }

    pub async fn subscribe_slots(&self) -> RpcResult<Subscription> {
        let (update_tx, update_rx) = mpsc::channel(100);
        let (shutdown_tx, shutdown_rx) = oneshot::channel();

        let subscription_id = format!("slot-{}", uuid::Uuid::new_v4());
        let ws_endpoints = self.ws_endpoints.clone();
        let client = self.clone();
        let active_subscriptions = Arc::clone(&self.active_subscriptions);

        {
            let mut subs = active_subscriptions.lock().await;
            subs.insert(subscription_id.clone());
        }

        let cloned_subscription_id = subscription_id.clone();

        tokio::spawn(async move {
            Self::run_slot_subscription(
                client,
                ws_endpoints,
                update_tx,
                shutdown_rx,
                cloned_subscription_id,
                active_subscriptions,
            )
            .await;
        });

        Ok(Subscription {
            id: subscription_id,
            rx: update_rx,
            cancel: Some(shutdown_tx),
        })
    }

    async fn run_slot_subscription(
        client: SolanaRpcClient,
        ws_endpoints: Vec<String>,
        update_tx: mpsc::Sender<SlotUpdate>,
        mut shutdown_rx: oneshot::Receiver<()>,
        subscription_id: String,
        active_subscriptions: Arc<Mutex<HashSet<String>>>,
    ) {
        let cleanup = async {
            let mut subs = active_subscriptions.lock().await;
            subs.remove(&subscription_id);
        };

        let mut current_endpoint = 0;
        let mut reconnect_delay = Duration::from_secs(1);

        loop {
            let endpoint = &ws_endpoints[current_endpoint];

            let pubsub = match PubsubClient::new(endpoint).await {
                Ok(client) => client,
                Err(err) => {
                    if update_tx
                        .send(SlotUpdate::Error(RpcError::InvalidResponse(format!(
                            "Failed to connect to WebSocket: {}",
                            err
                        ))))
                        .await
                        .is_err()
                    {
                        return;
                    }
                    Self::handle_reconnect(
                        &mut current_endpoint,
                        &ws_endpoints,
                        &mut reconnect_delay,
                    )
                    .await;
                    continue;
                }
            };

            // subscribe slot update
            let (mut slot_notifications, slot_unsubscribe) = match pubsub.slot_subscribe().await {
                Ok(sub) => sub,
                Err(err) => {
                    if update_tx
                        .send(SlotUpdate::Error(RpcError::InvalidResponse(format!(
                            "Failed to subscribe: {}",
                            err
                        ))))
                        .await
                        .is_err()
                    {
                        cleanup.await;
                        return;
                    }
                    Self::handle_reconnect(
                        &mut current_endpoint,
                        &ws_endpoints,
                        &mut reconnect_delay,
                    )
                    .await;
                    continue;
                }
            };

            // reset reconnect delay
            reconnect_delay = Duration::from_secs(1);

            loop {
                tokio::select! {
                    // handle shutdown signal
                    _ = &mut shutdown_rx => {
                        slot_unsubscribe().await;
                        cleanup.await;
                        return;
                    }
                    // handle slot received
                    maybe_slot_info = slot_notifications.next() => {
                        match maybe_slot_info {
                            Some(slot_info) => {
                                //if update_tx.send(SlotUpdate::NewSlot(slot_info.clone())).await.is_err() {
                                //    return;
                                //}
                                let _ = update_tx.send(SlotUpdate::NewSlot(slot_info.clone())).await;

                                // if is root slot, get block
                                if slot_info.root == slot_info.slot {
                                    match client.get_block(slot_info.slot).await {
                                        Ok(block) => {
                                            let _ = update_tx.send(SlotUpdate::NewBlock(block)).await;
                                            //if update_tx.send(SlotUpdate::NewBlock(block)).await.is_err() {
                                            //    return;
                                            //}
                                        }
                                        Err(err) => {
                                            let _ = update_tx.send(SlotUpdate::Error(err)).await;
                                            //if update_tx.send(SlotUpdate::Error(err)).await.is_err() {
                                            //    return;
                                            //}
                                        }
                                    }
                                }
                            }
                            None => {
                                // stream end, need reconnect
                                break;
                            }
                        }
                    }
                }
            }

            Self::handle_reconnect(&mut current_endpoint, &ws_endpoints, &mut reconnect_delay)
                .await;
        }
    }

    async fn handle_reconnect(
        current_endpoint: &mut usize,
        endpoints: &[String],
        reconnect_delay: &mut Duration,
    ) {
        *current_endpoint = (*current_endpoint + 1) % endpoints.len();
        
        let next_delay = reconnect_delay.as_secs() * 2;
        *reconnect_delay = Duration::from_secs(
            if next_delay > 60 { 60 } else { next_delay }
        );

        sleep(*reconnect_delay).await;
    }

    pub async fn unsubscribe_all(&self) {
        let mut subs = self.active_subscriptions.lock().await;
        subs.clear();
    }
}

impl Drop for SolanaRpcClient {
    fn drop(&mut self) {
        if let Ok(rt) = tokio::runtime::Handle::try_current() {
            rt.block_on(async {
                self.unsubscribe_all().await;
            });
        }
    }
}

fn convert_transactions(
    slot: Slot,
    transactions: Option<Vec<EncodedTransactionWithStatusMeta>>,
) -> RpcResult<Vec<EnrichedTransaction>> {
    let mut enriched_transactions = Vec::new();

    let transactions = match transactions {
        Some(txs) => txs,
        None => return Ok(Vec::new()),
    };

    for tx_with_meta in transactions {
        let (signature, transaction) = match tx_with_meta.transaction {
            EncodedTransaction::Binary(ref data, _) => {
                let decoded = BASE64.decode(data).map_err(|e| {
                    RpcError::InvalidResponse(format!("Failed to decode base64: {}", e))
                })?;

                let transaction: solana_sdk::transaction::Transaction =
                    bincode::deserialize(&decoded).map_err(|e| {
                        RpcError::InvalidResponse(format!(
                            "Failed to deserialize transaction: {}",
                            e
                        ))
                    })?;

                let signature = transaction
                    .signatures
                    .first()
                    .ok_or_else(|| {
                        RpcError::InvalidResponse("No signature found in transaction".to_string())
                    })?
                    .to_string();

                (signature, transaction)
            }
            EncodedTransaction::Json(ref _ui_transaction) => {
                return Err(RpcError::InvalidResponse(
                    "JSON transaction format not supported".to_string(),
                ));
            }
            _ => {
                return Err(RpcError::InvalidResponse(
                    "Unsupported transaction encoding".to_string(),
                ))
            }
        };

        let enriched_tx = EnrichedTransaction {
            signature,
            slot,
            error: tx_with_meta
                .meta
                .as_ref()
                .and_then(|meta| meta.err.as_ref().map(|e| e.to_string())),
            meta: tx_with_meta.meta,
            transaction,
        };

        enriched_transactions.push(enriched_tx);
    }

    Ok(enriched_transactions)
}
