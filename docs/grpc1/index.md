# GPRC 实战




# GPRC 实战



# GRPC 简介

grpc 是由 google 开发的一款开源，高性能 rpc（[远程进程调用协议](https://zh.wikipedia.org/wiki/%E9%81%A0%E7%A8%8B%E9%81%8E%E7%A8%8B%E8%AA%BF%E7%94%A8)）使用 [Protocol Buffers](https://developers.google.com/protocol-buffers/docs/overview) 作为数据交换格式。

![grpc.png](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030101652.png)


# GRPC 安装

golang 使用 grpc 要安装 grpc-go, protoc 和 对应的插件。


## 安装grpc-go


```bash
go get -u github.com/golang/protobuf/{proto,protoc-gen-go}
go get -u google.golang.org/grpc
```

如果是国内用户无法连接到 google.golang.org 的话可以使用 VPN。或者直接从 github.com 直接下载源代码再编译安装

```bash
git clone https://github.com/grpc/grpc-go.git $GOPATH/src/google.golang.org/grpc
go get -u google.golang.org/grpc
```


## 安装 protoc

golang 要使用 grpc，还需要使用 protoc 工具。因为 golang 不能直接识别 .proto 文件，需要使用 protoc 工具将 .proto 转化成 golang 代码。下面介绍几个平台下安装 protobuf 的方法。

### macos

macos 下安装直接使用 brew 命令即可。

```bash
brew install protobuf
```



### linux

linux 下需要先从 github.com 下载 protobuf 源码或者二进制文件，[下载地址](https://github.com/protocolbuffers/protobuf/releases)。二进制安装的话就下载 protobuf-all-*.tar.gz 包，解压后进入生成的目录。之后执行命令：

```bash
make && make install
```



### windows

下载 protobuf.all-*.zip 包，解压后再配置环境变量，将 protobuf\bin 配置到 $PATH 变量中。


# GRPC使用



## 新建项目

新建一个 grpc 项目，如下:

```bash
../sample
└── pb
    └── echo.proto
```

echo.proto 的内容为:

```protobuf
syntax = "proto3"; // protobuf 语法版本，默认为 proto2
// // 这个是注释
// .proto 所在的包路径
package sample.pb;
option go_package = "pb";
// EchoRequest grpc 请求报文格式.
message EchoRequest {
  string message = 1;
}
// EchoResponse grpc 响应报文格式.
message EchoResponse {
  string message = 1;
}
// 定义 Echo 服务.
service Echo {
  // UnaryEcho 一元请求.
  rpc UnaryEcho(EchoRequest) returns (EchoResponse) {}
  // ServerStreamingEcho 服务端 stream 请求.
  rpc ServerStreamingEcho(EchoRequest) returns (stream EchoResponse) {}
  // ClientStreamingEcho 客户端 stream 请求.
  rpc ClientStreamingEcho(stream EchoRequest) returns (EchoResponse) {}
  // BidirectionalStreamingEcho 双向 stream.
  rpc BidirectionalStreamingEcho(stream EchoRequest) returns (stream EchoResponse) {}
}
```

执行以下命令将  .proto 转化为 golang 代码:

```bash
cd sample
# protoc -I<import路径> <...-I$PATH> --go_out=plugins=grpc:<输出路径> *.proto
protoc -I. --go_out=plugins=grpc:. pb/echo.proto
```

简单描述下 protoc 命令的功能。

- -I  :  *.proto 中导入的包的路径，导入的路径为全路径格式。. 表示当前路径。
- --go_out=plugins=grpc: ：指定 _.proto 输出的格式和路径，生成 _.go 文件的路径为  和 *.proto 的拼接。执行成功后成为文件 echo.pb.go 文件:



```bash
../sample
└── pb
    ├── echo.pb.go
    └── echo.proto
```



## Server


```go
package main
import (
	"context"
	"errors"
	"google.golang.org/grpc"
	"io"
	"log"
	"mysite/sample/pb"
	"net"
)
type server struct {
	pb.EchoServer
}
// 简单请求
func (s *server) UnaryEcho(ctx context.Context, request *pb.EchoRequest) (*pb.EchoResponse, error) {
	return &pb.EchoResponse{Message: "echo: " + request.Message}, nil
}
// 服务端流式
func (s *server) ServerStreamingEcho(request *pb.EchoRequest, stream pb.Echo_ServerStreamingEchoServer) error {
	_ = stream.Send(&pb.EchoResponse{Message: "hello"})
	_ = stream.Send(&pb.EchoResponse{Message: " "})
	_ = stream.Send(&pb.EchoResponse{Message: "client"})
	return nil
}
// 客户端流式
func (s *server) ClientStreamingEcho(stream pb.Echo_ClientStreamingEchoServer) error {
	for {
      recv, err := stream.Recv() // block 直到有数据输出
      if errors.Is(err, io.EOF) {
          // 表示消息传输完毕
        break
      }
      if err != nil {
        log.Printf("recv error: %v", err)
        return err
      }
      // client 断开连接
      log.Printf("recv data: %v", recv.Message)
	}
  // SendAndClose 只存在于客户端 stream 请求
	// 发送完关闭 stream
	return stream.SendAndClose(&pb.EchoResponse{Message: "bye"})
}
// 双向流式
func (s *server) BidirectionalStreamingEcho(stream pb.Echo_BidirectionalStreamingEchoServer) error {
	// 如果服务端 stream 方法退出，客户端请求也直接断开
	for {
      recv, err := stream.Recv()
      if errors.Is(err, io.EOF) {
        break
      }
      if err != nil {
        log.Printf("recv error: %v", err)
        return err
      }
      if recv.Message == "bye" {
        log.Printf("client send done!")
        break
      }
      if err := stream.Send(&pb.EchoResponse{Message: "reply: " + recv.Message}); err != nil {
        log.Printf("send message error: %v", err)
        return err
      }
	}
	return nil
}
func main() {
	addr := "127.0.0.1:50001"
	// grpc 为 http2 请求，传输层协议为 tcp
	lis, err := net.Listen("tcp", addr)
	if err != nil {
  		log.Fatalf("binding at %v: %v", addr, err)
	}
	gRPCServer := grpc.NewServer()
	pb.RegisterEchoServer(gRPCServer, &server{})
	if err := gRPCServer.Serve(lis); err != nil {
  		log.Fatalf("start grpc: %v", err)
	}
}
```



## Client


```go
package main
import (
	"context"
	"errors"
	"fmt"
	"google.golang.org/grpc"
	"io"
	"log"
	"mysite/sample/pb"
)
// 简单请求
func unaryEcho(cli pb.EchoClient, msg string) {
	recv, err := cli.UnaryEcho(context.Background(), &pb.EchoRequest{Message: msg})
	if err != nil {
  		log.Fatalf("unaryEcho %v", err)
	}
	log.Println("recv data => " + recv.Message)
}
// 服务端流式
func serverStreamingEcho(cli pb.EchoClient, msg string) {
	stream, err := cli.ServerStreamingEcho(context.Background(), &pb.EchoRequest{Message: msg})
	if err != nil {
  		log.Fatalf("serverStreamingEcho %v", err)
	}
	ctx := stream.Context()
	for {
      select {
          case <-ctx.Done():
            log.Println("serverStreamingEcho done!")
            break
          default:
      }
      msg, err := stream.Recv()
      if errors.Is(err, io.EOF) {
        break
      }
      if err == nil {
        log.Println("serverStreaming reply => ", msg.Message)
      }
	}
}
// 客户端流式
func clientStreamingEcho(cli pb.EchoClient) {
	stream, err := cli.ClientStreamingEcho(context.Background())
	if err != nil {
      log.Printf("connect client Streaming: %v\n", err)
      return
	}
	err = stream.Send(&pb.EchoRequest{Message: "hello"})
	if err != nil {
      log.Printf("clientStreamingEcho send data: %v", err)
      return
	}
	err = stream.Send(&pb.EchoRequest{Message: " "})
	if err != nil {
      log.Printf("clientStreamingEcho send data: %v", err)
      return
	}
	err = stream.Send(&pb.EchoRequest{Message: "world"})
	if err != nil {
      log.Printf("clientStreamingEcho send data: %v", err)
      return
	}
	if recv, err := stream.CloseAndRecv(); err == nil {
  		fmt.Printf("recv data: %v\n", recv.Message)
	}
}
// 双向流式
func bidirectionalStreamingEcho(cli pb.EchoClient) {
	stream, err := cli.BidirectionalStreamingEcho(context.Background())
	if err != nil {
  		log.Printf("bidirectionalStreamingEcho error: %v\n", err)
  		return
	}
	stream.Send(&pb.EchoRequest{Message: "dataset 1"})
	recv, err := stream.Recv()
	if err == nil {
  		fmt.Printf("recv from bidirectionalStreamingEcho => %v\n", recv.Message)
	}
	stream.Send(&pb.EchoRequest{Message: "dataset 2"})
	recv, err = stream.Recv()
	if err == nil {
  		fmt.Printf("recv from bidirectionalStreamingEcho => %v\n", recv.Message)
	}
	stream.Send(&pb.EchoRequest{Message: "dataset 3"})
	recv, err = stream.Recv()
	if err == nil {
  		fmt.Printf("recv from bidirectionalStreamingEcho => %v\n", recv.Message)
	}
	stream.Send(&pb.EchoRequest{Message: "bye"})
	stream.CloseSend()
}
func main() {
	addr := "127.0.0.1:50001"
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	conn, err := grpc.DialContext(ctx, addr, grpc.WithInsecure())
	if err != nil {
  		log.Fatalf("connect %v: %v", addr, err)
	}
	cli := pb.NewEchoClient(conn)
	unaryEcho(cli, "hello")
	serverStreamingEcho(cli, "hello")
	clientStreamingEcho(cli)
	bidirectionalStreamingEcho(cli)
}
```


