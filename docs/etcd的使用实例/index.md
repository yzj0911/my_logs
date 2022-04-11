# etcd的使用实例


# etcd的使用实例

etcd有两个版本的接口，v2和v3，且两个版本不兼容，v2已经停止了支持，v3性能更好。

注意 ：etcdctl默认使用v2版本，如果想使用v3版本，可通过环境变量ETCDCTL_API=3进行设置

etcd 有如下的使用场景：

- 服务发现（Service Discovery）
- 消息发布与订阅
- 负载均衡
- 分布式通知与协调
- 分布式锁
- 分布式队列
- 集群监控于Leader竞选。


# 一、服务发现
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110140.png)

etcd 的常见使用场景之一就是服务发现。实现思路如下：先准备 etcd 服务端，服务端的程序在第一次启动之后会连接到 etcd 服务器并设置一个格式为 `ip:port` 的键值对，并绑定一个 lease。之后的服务端内部维护一个定时器，每隔一段时间就更新服务端注册中心的 lease 的 TTL。另外一个组件就是服务发现组件，discovery 会 watch 服务端的 key。每次该 key 变化时，discovery 就可以检测到时间并做出对应的操作。代码的实现如下：

```go
// server.go
package main

import (
	"context"
	"crypto/md5"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"github.com/coreos/etcd/clientv3"
	"github.com/coreos/etcd/etcdserver/api/v3rpc/rpctypes"
	"log"
	"net"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

var (
	prefix     = "register"
	client     *clientv3.Client
	stopSignal = make(chan struct{}, 1)
	srvKey     string
)

var (
	serv     = flag.String("name", "hello", "service name")
	port     = flag.Int("port", 30000, "service port")
	endpoint = flag.String("endpoints", "http://127.0.0.1:2379", "etcd endpoints")
)

type SvConfig struct {
	Name string `json:"name"`
	Host string `json:"host"`
	Port int    `json:"port"`
}

func Register(endpoints string, config *SvConfig, interval time.Duration, ttl int) error {
	// 解析服务端的值
	srvValue, _ := json.Marshal(config)
	srvKey = fmt.Sprintf("%s/%x", prefix, md5.Sum(srvValue))

	var err error
	client, err = clientv3.New(clientv3.Config{
		Endpoints:   strings.Split(endpoints, ","),
		DialTimeout: time.Second * 2,
	})
	if err != nil {
		return fmt.Errorf("register service failed: %v", err)
	}

	go func() {
		timer := time.NewTicker(interval)
		for {

			resp, _ := client.Grant(context.TODO(), int64(ttl))

			_, err = client.Get(context.TODO(), srvKey)
			if err != nil {
				// 捕获 key 不存在的场合
				if errors.Is(err, rpctypes.ErrKeyNotFound) {
					_, err = client.Put(context.TODO(), srvKey, string(srvValue), clientv3.WithLease(resp.ID))
					if err != nil {
						log.Printf("register service %s at %s:%d\n", config.Name, config.Host, config.Port)
					}
				}
			} else {
				// 如果key存在就更新ttl
				_, err = client.Put(context.TODO(), srvKey, string(srvValue), clientv3.WithLease(resp.ID))
			}
			select {
			case <-stopSignal:
				return
			case <-timer.C:
			}
		}
	}()

	return err
}

func Unregister() error {
	stopSignal <- struct{}{}
	stopSignal = make(chan struct{}, 1)
	_, err := client.Delete(context.TODO(), srvKey)
	return err
}

func main() {
	flag.Parse()

	// 绑定服务地址和端口
	lis, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", *port))
	if err != nil {
		panic(err)
	}

	config := &SvConfig{
		Name: *serv,
		Host: "127.0.0.1",
		Port: *port,
	}
	Register(*endpoint, config, time.Second*10, 15)

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT, syscall.SIGKILL, syscall.SIGHUP, syscall.SIGQUIT)
	go func() {
		<-ch
		Unregister()
		os.Exit(1)
	}()

	log.Printf("service %s start at %d", *serv, *port)
	// server todo
	for {
		lis.Accept()
	}
}

```

