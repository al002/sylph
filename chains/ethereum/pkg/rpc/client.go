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
	client    *ethclient.Client
	endpoint  string
	isHealthy atomic.Bool
	lastCheck atomic.Int64 // Unix timestamp
	latency   atomic.Int64 // in milliseconds
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
			ctx, cancel := context.WithTimeout(context.Background(), dialTimeout)
			defer cancel()

			start := time.Now()
			_, err := hc.client.ChainID(ctx)
			latency := time.Since(start).Milliseconds()

			hc.isHealthy.Store(err == nil)
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
	if len(clients) == 0 {
		return nil, fmt.Errorf("no clients available")
	}

	var retries int
	for retries < maxRetries {
		idx := int(current.Load() % int32(len(clients)))
		hc := clients[idx]

		if hc.isHealthy.Load() {
			return hc.client, nil
		}

		// go next client
		current.Add(1)
		retries++
	}

	return nil, fmt.Errorf("no healthy clients available after %d retries", maxRetries)
}

func (c *Client) NextWSClient() {
	c.wsCurrent.Add(1)
}

func (c *Client) ChainID() (*big.Int, error) {
	client, err := c.CurrentClient()
	if err != nil {
		return nil, fmt.Errorf("failed to get client: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	chainID, err := client.ChainID(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get chain ID: %w", err)
	}

	return chainID, nil
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
