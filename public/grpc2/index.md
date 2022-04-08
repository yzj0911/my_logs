# 

# GPRC 进阶


# GPRC 进阶


grpc 除了提供四种请求类型之外，还支持很多高级功能：keepalive、请求重试、负载均衡、用户验证等。接下来一一介绍。


# GRPC 进阶功能
> 每个grpc请求都是 stream。




## Keepalive
Keepalive 能够让 grpc 的每个 stream 保持长连接状态，适合一些执行时间长的请求。Keepalive 支持在服务端和客户端配置，且只有服务端配置后，客户端的配置才会真正有效。先给出实例的代码在来说明 grpc keepalive 的使用情况：server 实现：

```go
// ...
var kaep = keepalive.EnforcementPolicy{
	MinTime:             5 * time.Second, // If a client pings more than once every 5 seconds, terminate the connection
	PermitWithoutStream: true,            // Allow pings even when there are no active streams
}

var kasp = keepalive.ServerParameters{
	MaxConnectionIdle:     15 * time.Second, // If a client is idle for 15 seconds, send a GOAWAY
	MaxConnectionAge:      30 * time.Second, // If any connection is alive for more than 30 seconds, send a GOAWAY
	MaxConnectionAgeGrace: 5 * time.Second,  // Allow 5 seconds for pending RPCs to complete before forcibly closing connections
	Time:                  5 * time.Second,  // Ping the client if it is idle for 5 seconds to ensure the connection is still active
	Timeout:               1 * time.Second,  // Wait 1 second for the ping ack before assuming the connection is dead
}

// server implements EchoServer.
type server struct {
	pb.UnimplementedEchoServer
}

func (s *server) UnaryEcho(ctx context.Context, req *pb.EchoRequest) (*pb.EchoResponse, error) {
	return &pb.EchoResponse{Message: req.Message}, nil
}

func main() {
	address := "50001"
	lis, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

  // 创建 grpc server 时配置服务端的 keepalive
	s := grpc.NewServer(grpc.KeepaliveEnforcementPolicy(kaep), grpc.KeepaliveParams(kasp))
	pb.RegisterEchoServer(s, &server{})

	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
```

client 端实现：

```go
// ...
var kacp = keepalive.ClientParameters{
	Time:                10 * time.Second, // send pings every 10 seconds if there is no activity
	Timeout:             time.Second,      // wait 1 second for ping ack before considering the connection dead
	PermitWithoutStream: true,             // send pings even without active streams
}

func main() {
	conn, err := grpc.Dial("50001", grpc.WithInsecure(), grpc.WithKeepaliveParams(kacp))
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()

	c := pb.NewEchoClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	fmt.Println("Performing unary request")
	res, err := c.UnaryEcho(ctx, &pb.EchoRequest{Message: "keepalive demo"})
	if err != nil {
		log.Fatalf("unexpected error from UnaryEcho: %v", err)
	}
	fmt.Println("RPC response:", res)
}
```

keepalive 的实现核心在于 `keepalive.EnforcementPolicy` 和 `keepalive.ServerParameters`。首先是 `keepalive.ServerParameters`。它包含几个属性：

- MaxConnectionIdle : 最大空闲连接时间，默认为无限制。这段时间为客户端 stream 请求为0 或者建立连接。超出这段时间后，serve 会发送一个 `GoWay`，强制 client stream 断开。
- MaxConnectionAge：最大连接时间，默认为无限制。stream 连接超出这个值是发送一个 `GoWay`。
- MaxConnectionAgeGrace ：超出`MaxConnectionAge`之后的宽限时长，默认无限制，最小为 1s。
- Time ：如果一段时间客户端存活但没有 pings 请求，服务端发送一次 ping 请求，默认是 2hour。
- Timeout：服务端发送 ping 请求超时的时间，默认20s。

`keepalive.EnforcementPolicy`在服务端强制执行策略，如果客户端违反改策略则断开连接。它有两个属性：

- MinTime : 如果在指定时间内收到 pings 请求大于一次，强制断开连接，默认 5min。
- PermitWithoutStream：没有活动的 stream 也允许pings。默认关闭。

`keepalive.ClientParameters`是在客户端这侧使用的 keepalive 配置：

- Time ：pings 请求间隔时间，默认无限制，最小为 10s。
- Timeout ：pings 超时时间，默认是 20s。
- PermitWithoutStream：没有活动的 stream 也允许pings。默认关闭。