```go
// discovery.go
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"github.com/coreos/etcd/clientv3"
	"log"
	"net"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

var (
	prefix = "register"
	client *clientv3.Client
)

var (
	port     = flag.Int("port", 30001, "service port")
	endpoint = flag.String("endpoints", "http://127.0.0.1:2379", "etcd endpoints")
)

type SvConfig struct {
	Name string `json:"name"`
	Host string `json:"host"`
	Port int    `json:"port"`
}

func watcher() error {
	var err error
	client, err = clientv3.New(clientv3.Config{
		Endpoints:   strings.Split(*endpoint, ","),
		DialTimeout: time.Second * 3,
	})
	if err != nil {
		return fmt.Errorf("connect etcd cluster failed: %v", err.Error())
	}

	go func() {
		resp := client.Watch(context.TODO(), prefix, clientv3.WithPrefix())
		for ch := range resp {
			for _, event := range ch.Events {
				switch event.Type {
				case clientv3.EventTypePut:
					if event.IsCreate() {
						srv := parseSrv(event.Kv.Value)
						log.Printf("discovery service %s at %s:%d", srv.Name, srv.Host, srv.Port)
					}
				case clientv3.EventTypeDelete:
					log.Printf("delete service %s", event.Kv.Key)
				}
			}
		}
	}()

	return err
}

func parseSrv(text []byte) *SvConfig {
	svc := &SvConfig{}
	json.Unmarshal(text, &svc)
	return svc
}

func main() {
	flag.Parse()

	// 绑定服务地址和端口
	lis, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", *port))
	if err != nil {
		panic(err)
	}

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT, syscall.SIGKILL, syscall.SIGHUP, syscall.SIGQUIT)
	go func() {
		<-ch
		os.Exit(1)
	}()

	watcher()

	log.Printf("discovery start at %d", *port)
	// server todo
	for {
		lis.Accept()
	}
}
```


# 二、消息发布与订阅
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110205.png)
消息发布和订阅使用的场景也很多的。利用 etcd 的实现思路也很简单：只要消息的发布者向 etcd 发布一系列相同前缀的key，订阅者 watch 指定的前缀即可。代码如下：

```go
package main

import (
	"context"
	"flag"
	"fmt"
	"github.com/coreos/etcd/clientv3"
	"log"
	"strings"
	"time"
)

var (
	prefix = "/etcd"
	client   *clientv3.Client
	endponts = flag.String("endpoints", "http://127.0.0.1:2379", "etcd endpoints")
)

func publisher(client *clientv3.Client) {
	go func() {
		timer := time.NewTicker(time.Second)
		for range timer.C {
			now := time.Now()
			key := fmt.Sprintf("%s/%d", prefix, now.Second())
			value := now.String()
			// 可以在这里添加 key 的 lease
			// resp, _ := client.Grant(context.TODO(), 10)
			// client.Put(context.TODO(), key, value, clientv3.WithLease(resp.ID))
			client.Put(context.TODO(), key, value)
		}
	}()
}

func subscriber(client *clientv3.Client) {
	watcher := client.Watch(context.TODO(), prefix, clientv3.WithPrefix())
	for ch := range watcher {
		for _, e := range ch.Events {
			if e.IsCreate() {
				log.Printf("received %s => %s\n", e.Kv.Key, e.Kv.Value)
			}
		}
	}
}

func main() {
	flag.Parse()

	client, err := clientv3.New(clientv3.Config{
		Endpoints:            strings.Split(*endponts, ","),
		DialTimeout:          time.Second * 2,
	})
	if err != nil {
		log.Fatalln("connect etcd cluster failed: " + err.Error())
	}

	publisher(client)
	subscriber(client)

	select {
	//
	}
}
```


# 三、负载均衡
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110220.png)
etcd 可以配合 grpc 实现负载均衡的功能。可以在服务发现的基础上，利用 grpc 自带的 client 负载均衡实现。首先实现服务发现：

