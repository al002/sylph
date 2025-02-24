# Sylph - Blockchain Data Indexing Platform

A high-performance blockchain data indexing and processing platform supporting multiple chains including Ethereum and Solana.

## Overview

Sylph is a modular blockchain data indexing platform built with Elixir that enables:

- Real-time block and transaction syncing 
- Multi-chain support (Ethereum, Solana)
- Efficient data storage and indexing
- Configurable data processing pipelines
- Monitoring and telemetry
- Horizontal scalability

## Architecture

The platform consists of several key components:

- **Core** - Central application managing chain synchronization, data processing and storage
- **Chain Services** - Chain-specific gRPC services for Ethereum and Solana
- **Data Processors** - Configurable workers for processing blockchain data
- **Storage** - PostgreSQL database for indexed data
- **Cache** - In-memory caching layer for frequently accessed data
- **Monitoring** - Built-in monitoring and telemetry

## Getting Started

### Prerequisites

- Erlang/OTP 24 or later
- Elixir 1.18 or later 
- PostgreSQL 13 or later
- Go 1.20 or later (for chain services)

### Installation

1. Clone the repository:
```sh 
git clone https://github.com/al002/sylph.git 
cd sylph
```

2. Install dependencies:
```sh
cd apps/core
mix deps.get

cd ../..
cd chains/ethereum && go mod download
cd ../solana && cargo build
```

3. Setup database:
```sh
cd apps/core
mix ecto.setup
mix ecto.migrate
```

### Usage

Start Go GRPC server

```sh
#!/bin/bash

export SYLPH_ETH_ENV=${SYLPH_ETH_ENV:-"development"}
export SYLPH_ETH_PORT=${SYLPH_ETH_PORT:-"50051"}
export SYLPH_ETH_LOG_LEVEL=${SYLPH_ETH_LOG_LEVEL:-"info"}

if [ "$SYLPH_ETH_ENV" = "production" ]; then
  export SYLPH_ETH_HTTP_ENDPOINTS=${SYLPH_ETH_HTTP_ENDPOINTS:-"YOUR_RPC_URL"}
  export SYLPH_ETH_WS_ENDPOINTS=${SYLPH_ETH_WS_ENDPOINTS:-"YOUR_RPC_URL"}
else
  export SYLPH_ETH_HTTP_ENDPOINTS=${SYLPH_ETH_HTTP_ENDPOINTS:-"YOUR_RPC_URL"}
  export SYLPH_ETH_WS_ENDPOINTS=${SYLPH_ETH_WS_ENDPOINTS:-"YOUR_RPC_URL"}
fi

echo "Starting Sylph Ethereum Indexer"
echo "Environment:    $SYLPH_ETH_ENV"
echo "Port:           $SYLPH_ETH_PORT"
echo "HTTP Endpoints: $SYLPH_ETH_HTTP_ENDPOINTS"
echo "WS Endpoints:   $SYLPH_ETH_WS_ENDPOINTS"

exec go run cmd/main.go
```

Start exlixir client (interactive)

```
iex -S mix
```

### Disclaimer

Still in development, may have bug or crashes.
