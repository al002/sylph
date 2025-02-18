// Code generated by protoc-gen-go. DO NOT EDIT.
// versions:
// 	protoc-gen-go v1.36.5
// 	protoc        v3.21.12
// source: ethereum/service.proto

package proto

import (
	protoreflect "google.golang.org/protobuf/reflect/protoreflect"
	protoimpl "google.golang.org/protobuf/runtime/protoimpl"
	emptypb "google.golang.org/protobuf/types/known/emptypb"
	reflect "reflect"
	sync "sync"
	unsafe "unsafe"
)

const (
	// Verify that this generated code is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(20 - protoimpl.MinVersion)
	// Verify that runtime/protoimpl is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(protoimpl.MaxVersion - 20)
)

type GetLatestBlockResponse struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	LatestBlock   *LatestBlock           `protobuf:"bytes,1,opt,name=latest_block,json=latestBlock,proto3" json:"latest_block,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *GetLatestBlockResponse) Reset() {
	*x = GetLatestBlockResponse{}
	mi := &file_ethereum_service_proto_msgTypes[0]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *GetLatestBlockResponse) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*GetLatestBlockResponse) ProtoMessage() {}

func (x *GetLatestBlockResponse) ProtoReflect() protoreflect.Message {
	mi := &file_ethereum_service_proto_msgTypes[0]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use GetLatestBlockResponse.ProtoReflect.Descriptor instead.
func (*GetLatestBlockResponse) Descriptor() ([]byte, []int) {
	return file_ethereum_service_proto_rawDescGZIP(), []int{0}
}

func (x *GetLatestBlockResponse) GetLatestBlock() *LatestBlock {
	if x != nil {
		return x.LatestBlock
	}
	return nil
}

type GetBlockRequest struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	BlockNumber   int64                  `protobuf:"varint,1,opt,name=block_number,json=blockNumber,proto3" json:"block_number,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *GetBlockRequest) Reset() {
	*x = GetBlockRequest{}
	mi := &file_ethereum_service_proto_msgTypes[1]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *GetBlockRequest) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*GetBlockRequest) ProtoMessage() {}

func (x *GetBlockRequest) ProtoReflect() protoreflect.Message {
	mi := &file_ethereum_service_proto_msgTypes[1]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use GetBlockRequest.ProtoReflect.Descriptor instead.
func (*GetBlockRequest) Descriptor() ([]byte, []int) {
	return file_ethereum_service_proto_rawDescGZIP(), []int{1}
}

func (x *GetBlockRequest) GetBlockNumber() int64 {
	if x != nil {
		return x.BlockNumber
	}
	return 0
}

type GetBlockResponse struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	BlockData     *BlockData             `protobuf:"bytes,1,opt,name=block_data,json=blockData,proto3" json:"block_data,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *GetBlockResponse) Reset() {
	*x = GetBlockResponse{}
	mi := &file_ethereum_service_proto_msgTypes[2]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *GetBlockResponse) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*GetBlockResponse) ProtoMessage() {}

func (x *GetBlockResponse) ProtoReflect() protoreflect.Message {
	mi := &file_ethereum_service_proto_msgTypes[2]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use GetBlockResponse.ProtoReflect.Descriptor instead.
func (*GetBlockResponse) Descriptor() ([]byte, []int) {
	return file_ethereum_service_proto_rawDescGZIP(), []int{2}
}

func (x *GetBlockResponse) GetBlockData() *BlockData {
	if x != nil {
		return x.BlockData
	}
	return nil
}

type SubscribeNewBlocksRequest struct {
	state protoimpl.MessageState `protogen:"open.v1"`
	// Optional starting block number
	StartBlock    int64 `protobuf:"varint,1,opt,name=start_block,json=startBlock,proto3" json:"start_block,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *SubscribeNewBlocksRequest) Reset() {
	*x = SubscribeNewBlocksRequest{}
	mi := &file_ethereum_service_proto_msgTypes[3]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *SubscribeNewBlocksRequest) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*SubscribeNewBlocksRequest) ProtoMessage() {}