```go
// register.go
package balance

import (
	"fmt"
	"log"
	"strings"
	"time"

	"context"
	etcd3 "github.com/coreos/etcd/clientv3"
	"github.com/coreos/etcd/etcdserver/api/v3rpc/rpctypes"
)

// 服务的前缀
// 用这个来区分不同项目的服务
var Prefix = "etcd3_naming"
var client etcd3.Client
var serviceKey string

var stopSignal = make(chan bool, 1)

// 服务注册
func Register(name string, host string, port int, target string, interval time.Duration, ttl int) error {
	serviceValue := fmt.Sprintf("%s:%d", host, port)
	serviceKey = fmt.Sprintf("/%s/%s/%s", Prefix, name, serviceValue)

	// 解析 etcd 的 endpoints
	// 开启 etcd 客户端用于注册服务
	var err error
	client, err := etcd3.New(etcd3.Config{
		Endpoints: strings.Split(target, ","),
	})
	if err != nil {
		return fmt.Errorf("grpclb: create etcd3 client failed: %v", err)
	}

	go func() {
		// 启动一个定时器自动注册服务
		ticker := time.NewTicker(interval)
		for {
			// 在 etcd 中创建一个 lease 绑定服务的地址
			resp, _ := client.Grant(context.TODO(), int64(ttl))
			// 检测服务地址是否存在，若不存在就创建
			_, err := client.Get(context.Background(), serviceKey)
			if err != nil {
				if err == rpctypes.ErrKeyNotFound {
					// 服务地址不存在
					if _, err := client.Put(context.TODO(), serviceKey, serviceValue, etcd3.WithLease(resp.ID)); err != nil {
						log.Printf("grpclb: set service '%s' with ttl to etcd3 failed: %s", name, err.Error())
					}
				} else {
					log.Printf("grpclb: service '%s' connect to etcd3 failed: %s", name, err.Error())
				}
			} else {
				// 刷新服务地址 lease
				if _, err := client.Put(context.Background(), serviceKey, serviceValue, etcd3.WithLease(resp.ID)); err != nil {
					log.Printf("grpclb: refresh service '%s' with ttl to etcd3 failed: %s", name, err.Error())
				}
				//log.Panicln(serviceKey)
			}
			select {
			case <-stopSignal:
				return
			case <-ticker.C:
			}
		}
	}()

	return nil
}

// 删除服务注册信息
func UnRegister() error {
	stopSignal <- true
	// 获取 chan 之后马上留空，防止多个 UnRegister 造成死锁
	stopSignal = make(chan bool, 1)
	var err error
	if _, err := client.Delete(context.Background(), serviceKey); err != nil {
		log.Printf("grpclb: deregister '%s' failed: %s", serviceKey, err.Error())
	} else {
		log.Printf("grpclb: deregister '%s' ok.", serviceKey)
	}
	return err
}
```

```go
package balance

import (
	"fmt"

	"context"
	etcd3 "github.com/coreos/etcd/clientv3"
	"github.com/coreos/etcd/mvcc/mvccpb"
	"google.golang.org/grpc/naming"
)

// watcher is the implementaion of grpc.naming.Watcher
type watcher struct {
	re            *resolver // re: Etcd Resolver
	client        etcd3.Client
	isInitialized bool
}

// Close do nothing
func (w *watcher) Close() {
}

// Next to return the updates
func (w *watcher) Next() ([]*naming.Update, error) {
	// prefix is the etcd prefix/value to watch
	prefix := fmt.Sprintf("/%s/%s/", Prefix, w.re.serviceName)
	fmt.Println("prefix", prefix)
	// check if is initialized
	if !w.isInitialized {
		// query addresses from etcd
		w.isInitialized = true
		resp, err := w.client.Get(context.Background(), prefix, etcd3.WithPrefix())
		if err == nil {
			addrs := extractAddrs(resp)
			//if not empty, return the updates or watcher new dir
			if l := len(addrs); l != 0 {
				updates := make([]*naming.Update, l)
				for i := range addrs {
					updates[i] = &naming.Update{Op: naming.Add, Addr: addrs[i]}
				}
				return updates, nil
			}
		}
	}

	// generate etcd Watcher
	rch := w.client.Watch(context.Background(), prefix, etcd3.WithPrefix())
	for wresp := range rch {
		for _, ev := range wresp.Events {
			switch ev.Type {
			case mvccpb.PUT:
				return []*naming.Update{{Op: naming.Add, Addr: string(ev.Kv.Value)}}, nil
			case mvccpb.DELETE:
				return []*naming.Update{{Op: naming.Delete, Addr: string(ev.Kv.Value)}}, nil
			}
		}
	}
	return nil, nil
}

func extractAddrs(resp *etcd3.GetResponse) []string {
	addrs := []string{}

	if resp == nil || resp.Kvs == nil {
		return addrs
	}

	for i := range resp.Kvs {
		if v := resp.Kvs[i].Value; v != nil {
			addrs = append(addrs, string(v))
		}
	}

	return addrs
}
```

