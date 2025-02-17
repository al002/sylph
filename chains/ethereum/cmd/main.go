package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/al002/sylph/chains/ethereum/pkg/config"
	"github.com/al002/sylph/chains/ethereum/pkg/pb"
	"github.com/al002/sylph/chains/ethereum/pkg/rpc"
	"github.com/al002/sylph/chains/ethereum/pkg/service"

	// "github.com/nats-io/nats.go"
	"google.golang.org/grpc"
)

func main() {
	portOverride := flag.Int("port", 50051, "Override server port (default from env)")
	flag.Parse()

	cfg := config.Load()

	err := cfg.Validate()

	if err := cfg.Validate(); err != nil {
		log.Fatalf("Invalid config: %v", err)
	}

	if *portOverride > 0 {
		cfg.GRPCServerPort = *portOverride
	}

	client, err := rpc.NewClient(
		cfg.HTTPEndpoints,
		cfg.WSEndpoints,
	)
	if err != nil {
		log.Fatalf("Failed to create Ethereum rpc client: %v", err)
	}
	defer client.Close()

	grpcServer := grpc.NewServer()
	ethService, err := service.NewEthereumService(client)

	if err != nil {
		log.Fatalf("Failed to create Ethereum service: %v", err)
	}

	pb.RegisterEthereumServiceServer(grpcServer, ethService)

	// create gRPC server
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", cfg.GRPCServerPort))
	if err != nil {
		log.Fatalf("gRPC failed to listen on: %v", err)
	}

	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		grpcServer.GracefulStop()
	}()

	go func() {
		mux := http.NewServeMux()
		mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
			status := client.HealthStatus()
			json.NewEncoder(w).Encode(status)
		})

		healthAddr := fmt.Sprintf(":%d", cfg.GRPCServerPort+1)
		log.Printf("Starting health check server on %s", healthAddr)
		if err := http.ListenAndServe(healthAddr, mux); err != nil {
			log.Printf("Health check server failed: %v", err)
		}
	}()

	log.Printf("Starting Ethereum gRPC server on %v", lis.Addr())

	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}

	// nc, _ := nats.Connect(nats.DefaultURL)
	// defer nc.Close()
	//
	// nc.Publish("tx.eth", []byte("ETH data sample"))
}
