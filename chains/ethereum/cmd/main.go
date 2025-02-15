package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"strings"

	"github.com/al002/sylph/chains/ethereum/pkg/pb"
	"github.com/al002/sylph/chains/ethereum/pkg/rpc"
	"github.com/al002/sylph/chains/ethereum/pkg/service"

	// "github.com/nats-io/nats.go"
	"google.golang.org/grpc"
)

var (
	port      = flag.Int("port", 50051, "The server port")
	endpoints = flag.String("endpoints", "https://eth-mainnet.g.alchemy.com/v2/demo", "Comma-separated list of Ethereum JSON-RPC endpoints")
)

func main() {
  flag.Parse()
  client, err := rpc.NewClient(strings.Split(*endpoints, ","))
  if err != nil {
    log.Fatalf("Failed to create Ethereum rpc client: %v", err)
  }
  defer client.Close()

  // create gRPC server
  lis, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
  if err != nil {
    log.Fatalf("gRPC failed to listen on: %v", err)
  }

  grpcServer := grpc.NewServer()
  ethService := service.NewEthereumService(client)
  pb.RegisterEthereumServiceServer(grpcServer, ethService)

  log.Printf("Server listenining at %v", lis.Addr())

  if err := grpcServer.Serve(lis); err != nil {
    log.Fatalf("Failed to serve: %v", err)
  }

	// nc, _ := nats.Connect(nats.DefaultURL)
	// defer nc.Close()
	//
	// nc.Publish("tx.eth", []byte("ETH data sample"))
}