```go
// resolver.go
package balance

import (
	"errors"
	"fmt"
	"strings"

	etcd3 "github.com/coreos/etcd/clientv3"
	"google.golang.org/grpc/naming"
)

// resolver is the implementaion of grpc.naming.Resolver
type resolver struct {
	serviceName string // service name to resolve
}

// NewResolver return resolver with service name
func NewResolver(serviceName string) *resolver {
	return &resolver{serviceName: serviceName}
}

// Resolve to resolve the service from etcd, target is the dial address of etcd
// target example: "http://127.0.0.1:2379,http://127.0.0.1:12379,http://127.0.0.1:22379"
func (re *resolver) Resolve(target string) (naming.Watcher, error) {
	if re.serviceName == "" {
		return nil, errors.New("grpclb: no service name provided")
	}

	// generate etcd client
	client, err := etcd3.New(etcd3.Config{
		Endpoints: strings.Split(target, ","),
	})
	if err != nil {
		return nil, fmt.Errorf("grpclb: creat etcd3 client failed: %s", err.Error())
	}

	// Return watcher
	return &watcher{re: re, client: *client}, nil
}

```

实现服务发现和服务的解析之后，使用protobuf来定义服务的内容：

```protobuf
syntax = "proto3";

option java_multiple_files = true;
option java_package = "com.midea.jr.test.grpc";
option java_outer_classname = "HelloWorldProto";
option objc_class_prefix = "HLW";

package pb;

// The greeting service definition.
service Greeter {
    //   Sends a greeting
    rpc SayHello (HelloRequest) returns (HelloReply) {
    }
}

// The request message containing the user's name.
message HelloRequest {
    string name = 1;
}

// The response message containing the greetings
message HelloReply {
    string message = 1;
}
```

将proto文件编译成go代码：

```bash
# 需要先安装 protoc-gen-go  和 proto
# go get -u github.com/golang/protobuf/protoc-gen-go 
# go get -u github.com/golang/protobuf/proto
$ protoc -I ./pb --go_out=plugins=grpc:pb ./pb/helloworld.proto
```

服务端的代码如下：

```go
// server.go
package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"context"
	"google.golang.org/grpc"
	grpclb "xingyys.com/mysite/balance"
	"xingyys.com/mysite/pb"
)

var (
	serv = flag.String("service", "hello_service", "service name")
	port = flag.Int("port", 50001, "listening port")
	reg  = flag.String("reg", "http://127.0.0.1:2379", "register etcd address")
)

func main() {
	flag.Parse()

	// 绑定服务端的监听地址
	lis, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", *port))
	if err != nil {
		panic(err)
	}

	// 向 etcd 注册服务，指定检测周期为10s，生存周期为15s
	err = grpclb.Register(*serv, "127.0.0.1", *port, *reg, time.Second*10, 15)
	if err != nil {
		panic(err)
	}

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT, syscall.SIGKILL, syscall.SIGHUP, syscall.SIGQUIT)
	go func() {
		s := <-ch
		log.Printf("receive signal '%v'", s)
		grpclb.UnRegister()
		os.Exit(1)
	}()

	// 启动服务端
	log.Printf("starting hello service at %d", *port)
	s := grpc.NewServer()
	pb.RegisterGreeterServer(s, &server{})
	s.Serve(lis)
}

// server is used to implement helloworld.GreeterServer.
type server struct{}

// SayHello implements helloworld.GreeterServer
func (s *server) SayHello(ctx context.Context, in *pb.HelloRequest) (*pb.HelloReply, error) {
	fmt.Printf("%v: Receive is %s\n", time.Now(), in.Name)
	return &pb.HelloReply{Message: "Hello " + in.Name}, nil
}
```

负载均衡的代码下client中实现：

```go
// client.go
package main

import (
	"flag"
	"fmt"
	"time"

	"strconv"

	"context"
	"google.golang.org/grpc"
	grpclb "xingyys.com/mysite/balance"
	"xingyys.com/mysite/pb"
)

var (
	serv = flag.String("service", "hello_service", "service name")
	reg  = flag.String("reg", "http://127.0.0.1:2379", "register etcd address")
)

func main() {
	flag.Parse()
	fmt.Println("serv", *serv)
	r := grpclb.NewResolver(*serv)
	b := grpc.RoundRobin(r)

	ctx, _ := context.WithTimeout(context.Background(), 10*time.Second)
	conn, err := grpc.DialContext(ctx, *reg, grpc.WithInsecure(), grpc.WithBalancer(b))
	if err != nil {
		panic(err)
	}
	fmt.Println("conn...")

	ticker := time.NewTicker(1 * time.Second)
	for t := range ticker.C {
		client := pb.NewGreeterClient(conn)
		resp, err := client.SayHello(context.Background(), &pb.HelloRequest{Name: "world " + strconv.Itoa(t.Second())})
		if err == nil {
			fmt.Printf("%v: Reply is %s\n", t, resp.Message)
		} else {
			fmt.Println(err)
		}
	}
}
```


