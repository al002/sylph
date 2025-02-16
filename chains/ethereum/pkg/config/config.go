package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

const (
	envPrefix       = "SYLPH_ETH_"
	DefaultEnv      = "development"
	DefaultPort     = 50051
	DefaultLogLevel = "info"
)

const (
	DefaultHealthCheckInterval = 30 // seconds
)

type Config struct {
	Env                 string
	GRPCServerPort      int
	LogLevel            string
	HTTPEndpoints       []string
	WSEndpoints         []string
	HealthCheckInterval int
}

func Load() *Config {
	return &Config{
		Env:                 getEnv(envPrefix+"ENV", DefaultEnv),
		GRPCServerPort:      getEnvInt(envPrefix+"PORT", DefaultPort),
		LogLevel:            getEnv(envPrefix+"LOG_LEVEL", DefaultLogLevel),
		HTTPEndpoints:       parseEndpoints(getEnv(envPrefix+"HTTP_ENDPOINTS", defaultEndpoints("http"))),
		WSEndpoints:         parseEndpoints(getEnv(envPrefix+"WS_ENDPOINTS", defaultEndpoints("ws"))),
		HealthCheckInterval: getEnvInt(envPrefix+"HEALTH_CHECK_INTERVAL", DefaultHealthCheckInterval),
	}
}

func (c *Config) Validate() error {
	return validateEndpoints(c.HTTPEndpoints)
}

func validateEndpoints(endpoints []string) error {
	if len(endpoints) == 0 {
		return errors.New("At least one endpoint")
	}
	for _, ep := range endpoints {
		if !strings.HasPrefix(ep, "http://") && !strings.HasPrefix(ep, "https://") {
			return fmt.Errorf("Invalid endpoint protocol: %s", ep)
		}
	}
	return nil
}

func getEnv(key, defaultValue string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}

	return defaultValue
}

func defaultEndpoints(netType string) string {
	if os.Getenv(envPrefix+"ENV") == "production" {
		if netType == "http" {
			return "https://eth-mainnet.g.alchemy.com/v2/"
		}
		return "wss://eth-mainnet.g.alchemy.com/v2/"
	}
	return netType + "://localhost:8545"
}

func getEnvInt(key string, defaultValue int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return defaultValue
}

func parseEndpoints(input string) []string {
	if input == "" {
		return []string{}
	}

	endpoints := strings.Split(input, ",")
	result := make([]string, 0, len(endpoints))
	for _, ep := range endpoints {
		if trimmed := strings.TrimSpace(ep); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}