func (x *SubscribeNewBlocksRequest) ProtoReflect() protoreflect.Message {
	mi := &file_ethereum_service_proto_msgTypes[3]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use SubscribeNewBlocksRequest.ProtoReflect.Descriptor instead.
func (*SubscribeNewBlocksRequest) Descriptor() ([]byte, []int) {
	return file_ethereum_service_proto_rawDescGZIP(), []int{3}
}

func (x *SubscribeNewBlocksRequest) GetStartBlock() int64 {
	if x != nil {
		return x.StartBlock
	}
	return 0
}

type GetBlockRangeRequest struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	StartBlock    int64                  `protobuf:"varint,1,opt,name=start_block,json=startBlock,proto3" json:"start_block,omitempty"`
	EndBlock      int64                  `protobuf:"varint,2,opt,name=end_block,json=endBlock,proto3" json:"end_block,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *GetBlockRangeRequest) Reset() {
	*x = GetBlockRangeRequest{}
	mi := &file_ethereum_service_proto_msgTypes[4]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *GetBlockRangeRequest) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*GetBlockRangeRequest) ProtoMessage() {}

func (x *GetBlockRangeRequest) ProtoReflect() protoreflect.Message {
	mi := &file_ethereum_service_proto_msgTypes[4]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use GetBlockRangeRequest.ProtoReflect.Descriptor instead.
func (*GetBlockRangeRequest) Descriptor() ([]byte, []int) {
	return file_ethereum_service_proto_rawDescGZIP(), []int{4}
}

func (x *GetBlockRangeRequest) GetStartBlock() int64 {
	if x != nil {
		return x.StartBlock
	}
	return 0
}

func (x *GetBlockRangeRequest) GetEndBlock() int64 {
	if x != nil {
		return x.EndBlock
	}
	return 0
}

var File_ethereum_service_proto protoreflect.FileDescriptor

var file_ethereum_service_proto_rawDesc = string([]byte{
	0x0a, 0x16, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65, 0x75, 0x6d, 0x2f, 0x73, 0x65, 0x72, 0x76, 0x69,
	0x63, 0x65, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x12, 0x08, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65,
	0x75, 0x6d, 0x1a, 0x1b, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2f, 0x70, 0x72, 0x6f, 0x74, 0x6f,
	0x62, 0x75, 0x66, 0x2f, 0x65, 0x6d, 0x70, 0x74, 0x79, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x1a,
	0x14, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65, 0x75, 0x6d, 0x2f, 0x74, 0x79, 0x70, 0x65, 0x73, 0x2e,
	0x70, 0x72, 0x6f, 0x74, 0x6f, 0x22, 0x52, 0x0a, 0x16, 0x47, 0x65, 0x74, 0x4c, 0x61, 0x74, 0x65,
	0x73, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x12,
	0x38, 0x0a, 0x0c, 0x6c, 0x61, 0x74, 0x65, 0x73, 0x74, 0x5f, 0x62, 0x6c, 0x6f, 0x63, 0x6b, 0x18,
	0x01, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x15, 0x2e, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65, 0x75, 0x6d,
	0x2e, 0x4c, 0x61, 0x74, 0x65, 0x73, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x52, 0x0b, 0x6c, 0x61,
	0x74, 0x65, 0x73, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x22, 0x34, 0x0a, 0x0f, 0x47, 0x65, 0x74,
	0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x52, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x12, 0x21, 0x0a, 0x0c,
	0x62, 0x6c, 0x6f, 0x63, 0x6b, 0x5f, 0x6e, 0x75, 0x6d, 0x62, 0x65, 0x72, 0x18, 0x01, 0x20, 0x01,
	0x28, 0x03, 0x52, 0x0b, 0x62, 0x6c, 0x6f, 0x63, 0x6b, 0x4e, 0x75, 0x6d, 0x62, 0x65, 0x72, 0x22,
	0x46, 0x0a, 0x10, 0x47, 0x65, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x52, 0x65, 0x73, 0x70, 0x6f,
	0x6e, 0x73, 0x65, 0x12, 0x32, 0x0a, 0x0a, 0x62, 0x6c, 0x6f, 0x63, 0x6b, 0x5f, 0x64, 0x61, 0x74,
	0x61, 0x18, 0x01, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x13, 0x2e, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65,
	0x75, 0x6d, 0x2e, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x44, 0x61, 0x74, 0x61, 0x52, 0x09, 0x62, 0x6c,
	0x6f, 0x63, 0x6b, 0x44, 0x61, 0x74, 0x61, 0x22, 0x3c, 0x0a, 0x19, 0x53, 0x75, 0x62, 0x73, 0x63,
	0x72, 0x69, 0x62, 0x65, 0x4e, 0x65, 0x77, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x73, 0x52, 0x65, 0x71,
	0x75, 0x65, 0x73, 0x74, 0x12, 0x1f, 0x0a, 0x0b, 0x73, 0x74, 0x61, 0x72, 0x74, 0x5f, 0x62, 0x6c,
	0x6f, 0x63, 0x6b, 0x18, 0x01, 0x20, 0x01, 0x28, 0x03, 0x52, 0x0a, 0x73, 0x74, 0x61, 0x72, 0x74,
	0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x22, 0x54, 0x0a, 0x14, 0x47, 0x65, 0x74, 0x42, 0x6c, 0x6f, 0x63,
	0x6b, 0x52, 0x61, 0x6e, 0x67, 0x65, 0x52, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x12, 0x1f, 0x0a,
	0x0b, 0x73, 0x74, 0x61, 0x72, 0x74, 0x5f, 0x62, 0x6c, 0x6f, 0x63, 0x6b, 0x18, 0x01, 0x20, 0x01,
	0x28, 0x03, 0x52, 0x0a, 0x73, 0x74, 0x61, 0x72, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x12, 0x1b,
	0x0a, 0x09, 0x65, 0x6e, 0x64, 0x5f, 0x62, 0x6c, 0x6f, 0x63, 0x6b, 0x18, 0x02, 0x20, 0x01, 0x28,
	0x03, 0x52, 0x08, 0x65, 0x6e, 0x64, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x32, 0xc2, 0x02, 0x0a, 0x0f,
	0x45, 0x74, 0x68, 0x65, 0x72, 0x65, 0x75, 0x6d, 0x53, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x12,
	0x4c, 0x0a, 0x0e, 0x47, 0x65, 0x74, 0x4c, 0x61, 0x74, 0x65, 0x73, 0x74, 0x42, 0x6c, 0x6f, 0x63,
	0x6b, 0x12, 0x16, 0x2e, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f,
	0x62, 0x75, 0x66, 0x2e, 0x45, 0x6d, 0x70, 0x74, 0x79, 0x1a, 0x20, 0x2e, 0x65, 0x74, 0x68, 0x65,
	0x72, 0x65, 0x75, 0x6d, 0x2e, 0x47, 0x65, 0x74, 0x4c, 0x61, 0x74, 0x65, 0x73, 0x74, 0x42, 0x6c,
	0x6f, 0x63, 0x6b, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x22, 0x00, 0x12, 0x43, 0x0a,
	0x08, 0x47, 0x65, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x12, 0x19, 0x2e, 0x65, 0x74, 0x68, 0x65,
	0x72, 0x65, 0x75, 0x6d, 0x2e, 0x47, 0x65, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x52, 0x65, 0x71,
	0x75, 0x65, 0x73, 0x74, 0x1a, 0x1a, 0x2e, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65, 0x75, 0x6d, 0x2e,
	0x47, 0x65, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65,
	0x22, 0x00, 0x12, 0x52, 0x0a, 0x12, 0x53, 0x75, 0x62, 0x73, 0x63, 0x72, 0x69, 0x62, 0x65, 0x4e,
	0x65, 0x77, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x73, 0x12, 0x23, 0x2e, 0x65, 0x74, 0x68, 0x65, 0x72,
	0x65, 0x75, 0x6d, 0x2e, 0x53, 0x75, 0x62, 0x73, 0x63, 0x72, 0x69, 0x62, 0x65, 0x4e, 0x65, 0x77,
	0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x73, 0x52, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x1a, 0x13, 0x2e,
	0x65, 0x74, 0x68, 0x65, 0x72, 0x65, 0x75, 0x6d, 0x2e, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x44, 0x61,
	0x74, 0x61, 0x22, 0x00, 0x30, 0x01, 0x12, 0x48, 0x0a, 0x0d, 0x47, 0x65, 0x74, 0x42, 0x6c, 0x6f,
	0x63, 0x6b, 0x52, 0x61, 0x6e, 0x67, 0x65, 0x12, 0x1e, 0x2e, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65,
	0x75, 0x6d, 0x2e, 0x47, 0x65, 0x74, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x52, 0x61, 0x6e, 0x67, 0x65,
	0x52, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x1a, 0x13, 0x2e, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65,
	0x75, 0x6d, 0x2e, 0x42, 0x6c, 0x6f, 0x63, 0x6b, 0x44, 0x61, 0x74, 0x61, 0x22, 0x00, 0x30, 0x01,
	0x42, 0x2e, 0x5a, 0x2c, 0x67, 0x69, 0x74, 0x68, 0x75, 0x62, 0x2e, 0x63, 0x6f, 0x6d, 0x2f, 0x61,
	0x6c, 0x30, 0x30, 0x32, 0x2f, 0x73, 0x79, 0x6c, 0x70, 0x68, 0x2f, 0x63, 0x68, 0x61, 0x69, 0x6e,
	0x73, 0x2f, 0x65, 0x74, 0x68, 0x65, 0x72, 0x65, 0x75, 0x6d, 0x2f, 0x70, 0x72, 0x6f, 0x74, 0x6f,
	0x62, 0x06, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x33,
})

var (
	file_ethereum_service_proto_rawDescOnce sync.Once
	file_ethereum_service_proto_rawDescData []byte
)

func file_ethereum_service_proto_rawDescGZIP() []byte {
	file_ethereum_service_proto_rawDescOnce.Do(func() {
		file_ethereum_service_proto_rawDescData = protoimpl.X.CompressGZIP(unsafe.Slice(unsafe.StringData(file_ethereum_service_proto_rawDesc), len(file_ethereum_service_proto_rawDesc)))
	})
	return file_ethereum_service_proto_rawDescData
}

var file_ethereum_service_proto_msgTypes = make([]protoimpl.MessageInfo, 5)
var file_ethereum_service_proto_goTypes = []any{
	(*GetLatestBlockResponse)(nil),    // 0: ethereum.GetLatestBlockResponse
	(*GetBlockRequest)(nil),           // 1: ethereum.GetBlockRequest
	(*GetBlockResponse)(nil),          // 2: ethereum.GetBlockResponse
	(*SubscribeNewBlocksRequest)(nil), // 3: ethereum.SubscribeNewBlocksRequest
	(*GetBlockRangeRequest)(nil),      // 4: ethereum.GetBlockRangeRequest
	(*LatestBlock)(nil),               // 5: ethereum.LatestBlock
	(*BlockData)(nil),                 // 6: ethereum.BlockData
	(*emptypb.Empty)(nil),             // 7: google.protobuf.Empty
}
var file_ethereum_service_proto_depIdxs = []int32{
	5, // 0: ethereum.GetLatestBlockResponse.latest_block:type_name -> ethereum.LatestBlock
	6, // 1: ethereum.GetBlockResponse.block_data:type_name -> ethereum.BlockData
	7, // 2: ethereum.EthereumService.GetLatestBlock:input_type -> google.protobuf.Empty
	1, // 3: ethereum.EthereumService.GetBlock:input_type -> ethereum.GetBlockRequest
	3, // 4: ethereum.EthereumService.SubscribeNewBlocks:input_type -> ethereum.SubscribeNewBlocksRequest
	4, // 5: ethereum.EthereumService.GetBlockRange:input_type -> ethereum.GetBlockRangeRequest
	0, // 6: ethereum.EthereumService.GetLatestBlock:output_type -> ethereum.GetLatestBlockResponse
	2, // 7: ethereum.EthereumService.GetBlock:output_type -> ethereum.GetBlockResponse
	6, // 8: ethereum.EthereumService.SubscribeNewBlocks:output_type -> ethereum.BlockData
	6, // 9: ethereum.EthereumService.GetBlockRange:output_type -> ethereum.BlockData
	6, // [6:10] is the sub-list for method output_type
	2, // [2:6] is the sub-list for method input_type
	2, // [2:2] is the sub-list for extension type_name
	2, // [2:2] is the sub-list for extension extendee
	0, // [0:2] is the sub-list for field type_name
}

func init() { file_ethereum_service_proto_init() }
func file_ethereum_service_proto_init() {
	if File_ethereum_service_proto != nil {
		return
	}
	file_ethereum_types_proto_init()
	type x struct{}
	out := protoimpl.TypeBuilder{
		File: protoimpl.DescBuilder{
			GoPackagePath: reflect.TypeOf(x{}).PkgPath(),
			RawDescriptor: unsafe.Slice(unsafe.StringData(file_ethereum_service_proto_rawDesc), len(file_ethereum_service_proto_rawDesc)),
			NumEnums:      0,
			NumMessages:   5,
			NumExtensions: 0,
			NumServices:   1,
		},
		GoTypes:           file_ethereum_service_proto_goTypes,
		DependencyIndexes: file_ethereum_service_proto_depIdxs,
		MessageInfos:      file_ethereum_service_proto_msgTypes,
	}.Build()
	File_ethereum_service_proto = out.File
	file_ethereum_service_proto_goTypes = nil
	file_ethereum_service_proto_depIdxs = nil
}
