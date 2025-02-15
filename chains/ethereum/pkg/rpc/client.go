package rpc

import (
	"context"
	"errors"
	"math/big"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
)

type Client struct {
	endpoints []string
	clients   []*ethclient.Client
	mu        sync.RWMutex
	current   int
}

func NewClient(endpoints []string) (*Client, error) {
  if len(endpoints) == 0 {
    return nil, errors.New("no endpoints provided")
  }

  clients := make([]*ethclient.Client, len(endpoints))

  for i, endpoint := range endpoints {
    client, err := ethclient.Dial(endpoint)
    if err != nil {
      return nil, err
    }

    clients[i] = client
  }

  return &Client{
    endpoints: endpoints,
    clients: clients,
  }, nil
}

func (c *Client) CurrentClient() *ethclient.Client {
  c.mu.RLock()
  defer c.mu.RUnlock()
  return c.clients[c.current]
}

func (c *Client) NextClient() *ethclient.Client {
  c.mu.Lock()
  defer c.mu.Unlock()
  c.current = (c.current + 1) % len(c.clients)
  return c.clients[c.current]
}

func (c *Client) Close() {
  for _, client := range c.clients {
    client.Close()
  }
}

func (c *Client) ChainID() *big.Int {
  client := c.CurrentClient()
  ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
  defer cancel()

  chainID, err := client.ChainID(ctx)
  if err != nil {
    // ethereum mainnet chain id
    return big.NewInt(1)
  }

  return chainID
}
