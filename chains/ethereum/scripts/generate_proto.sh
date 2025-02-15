#!/bin/bash

PROTO_DIR="../../proto"
OUT_DIR="./proto"

protoc -I=$PROTO_DIR \
    --go_out=$OUT_DIR --go_opt=paths=source_relative \
    --go-grpc_out=$OUT_DIR --go-grpc_opt=paths=source_relative \
    $PROTO_DIR/ethereum/types.proto \
    $PROTO_DIR/ethereum/service.proto
