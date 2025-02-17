package rpc

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"sync/atomic"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
)

const (
	healthCheckInterval = 30 * time.Second
	dialTimeout         = 5 * time.Second
	maxRetries          = 3
)

type HealthyClient struct {
	client       *ethclient.Client
	endpoint     string
	isHealthy    atomic.Bool
	lastCheck    atomic.Int64 // Unix timestamp
	latency      atomic.Int64 // in milliseconds
	failureCount atomic.Int32
	successCount atomic.Int32
}

type Client struct {
	httpEndpoints []string
	httpClients   []*HealthyClient
	current       atomic.Int32

	wsEndpoints []string
	wsClients   []*HealthyClient
	wsCurrent   atomic.Int32

	mu     sync.RWMutex
	closed atomic.Bool
}

func NewClient(httpEndpoints, wsEndpoints []string) (*Client, error) {
	c := &Client{
		httpEndpoints: httpEndpoints,
		wsEndpoints:   wsEndpoints,
	}

	const dialTimeout = 5 * time.Second
	for _, endpoint := range httpEndpoints {
		client, err := dialWithTimeout(endpoint)
		if err != nil {
			return nil, fmt.Errorf("failed to dial HTTP endpoint %s: %v", endpoint, err)
		}
		c.httpClients = append(c.httpClients, &HealthyClient{
			client:   client,
			endpoint: endpoint,
		})
	}

	for _, endpoint := range wsEndpoints {
		client, err := dialWithTimeout(endpoint)
		if err != nil {
			return nil, fmt.Errorf("failed to dial WS endpoint %s: %v", endpoint, err)
		}

		c.wsClients = append(c.wsClients, &HealthyClient{
			client:   client,
			endpoint: endpoint,
		})
	}

	if len(c.httpClients) == 0 {
		return nil, fmt.Errorf("no valid HTTP endpoints provided")
	}

	go c.startHealthChecks()

	return c, nil
}

func dialWithTimeout(endpoint string) (*ethclient.Client, error) {
	ctx, cancel := context.WithTimeout(context.Background(), dialTimeout)
	defer cancel()
	return ethclient.DialContext(ctx, endpoint)
}

func (c *Client) startHealthChecks() {
	ticker := time.NewTicker(healthCheckInterval)
	defer ticker.Stop()

	for range ticker.C {
		if c.closed.Load() {
			return
		}

		c.checkClientsHealth(c.httpClients)
		c.checkClientsHealth(c.wsClients)
	}
}

func (c *Client) checkClientsHealth(clients []*HealthyClient) {
	var wg sync.WaitGroup
	for _, hc := range clients {
		wg.Add(1)
		go func(hc *HealthyClient) {
			defer wg.Done()

			if failures := hc.failureCount.Load(); failures > 0 {
				backoff := time.Duration(1<<uint(failures)) * time.Second
				if backoff > 30*time.Second {
					backoff = 30 * time.Second
				}
				time.Sleep(backoff)
			}

			ctx, cancel := context.WithTimeout(context.Background(), dialTimeout)
			defer cancel()

			start := time.Now()
			_, err := hc.client.ChainID(ctx)
			latency := time.Since(start).Milliseconds()

			if err == nil {
				hc.isHealthy.Store(true)
				hc.successCount.Add(1)
				hc.failureCount.Store(0)
			} else {
				hc.isHealthy.Store(false)
				hc.failureCount.Add(1)
			}

			hc.lastCheck.Store(time.Now().Unix())
			hc.latency.Store(latency)
		}(hc)
	}
	wg.Wait()
}

func (c *Client) CurrentClient() (*ethclient.Client, error) {
	return c.getHealthyClient(c.httpClients, &c.current)
}

func (c *Client) NextClient() {
	c.current.Add(1)
}

func (c *Client) Close() {
	c.closed.Store(true)

	for _, hc := range append(c.httpClients, c.wsClients...) {
		if hc.client != nil {
			hc.client.Close()
		}
	}
}

func (c *Client) WSClient() (*ethclient.Client, error) {
	return c.getHealthyClient(c.wsClients, &c.wsCurrent)
}

func (c *Client) getHealthyClient(clients []*HealthyClient, current *atomic.Int32) (*ethclient.Client, error) {
	candidates := make([]int, 0, len(clients))
	for i, hc := range clients {
		if hc.isHealthy.Load() {
			candidates = append(candidates, i)
		}
	}

	if len(candidates) == 0 {
		return nil, fmt.Errorf("no healthy clients available")
	}

	cur := int(current.Add(0))

	for offset := 0; offset < len(candidates); offset++ {
		idx := (cur + offset) % len(clients)
		if hc := clients[idx]; hc.isHealthy.Load() {
			current.Store(int32(idx))
			return hc.client, nil
		}
	}

	return clients[candidates[0]].client, nil
}

func (c *Client) NextWSClient() {
	c.wsCurrent.Add(1)
}

func (c *Client) ChainID() (*big.Int, error) {
	if err := c.initializeClients(); err != nil {
		return nil, fmt.Errorf("failed to initialize clients: %w", err)
	}

	var lastErr error

	for i := 0; i < len(c.httpClients); i++ {
		client := c.httpClients[i].client
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		chainID, err := client.ChainID(ctx)
		if err == nil {
			return chainID, nil
		}
		lastErr = err
	}

	return nil, fmt.Errorf("failed to get chain ID from any client: %w", lastErr)

}

func (c *Client) initializeClients() error {
	if len(c.httpClients) > 0 && c.httpClients[0].isHealthy.Load() {
		return nil
	}

	c.checkClientsHealth(c.httpClients)

	for _, client := range c.httpClients {
		if client.isHealthy.Load() {
			return nil
		}
	}

	return fmt.Errorf("no healthy clients available after initialization")
}

func (c *Client) HealthStatus() map[string]interface{} {
	c.mu.RLock()
	defer c.mu.RUnlock()

	status := make(map[string]interface{})

	httpStatus := make([]map[string]interface{}, len(c.httpClients))
	for i, hc := range c.httpClients {
		httpStatus[i] = map[string]interface{}{
			"endpoint":  hc.endpoint,
			"healthy":   hc.isHealthy.Load(),
			"lastCheck": time.Unix(hc.lastCheck.Load(), 0),
			"latency":   hc.latency.Load(),
		}
	}

	wsStatus := make([]map[string]interface{}, len(c.wsClients))
	for i, hc := range c.wsClients {
		wsStatus[i] = map[string]interface{}{
			"endpoint":  hc.endpoint,
			"healthy":   hc.isHealthy.Load(),
			"lastCheck": time.Unix(hc.lastCheck.Load(), 0),
			"latency":   hc.latency.Load(),
		}
	}

	status["http"] = httpStatus
	status["ws"] = wsStatus
	return status
}
