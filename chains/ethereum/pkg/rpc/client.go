package rpc

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
)

type Client struct {
	httpEndpoints []string
	httpClients   []*ethclient.Client
	current       int

	wsEndpoints []string
	wsClients   []*ethclient.Client

	wsCurrent int
	mu        sync.RWMutex
}

func NewClient(httpEndpoints, wsEndpoints []string) (*Client, error) {
	c := &Client{
		httpEndpoints: httpEndpoints,
		wsEndpoints:   wsEndpoints,
	}

	const dialTimeout = 5 * time.Second
	for _, endpoint := range httpEndpoints {
		ctx, cancel := context.WithTimeout(context.Background(), dialTimeout)
		defer cancel()

		client, err := ethclient.DialContext(ctx, endpoint)
		if err != nil {
			return nil, err
		}
		c.httpClients = append(c.httpClients, client)
	}

	for _, endpoint := range wsEndpoints {
		client, err := ethclient.Dial(endpoint)
		if err != nil {
			return nil, err
		}
		c.wsClients = append(c.wsClients, client)
	}

	if len(c.httpClients) == 0 {
		return nil, fmt.Errorf("no valid HTTP endpoints provided")
	}

	return c, nil
}

func (c *Client) CurrentClient() *ethclient.Client {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.httpClients[c.current]
}

func (c *Client) NextClient() *ethclient.Client {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.current = (c.current + 1) % len(c.httpClients)
	return c.httpClients[c.current]
}

func (c *Client) Close() {
	for _, client := range c.httpClients {
		client.Close()
	}
}

func (c *Client) WSClient() *ethclient.Client {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if len(c.wsClients) == 0 {
		return nil
	}
	return c.wsClients[c.wsCurrent]
}

func (c *Client) NextWSClient() *ethclient.Client {
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.wsClients) == 0 {
		return nil
	}
	c.wsCurrent = (c.wsCurrent + 1) % len(c.wsClients)
	return c.wsClients[c.wsCurrent]
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