## 请求重试
grpc 支持请求重试，在客户端配置好规则之后，客户端会在请求失败之后尝试重新发起请求。

```go
var (
	retryPolicy = `{
		"methodConfig": [{
		  "name": [{"service": "mysite.pb.Echo"}],
		  "waitForReady": true,
		  "retryPolicy": {
			  "MaxAttempts": 3,
			  "InitialBackoff": ".01s",
			  "MaxBackoff": "1s",
			  "BackoffMultiplier": 2.0,
			  "RetryableStatusCodes": [ "UNAVAILABLE" ]
		  }
		}]}`
)

// use grpc.WithDefaultServiceConfig() to set service config
func retryDial() (*grpc.ClientConn, error) {
	return grpc.Dial(*addr, grpc.WithInsecure(), grpc.WithDefaultServiceConfig(retryPolicy))
}
// ...
```

retry 配置只需要在客户端设置即可生效。主要是配置ServerConfig，格式为[该链接](https://github.com/grpc/grpc-proto/blob/master/grpc/service_config/service_config.proto)

- MaxAttempts ：重试的最大次数，最大值是5。
- InitialBackoff : 初始化重试间隔时间，第一次重试去 `Randon(0,initialBackoff)`。
- MaxBackoff : 最大重试间隔时间，多次重试是，间隔时间取 `random(0,min(initial_backoff*backoff_multiplier**(n-1), max_backoff))`。
- RetryableStatusCodes : 设置需要重试的状态码。




## 负载均衡
grpc 支持客户端负载均衡策略，负载均衡在 grpc name_resolver 的基础上实现：

```go
const (
	exampleScheme      = "example"
	exampleServiceName = "lb.example.grpc.io"
)
// ...
func main() {
  // ...
	// round_robin 指定负载均衡策略为轮询策略
	roundrobinConn, err := grpc.Dial(
		fmt.Sprintf("%s:///%s", exampleScheme, exampleServiceName),
		grpc.WithBalancerName("round_robin"), // This sets the initial balancing policy.
		grpc.WithInsecure(),
		grpc.WithBlock(),
	)
  // ...
}

// 配置 name resolver

type exampleResolverBuilder struct{}

func (*exampleResolverBuilder) Build(target resolver.Target, cc resolver.ClientConn, opts resolver.BuildOptions) (resolver.Resolver, error) {
	r := &exampleResolver{
		target: target,
		cc:     cc,
		addrsStore: map[string][]string{
			exampleServiceName: addrs,
		},
	}
	r.start()
	return r, nil
}
func (*exampleResolverBuilder) Scheme() string { return exampleScheme }

type exampleResolver struct {
	target     resolver.Target
	cc         resolver.ClientConn
	addrsStore map[string][]string
}

func (r *exampleResolver) start() {
	addrStrs := r.addrsStore[r.target.Endpoint]
	addrs := make([]resolver.Address, len(addrStrs))
	for i, s := range addrStrs {
		addrs[i] = resolver.Address{Addr: s}
	}
	r.cc.UpdateState(resolver.State{Addresses: addrs})
}
func (*exampleResolver) ResolveNow(o resolver.ResolveNowOptions) {}
func (*exampleResolver) Close()                                  {}

func init() {
	resolver.Register(&exampleResolverBuilder{})
}
```

主要是要实现 `resolver.Builder`接口

```go
// Builder creates a resolver that will be used to watch name resolution updates.
type Builder interface {
	// Build creates a new resolver for the given target.
	//
	// gRPC dial calls Build synchronously, and fails if the returned error is
	// not nil.
	Build(target Target, cc ClientConn, opts BuildOptions) (Resolver, error)
	// Scheme returns the scheme supported by this resolver.
	// Scheme is defined at <https://github.com/grpc/grpc/blob/master/doc/naming.md>.
	Scheme() string
}
```

上面的实现方式不支持动态增减服务端地址，可以使用 etcd 实现负载均衡：

```go
type etcdBuilder struct {
	prefix    string
	endpoints []string
}

func ETCDBuilder(prefix string, endpoints []string) resolver.Builder {
	return &etcdBuilder{prefix, endpoints}
}

func (b *etcdBuilder) Build(target resolver.Target, cc resolver.ClientConn, opts resolver.BuildOptions) (resolver.Resolver, error) {
	cli, err := clientv3.New(clientv3.Config{
		Endpoints:   b.endpoints,
		DialTimeout: 3 * time.Second,
	})
	if err != nil {
		return nil, fmt.Errorf("connect to etcd endpoints error")
	}

	ctx, cancel := context.WithCancel(context.Background())
	rlv := &etcdResolver{
		cc:             cc,
		cli:            cli,
		ctx:            ctx,
		cancel:         cancel,
		watchKeyPrefix: b.prefix,
		freq:           5 * time.Second,
		t:              time.NewTimer(0),
		rn:             make(chan struct{}, 1),
		im:             make(chan []resolver.Address),
		wg:             sync.WaitGroup{},
	}

	rlv.wg.Add(2)
	go rlv.watcher()
	go rlv.FetchBackendsWithWatch()

	return rlv, nil
}

func (b *etcdBuilder) Scheme() string {
	return "etcd"
}

type etcdResolver struct {
	retry  int
	freq   time.Duration
	ctx    context.Context
	cancel context.CancelFunc
	cc     resolver.ClientConn
	cli    *clientv3.Client
	t      *time.Timer

	watchKeyPrefix string

	rn chan struct{}
	im chan []resolver.Address

	wg sync.WaitGroup
}

func (r *etcdResolver) ResolveNow(opt resolver.ResolveNowOptions) {
	select {
        case r.rn <- struct{}{}:
        default:
	}
}

func (r *etcdResolver) Close() {
	r.cancel()
	r.wg.Wait()
	r.t.Stop()
}

func (r *etcdResolver) watcher() {
	defer r.wg.Done()

	for {
		select {
		case <-r.ctx.Done():
			return
		case addrs := <-r.im:
			if len(addrs) > 0 {
				r.retry = 0
				r.t.Reset(r.freq)
				r.cc.UpdateState(resolver.State{Addresses: addrs})
				continue
			}
		case <-r.t.C:
		case <-r.rn:
		}

		result := r.FetchBackends()

		if len(result) == 0 {
			r.retry++
			r.t.Reset(r.freq)
		} else {
			r.retry = 0
			r.t.Reset(r.freq)
		}

		r.cc.UpdateState(resolver.State{Addresses: result})
	}
}

func (r *etcdResolver) FetchBackendsWithWatch() {
	defer r.wg.Done()

	for {
		select {
		case <-r.ctx.Done():
			return
		case _ = <-r.cli.Watch(r.ctx, r.watchKeyPrefix, clientv3.WithPrefix()):
			result := r.FetchBackends()
			r.im <- result
		}
	}
}

func (r *etcdResolver) FetchBackends() []resolver.Address {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	result := make([]resolver.Address, 0)

	resp, err := r.cli.Get(ctx, r.watchKeyPrefix, clientv3.WithPrefix())
	if err != nil {
		return result
	}

	for _, kv := range resp.Kvs {
		if strings.TrimSpace(string(kv.Value)) == "" {
			continue
		}
		result = append(result, resolver.Address{Addr: string(kv.Value)})
	}

	return result
}
```



## grpc 加密传输

以上的请求中，grpc 都是通过明文传输数据。但这种方式是很容易泄露数据内容的，grpc 支持 TLS 格式的加密通讯，来保存数据传输的安全性。

### TLS 证书
我们首先来生成 TLS 证书

```bash
openssl ecparam -genkey -name secp384r1 -out server.key
openssl req -new -x509 -sha256 -key server.key -out server.pem -days 3650
```

这里需要填写相关信息

```bash
Country Name (2 letter code) []:
State or Province Name (full name) []:
Locality Name (eg, city) []:
Organization Name (eg, company) []:
Organizational Unit Name (eg, section) []:
Common Name (eg, fully qualified host name) []: mysite
Email Address []:
```

填写完成后就生成对应的证书：

```bash
ssl
├── server.key
└── server.pem
```

服务端实现

```go
// ...
const PORT = "50001"

func main() {
    // 通过 credentials 加载服务端的TLS证书
    c, err := credentials.NewServerTLSFromFile("../ssl/server.pem", "../ssl/server.key")
    if err != nil {
        log.Fatalf("credentials.NewServerTLSFromFile err: %v", err)
    }
		
  	// 添加 credentials 配置
    server := grpc.NewServer(grpc.Creds(c))
    pb.RegisterSearchServiceServer(server, &SearchService{})

    lis, err := net.Listen("tcp", ":"+PORT)
    if err != nil {
        log.Fatalf("net.Listen err: %v", err)
    }

    server.Serve(lis)
}
```

客户端实现

```go
const PORT = "9001"

func main() {
    // 添加 credentials 配置
    c, err := credentials.NewClientTLSFromFile("../ssl/server.pem", "mysite")
    if err != nil {
        log.Fatalf("credentials.NewClientTLSFromFile err: %v", err)
    }

  	// 客户端开启证书验证
    conn, err := grpc.Dial(":"+PORT, grpc.WithTransportCredentials(c))
    if err != nil {
        log.Fatalf("grpc.Dial err: %v", err)
    }
    defer conn.Close()

    client := pb.NewSearchServiceClient(conn)
    resp, err := client.Search(context.Background(), &pb.SearchRequest{
        Request: "gRPC",
    })
    if err != nil {
        log.Fatalf("client.Search err: %v", err)
    }

    log.Printf("resp: %s", resp.GetResponse())
}
```



### CA TLS 证书

TLS 证书的安全性还不够高，特别在证书生成之后，`server.key`文件的传输就成为一个问题。所以 CA 来签发 TLS 证书来解决这个问题。使用开源工具 [cfssl](https://github.com/cloudflare/cfssl/releases) 生成对应的证书：[1.ca](http://1.ca/) 配置

```bash
cat << EOF | tee ca-config.json
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "mysite": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }}
EOF
```

配置 mysite 机构证书可以进行服务端和客户端双向验证。[2.ca](http://2.ca/) 证书

```bash
cat << EOF | tee ca-csr.json
{
    "CN": "mysite CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]}
EOF
```

3.服务端证书

```bash
cat << EOF | tee server-csr.json
{
    "CN": "mysite",
    "hosts": [
        "127.0.0.1"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]}
EOF
```

生成 mysite ca 证书和私钥，初始化 ca

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

生成server证书

```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=mysite -hostname=mysite server-csr.json | cfssljson -bare server
```

最后的结果为:

```bash
../ssl
├── ca-config.json
├── ca-csr.json
├── ca-key.pem
├── ca.csr
├── ca.pem
├── server-csr.json
├── server-key.pem
├── server.csr
└── server.pem
```

接下来是代码实现，先是服务端：

```go
// ...
type ecServer struct {
	pb.UnimplementedEchoServer
}

func (s *ecServer) UnaryEcho(ctx context.Context, req *pb.EchoRequest) (*pb.EchoResponse, error) {
	return &pb.EchoResponse{Message: req.Message}, nil
}

func main() {
	lis, err := net.Listen("tcp", "127.0.0.1:50001")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	// Create tls based credential.
	cert, err := tls.LoadX509KeyPair("ssl/server.pem", "ssl/server-key.pem")
	if err != nil {
		log.Fatalf("tls.LoadX509KeyPair err: %v", err)
	}

	certPool := x509.NewCertPool()
	ca, err := ioutil.ReadFile("ssl/ca.pem")
	if err != nil {
		log.Fatalf("ioutil.ReadFile err: %v", err)
	}

	if ok := certPool.AppendCertsFromPEM(ca); !ok {
		log.Fatalf("certPool.AppendCertsFromPEM err")
	}

	creds := credentials.NewTLS(&tls.Config{
		Certificates: []tls.Certificate{cert},
		ClientAuth:   tls.RequireAndVerifyClientCert,
		ClientCAs:    certPool,
	})

	s := grpc.NewServer(grpc.Creds(creds))

	// Register EchoServer on the server.
	pb.RegisterEchoServer(s, &ecServer{})

	log.Println("server start")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
```

然后是客户端：

```go
// ...
func callUnaryEcho(client pb.EchoClient, message string) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	resp, err := client.UnaryEcho(ctx, &pb.EchoRequest{Message: message})
	if err != nil {
		log.Fatalf("client.UnaryEcho(_) = _, %v: ", err)
	}
	fmt.Println("UnaryEcho: ", resp.Message)
}

func main() {
	// Create tls based credential.
	cert, err := tls.LoadX509KeyPair("ssl/server.pem", "ssl/server-key.pem")
	if err != nil {
		log.Fatalf("tls.LoadX509KeyPair err: %v", err)
	}

	certPool := x509.NewCertPool()
	ca, err := ioutil.ReadFile("ssl/ca.pem")
	if err != nil {
		log.Fatalf("ioutil.ReadFile err: %v", err)
	}

	if ok := certPool.AppendCertsFromPEM(ca); !ok {
		log.Fatalf("certPool.AppendCertsFromPEM err")
	}

	creds := credentials.NewTLS(&tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   "mysite",
		RootCAs:      certPool,
	})

	// Set up a connection to the server.
	conn, err := grpc.Dial("127.0.0.1:50001", grpc.WithTransportCredentials(creds))
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()

	// Make a echo client and send an RPC.
	rgc := pb.NewEchoClient(conn)
	callUnaryEcho(rgc, "hello world")
}
```



## 拦截器

grpc 支持服务端和客户端的拦截器，可以在请求发起或返回前进行处理，而不用修改原来的代码。接下来来看服务端和客户端各自怎么使用拦截器：

```go
// unary 请求拦截器
func UnaryInterceptor(ctx context.Context,
	req interface{},
	info *grpc.UnaryServerInfo,
	handler grpc.UnaryHandler,
) (resp interface{}, err error) {
	var ip string
	p, ok := peer.FromContext(ctx)
	if ok {
		ip = p.Addr.String()
	}
	md, _ := metadata.FromIncomingContext(ctx)
	start := time.Now()
	resp, err = handler(ctx, req)
	end := time.Now()
	log.Printf("%10s | %14s | %10v | md=%v | reply = %v", ip, info.FullMethod, end.Sub(start), md, resp)
	return
}

// stream 请求拦截器
func StreamInterceptor(srv interface{},
	ss grpc.ServerStream,
	info *grpc.StreamServerInfo,
	handler grpc.StreamHandler,
) (err error) {
	var ip string
	p, ok := peer.FromContext(ss.Context())
	if ok {
		ip = p.Addr.String()
	}
	err = handler(srv, ss)
	log.Printf("stream %v | %v | %s\\n", srv, ip, info.FullMethod)
	return
}

type server struct {
	pb.UnimplementedEchoServer
}

func (s *server) UnaryEcho(ctx context.Context, request *pb.EchoRequest) (*pb.EchoResponse, error) {
	return &pb.EchoResponse{Message: request.Message}, nil
}

func (s *server) BidirectionalStreamingEcho(stream pb.Echo_BidirectionalStreamingEchoServer) error {
	ctx := stream.Context()
	for {
		select {
		case <-ctx.Done():
			break
		default:
		}

		msg, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			log.Printf("recv failed: %v\\n", err)
		}

		if err := stream.Send(&pb.EchoResponse{Message: "reply: " + msg.Message}); err != nil {
			log.Printf("send to client: %v\\n", err)
		}
	}

	return nil
}

func main() {
	addr := "127.0.0.1:50001"

	lis, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("network at %v: %v\\n", addr, err)
	}

	s := grpc.NewServer(grpc.ChainUnaryInterceptor(UnaryInterceptor), grpc.ChainStreamInterceptor(StreamInterceptor))
	pb.RegisterEchoServer(s, &server{})

	if err := s.Serve(lis); err != nil {
		log.Fatalf("start server at %v: %v\\n", addr, err)
	}
}
```

grpc 中的拦截器分两种，一元请求的拦截器和流式请求的拦截器。其中流式请求的连接器同时作用于服务端流式、客户端流式和双向流式三种请求模式。
接下来是客户端：

```go
func clientUnaryInterceptor(
	ctx context.Context,
	method string,
	req, reply interface{},
	cc *grpc.ClientConn,
	invoker grpc.UnaryInvoker,
	opts ...grpc.CallOption,
) (err error) {

	ctx = metadata.AppendToOutgoingContext(ctx, "username", "OOB")
	err = invoker(ctx, method, req, reply, cc, opts...)
	return
}

func clientStreamInterceptor(ctx context.Context,
	desc *grpc.StreamDesc,
	cc *grpc.ClientConn,
	method string,
	streamer grpc.Streamer,
	opts ...grpc.CallOption,
) (stream grpc.ClientStream, err error) {

	// before stream
	stream, err = streamer(ctx, desc, cc, method, opts...)
	// after stream
	return
}

func callUnaryEcho(cc pb.EchoClient, msg string) {
	reply, err := cc.UnaryEcho(context.Background(), &pb.EchoRequest{Message: msg})
	if err == nil {
		log.Printf("reply => %v\\n", reply)
	}
}

func callBidirectionalEcho(cc pb.EchoClient, msg string) {
	stream, err := cc.BidirectionalStreamingEcho(context.TODO())
	if err != nil {
		log.Fatalf("call BidirectionalEcho: %v\\n", err)
	}

	_ = stream.Send(&pb.EchoRequest{Message: msg})
	_ = stream.CloseSend()
	ctx := stream.Context()
	for {
		select {
		case <-ctx.Done():
			break
		default:
		}

		reply, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			log.Fatalf("stream recv: %v\\n", err)
		}
		log.Printf("stream reply => %v\\n", reply.Message)
	}
}

func main() {
	addr := "127.0.0.1:50001"

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	conn, err := grpc.DialContext(
		ctx,
		addr,
		grpc.WithInsecure(),
		grpc.WithChainUnaryInterceptor(clientUnaryInterceptor),
		grpc.WithChainStreamInterceptor(clientStreamInterceptor))
	if err != nil {
		log.Fatalf("connect %v: %v\\n", addr, err)
	}

	cc := pb.NewEchoClient(conn)

	callUnaryEcho(cc, "unary")

	callBidirectionalEcho(cc, "start")
}
```

grpc 的拦截器同时支持单个拦截器和链式拦截器。


## grpc 添加 pprof 接口
grpc 本身是使用 http2 作为底层协议，所以它也能和 golang 的 pprof 结合提供 pprof 接口。下面给出代码：

```go
type server struct {
	pb.UnimplementedEchoServer
}

func (s *server) UnaryEcho(ctx context.Context, request *pb.EchoRequest) (*pb.EchoResponse, error) {
	return &pb.EchoResponse{Message: request.Message}, nil
}

func (s *server) BidirectionalStreamingEcho(stream pb.Echo_BidirectionalStreamingEchoServer) error {
	ctx := stream.Context()
	for {
		select {
		case <-ctx.Done():
			break
		default:
		}

		msg, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			log.Printf("recv failed: %v\\n", err)
		}

		if err := stream.Send(&pb.EchoResponse{Message: "reply: " + msg.Message}); err != nil {
			log.Printf("send to client: %v\\n", err)
		}
	}

	return nil
}

func main() {
	addr := "127.0.0.1:50001"

  // 这里可以添加服务段启动配置和各种拦截器
	s := grpc.NewServer() 
	pb.RegisterEchoServer(s, &server{})

	mux := http.NewServeMux()
	mux.HandleFunc("/debug/pprof/", pprof.Index)
	mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
  // 启动 http2 服务，golang http 启动时添加证书会自动转化为 http2 服务。
  // 将 Content-Type 为 application/grpc 请求转交给 grpc 即可。
	err := http.ListenAndServeTLS(
		addr,
		"ssl/server.pem",
		"ssl/server-key.pem",
		http.HandlerFunc(func(rw http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor == 2 && strings.Contains(r.Header.Get("Content-Type"), "application/grpc") {
			log.Println("call grpc service")
			s.ServeHTTP(rw, r)
		} else {
			mux.ServeHTTP(rw, r)
		}
	}))
	if err != nil {
		log.Fatalf("start server at %v: %v", addr, err)
	}
}
```



## grpc 请求断开处理
grpc 的请求没有自己设置请求的超时时间，而是将这部分的处理交给 golang 的 context 包。通过 context 的功能实现客户端的登录超时，请求超时。服务端代码：

```go
type server struct {
	pb.UnimplementedEchoServer
}

func (s *server) BidirectionalStreamingEcho(stream pb.Echo_BidirectionalStreamingEchoServer) error {
	// 该函数内是 stream 的整个生命周期，该函数退出后，stream 的上下文结束
	// 每个stream函数相互独立
	// 服务端的 stream 不能直接发起请求终止，但可以通过提前结束该函数，停止该 stream
	for {
		in, err := stream.Recv()
		if err != nil {
			fmt.Printf("server: error receiving from stream: %v\n", err)
			if err == io.EOF {
				return nil
			}
			return err
		}
		fmt.Printf("echoing message %q\n", in.Message)
		stream.Send(&pb.EchoResponse{Message: in.Message})
	}
}

func main() {
	lis, err := net.Listen("tcp", "127.0.0.1:10050")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	fmt.Printf("server listening at port %v\n", lis.Addr())
	s := grpc.NewServer()
	pb.RegisterEchoServer(s, &server{})
	s.Serve(lis)
}
```

客户端:

```go
func sendMessage(stream pb.Echo_BidirectionalStreamingEchoClient, msg string) error {
	fmt.Printf("sending message %q\n", msg)
	return stream.Send(&pb.EchoRequest{Message: msg})
}

func recvMessage(stream pb.Echo_BidirectionalStreamingEchoClient, wantErrCode codes.Code) {
	res, err := stream.Recv()
	if status.Code(err) != wantErrCode {
		log.Fatalf("stream.Recv() = %v, %v; want _, status.Code(err)=%v", res, err, wantErrCode)
	}
	if err != nil {
		fmt.Printf("stream.Recv() returned expected error %v\n", err)
		return
	}
	fmt.Printf("received message %q\n", res.Message)
}

func main() {
	addr := "127.0.0.1:10050"
	// 建立连接
	// 建立连接的 ctx 和请求的 ctx 是独立的
	conn, err := grpc.DialContext(context.Background(), addr, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()

	c := pb.NewEchoClient(conn)

	// Initiate the stream with a context that supports cancellation.
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	stream, err := c.BidirectionalStreamingEcho(ctx)
	if err != nil {
		log.Fatalf("error creating stream: %v", err)
	}

	// Send some test messages.
	if err := sendMessage(stream, "hello"); err != nil {
		log.Fatalf("error sending on stream: %v", err)
	}
	if err := sendMessage(stream, "world"); err != nil {
		log.Fatalf("error sending on stream: %v", err)
	}

	// Ensure the RPC is working.
	recvMessage(stream, codes.OK)
	recvMessage(stream, codes.OK)

	fmt.Println("cancelling context")
	cancel()

	// This Send may or may not return an error, depending on whether the
	// monitored context detects cancellation before the call is made.
	sendMessage(stream, "closed")

	// This Recv should never succeed.
	recvMessage(stream, codes.Canceled)
}
```



# GRPC 性能优化

虽然 grpc 的官方自诩是高性能的框架，但是 grpc 内部使用大量的反射，使得 grpc 在性能上并不算很好，所以还是有必要优化。grpc 的优化思路比较简单，不需要直接修改源码，只需要在 protoc 命令生成 golang 代码是，将 golang/protobuf 换成第三方的 [gogo/protobuf](https://github.com/gogo/protobuf) 。gogo库基于官方库开发，增加了很多的功能，包括：

- 快速的序列化和反序列化
- 更规范的Go数据结构
- goprotobuf兼容
- 可选择的产生一些辅助方法，减少使用中的代码输入
- 可以选择产生测试代码和benchmark代码
- 其它序列化格式

比如etcd、k8s、dgraph、docker swarmkit都使用它。基于速度和定制化的考虑，gogo有三种产生代码的方式

- `gofast`: 速度优先，不支持其它gogoprotobuf extensions。



```bash
go get github.com/gogo/protobuf/protoc-gen-gofast
protoc --gofast_out=. myproto.proto
```


- `gogofast`类似`gofast`,但是会导入gogoprotobuf
- `gogofaster`类似`gogofast`, 不会产生`XXX_unrecognized`指针字段，可以减少垃圾回收时间。
- `gogoslick`类似`gogofaster`,但是可以增加一些额外的方法`gostring`和`equal`等等。



```bash
go get github.com/gogo/protobuf/proto
go get github.com/gogo/protobuf/{binary} //protoc-gen-gogofast、protoc-gen-gogofaster 、protoc-gen-gogoslick 
go get github.com/gogo/protobuf/gogoproto
protoc -I=. -I=$GOPATH/src -I=$GOPATH/src/github.com/gogo/protobuf/protobuf --{binary}_out=. myproto.proto
```


- `protoc-gen-gogo`: 最快的速度，最多的可定制化

你可以通过扩展定制序列化: [扩展](https://github.com/gogo/protobuf/blob/master/extensions.md).

```bash
go get github.com/gogo/protobuf/proto
go get github.com/gogo/protobuf/jsonpb
go get github.com/gogo/protobuf/protoc-gen-gogo
go get github.com/gogo/protobuf/gogoproto
```

gogo同样支持grpc: `protoc --gofast_out=plugins=grpc:. my.proto`。同时还有 protobuf 对应的[教程](https://colobu.com/2019/10/03/protobuf-ultimate-tutorial-in-go/) 。