# 四、分布式通知与协调
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110244.png)
和消息发布与订阅相似，都是用到 etcd 的 watch 机制，通过注册与异步通知机制，实现分布式环境下不同系统之间的通知与协调，从而对数据变更做到实时处理。实现思路如下：不同的系统在 etcd 注册目录，并监控目录下 key 的变化，到检测到变化时，watcher 做出放映。

```go
package main

import (
	"context"
	"fmt"
	"github.com/coreos/etcd/clientv3"
	"log"
	"time"
)

func main() {
	client, err := clientv3.New(clientv3.Config{
		Endpoints:   []string{"192.168.10.10:2379"},
		DialTimeout: time.Second * 3,
	})
	if err != nil {
		log.Fatalln(err)
	}

	prefix := "/job"
	id := "test_job"
	key := fmt.Sprintf("%s/%s", prefix, id)
	go func() {
		timer := time.NewTicker(time.Millisecond * 10)
		i := 0
		for range timer.C {
			if i > 100 {
				return
			}

			if _, err := client.Put(context.TODO(), key, string(i)); err == nil {
				log.Printf("job process: %d%%", i)
			}

			i++
		}
	}()

	watcher := client.Watch(context.TODO(), key)
	for ch := range watcher {
		for _, e := range ch.Events {
			if e.Kv.Value[0] == 100 {
				log.Println("job Done!")
				return
			}
		}
	}
}
```


# 五、分布式锁
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110301.png)
因为etcd使用Raft算法保持了数据的强一致性，某次操作存储到集群中的值必然是全局一致的，所以很容易实现分布式锁。实现的思路：多个 session 同时使用开启事物抢占同一 key，最先抢到的 session 获得锁，其他 session 等待锁的释放。如果是 trylock，session 在抢不到 session 时不再等待直接报错。在 etcd clientv3的版本中，官方自带锁的实现，支持locks 和 trylock（需要 etcd v3.4.3）示例看 [这里](https://github.com/etcd-io/etcd/blob/master/clientv3/concurrency/example_mutex_test.go)


# 六、分布式队列
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110313.png)

etcd 分布式队列有两种实现方式，一种等待所有条件都满足后才开始执行任务。另一种是先入先出列队。第一种的思路就是在 watch 一个目录，当目录下存在必要的 key 时就进行对应操作。

```go
package main

import (
	"context"
	"fmt"
	"github.com/coreos/etcd/clientv3"
	"log"
	"math/rand"
	"time"
)

func random(max int) int {
	rand.Seed(time.Now().UnixNano())
	return rand.Intn(max)
}

func main() {
	client, _ := clientv3.New(clientv3.Config{
		Endpoints:   []string{"192.168.10.10:2379"},
		DialTimeout: time.Second * 2,
	})

	prefix := "/queue"

	client.Delete(context.TODO(), prefix, clientv3.WithPrefix())

	// 每隔1s，condition 变为 0 1 2 中的随机一个
	go func() {
		timer := time.NewTicker(time.Second * 1)
		key := prefix + "/1"
		for range timer.C {
			rd := random(3)
			client.Put(context.TODO(), key, fmt.Sprintf("%d", rd))
		}
	}()

	// 每隔2s，condition 变为 0 1 2 中的随机一个
	go func() {
		timer := time.NewTicker(time.Second * 1)
		key := prefix + "/2"
		for range timer.C {
			rd := random(3)
			client.Put(context.TODO(), key, fmt.Sprintf("%d", rd))
		}
	}()

	// 每隔3s，condition 变为 0 1 2 中的随机一个
	go func() {
		timer := time.NewTicker(time.Second * 1)
		key := prefix + "/3"
		for range timer.C {
			rd := random(3)
			client.Put(context.TODO(), key, fmt.Sprintf("%d", rd))
		}
	}()

	watcher := client.Watch(context.TODO(), prefix, clientv3.WithPrefix())
	for range watcher {
		// 满足以下条件是退出
		// /queue/1 = 0
		// /queue/2 = 2
		// /queue/3 = 1
		resp, _ := client.Get(context.TODO(), prefix, clientv3.WithRange(prefix+"/4"))
		fmt.Println(resp.Kvs)
		if string(resp.Kvs[0].Value[0]) == "0" &&
			string(resp.Kvs[1].Value[0]) == "2" &&
			string(resp.Kvs[2].Value[0]) == "1" {
			log.Println("Done!")
			return
		}
	}
}
```

第二种实现思路：

```go
package main

import (
	"context"
	"crypto/md5"
	"fmt"
	"github.com/coreos/etcd/clientv3"
	"time"
)

func main() {

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	client, _ := clientv3.New(clientv3.Config{
		Endpoints:   []string{"192.168.10.10:2379"},
		DialTimeout: time.Second * 2})

	prefix := "/queue"
	client.Delete(ctx, prefix, clientv3.WithPrefix())
	for i := 0; i < 10; i++ {
		key := fmt.Sprintf("%s/%x", prefix, md5.Sum([]byte(time.Now().String())))
		client.Put(ctx, key, string(i))
		fmt.Printf("key %s push queue\n", key)
	}

	fmt.Println("\n\n")

	ops := make([]clientv3.OpOption, 0)
	// 换成 clientv3.WithLastRev() 就是先进先出队列了
	ops = append(ops, clientv3.WithFirstRev()...)
	ops = append(ops, clientv3.WithPrefix())
	ops = append(ops, clientv3.WithLimit(1))
	for i := 0; i < 10; i++ {
		resp, _ := client.Get(context.TODO(), prefix, ops...)
		if resp.Count > 0 {
			key := string(resp.Kvs[0].Key)
			fmt.Printf("count %d => key %s pop queue\n", resp.Count, key)
			client.Delete(context.TODO(), key)
		}
		//fmt.Println(resp.Kvs)
	}
}
```


# 七、集群监控与Leader竞选。
通过etcd来进行监控实现起来非常简单并且实时性强。

1. Watcher机制，当某个节点消失或有变动时，Watcher会第一时间发现并告知用户。
1. 节点可以设置`TTL key`，比如每隔30s发送一次心跳使代表该机器存活的节点继续存在，否则节点消失。

　　这样就可以第一时间检测到各节点的健康状态，以完成集群的监控要求。
使用分布式锁，可以完成Leader竞选。　　这种场景通常是一些长时间CPU计算或者使用IO操作的机器，只需要竞选出的Leader计算或处理一次，就可以把结果复制给其他的Follower。从而避免重复劳动，节省计算资源。这个的经典场景是**搜索系统中建立全量索引**。如果每个机器都进行一遍索引的建立，不但耗时而且建立索引的一致性不能保证。通过在etcd的CAS机制同时创建一个节点，创建成功的机器作为Leader，进行索引计算，然后把计算结果分发到其它节点。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110336.png)

同样官方自带示例：详细看 [这里](https://github.com/etcd-io/etcd/blob/master/clientv3/concurrency/example_election_test.go)


# 八、etcd常用命令
## 查询数据

### 按key值查询

```etcdctl get name1```

```
name1
james
```

### 不显示key只限制values

```etcdctl get --print-value-only name1```

```
james
```

### 按key前缀查找

```etcdctl get --prefix name```
```
name1
james
name11
alice
name12
seli
name2
jetty
name3
tom
name4
cris
```
### 按key的字节排序的前缀查找 >=

```etcdctl get --from-key name2```
```
name2
jetty
name3
tom
name4
cris
```

### 按key的字节排序区间查找 <= value <

```etcdctl get name1 name3```
```
name1
james
name11
alice
name12
seli
name2
jetty
```

### 查找所有key
```etcdctl get --from-key ""```
```
avg_age
25
name1
james
name11
alice
name12
seli
name2
jetty
name3
tom
name4
cris
```
## 删除数据
### 删除key name11

```etcdctl del name11```

### 删除key name12时并返回被删除的键值对

```etcdctl del --prev-kv name12```
```
1
name12
seli
```
### 删除指定字节排序起始值后的key

```etcdctl del --prev-kv --from-key name3```
```
2
name3
tom
name4
cris
```
### 删除指定前缀的key

```etcdctl del --prev-kv --prefix name```
```
2
name1
james
name2
jetty
```
### 删除所有数据

```etcdctl del --prefix ""```
```
9
```
## 更新数据
### 直接用put即可

```etcdctl put avg_age 30```

```
etcdctl get --prefix ""

avg_age
30
```
