---
title: "Go 结合 etcd"
date: 2021-12-03T10:17:16+08:00
draft: false
---


# Go 结合 etcd


关于 etcd 的安装和介绍看 [这里](https://www.yuque.com/xingyys/szknb5/at7lql) 。官方的实例可以看 [这里](https://github.com/etcd-io/etcd/tree/master/clientv3)

# 一、连接
首先是关于 golang 如何连接 etcd ，先是简单的连接。

```go
package main

import (
	"github.com/coreos/etcd/clientv3"
	"log"
	"time"
)

func connect()  {
	cli, err := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints:            []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout:          time.Second * 3,
	})
	if err != nil {
		log.Fatal("connect etcd cluster: " + err.Error())
	}
	cli.Close()
}
```

还有带 https 和 开启用户验证的连接

```bash
func connectTlsAuth() {

	tlsInfo := transport.TLSInfo{
		CertFile:      "/tmp/cert.pem",
		KeyFile:       "/tmp/key.pem",
		TrustedCAFile: "/tmp/ca.pem",
	}
	tlsConfig, err := tlsInfo.ClientConfig()
	if err != nil {
		log.Fatal("parse tls config file: " + err.Error())
	}

	cli, err := clientv3.New(clientv3.Config{
		Endpoints:   []string{"192.168.10.10:2379"},
		DialTimeout: time.Second * 3,
		TLS:         tlsConfig,
		Username:    "root",
		Password:    "root",
	})

	if err != nil {
		log.Fatal("connect etcd cluster: " + err.Error())
	}
	cli.Close()
}
```


# 二、KV 操作

## 2.1 简单的 curd
在连接基础上，接下来就可以对key做操作了。对key做 curd

```go
func kv() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()
	
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	// etcdctl put foo 1
	_, err := cli.Put(ctx, "foo", "1")
	if err != nil {
		log.Fatal("put key:" + err.Error())
	}
	
	// etcdctl get foo --prefix
    // 带参数的请求
	resp, err := cli.Get(ctx, "foo", clientv3.WithPrefix())
	if err != nil {
		log.Fatal("get key: " + err.Error())
	}
	for _, v := range resp.Kvs {
		log.Printf("get %s => %s\n", v.Key, string(v.Value))
	}
	
	kvcli := clientv3.NewKV(cli)
	// etcdctl del foo
	_, err = kvcli.Delete(ctx, "foo")
	if err != nil {
		log.Fatal("delete key: " + err.Error())
	}
}
```


## 2.2 事务
使用事务如下：

```go
func txn() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	kvc := clientv3.NewKV(cli)

	_, err := kvc.Put(ctx, "foo", "xyz")
	if err != nil {
		log.Fatal("put key: " + err.Error())
	}

	_, err = kvc.Txn(ctx).
		// txn value comparisons are lexical
		If(clientv3.Compare(clientv3.Value("foo"), ">", "abc")).
		// the "Then" runs, since "xyz" > "abc"
		Then(clientv3.OpPut("foo", "XYZ")).
		// the "Else" does not run
		Else(clientv3.OpPut("foo", "ABC")).
		Commit()
	if err != nil {
		log.Fatal("run txn: " + err.Error())
	}
}
```


## 2.3 批量操作
批量指定操作

```go
func do() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	ops := []clientv3.Op{
		clientv3.OpPut("key1", "123"),
		clientv3.OpGet("key1"),
		clientv3.OpPut("key2", "456"),
	}
	
	for _, op := range ops {
		if _, err := cli.Do(ctx, op); err != nil {
			log.Fatal(err.Error())
		}
	}
}
```


## 2.3 watch
监视key

```go
func watch() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() {
		timer := time.NewTicker(time.Second)
		for {
			select {
			case <-timer.C:
				// change foo value every second
				_, _ = cli.Put(context.TODO(), "foo", time.Now().String())
				_, _ = cli.Put(context.TODO(), "foo1", time.Now().String())
				_, _ = cli.Put(context.TODO(), "foo2", time.Now().String())
				_, _ = cli.Put(context.TODO(), "foo3", time.Now().String())
				_, _ = cli.Put(context.TODO(), "foo4", time.Now().String())
			}
		}
	}()

	//rch := cli.Watch(ctx, "foo")
	rch := cli.Watch(ctx, "foo", clientv3.WithPrefix())
	//rch := cli.Watch(ctx, "foo", clientv3.WithRange("foo4"))
	for wresp := range rch {
		for _, ev := range wresp.Events {
			fmt.Printf("%s %q: %q\n", ev.Type, ev.Kv.Key, ev.Kv.Value)
		}
	}
}
```

```go
func watchWithProcessNotify() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	rch := cli.Watch(ctx, "foo", clientv3.WithProgressNotify())
	wresp := <- rch
	fmt.Printf("wresp.Header.Revision: %d\n", wresp.Header.Revision)
	fmt.Println("wresp.IsProgressNotify:", wresp.IsProgressNotify())
}
```


# 三、lease

## 2.1 创建 lease

```go
func grant() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// etcdctl lease grant 5
	// grant lease 5s
	resp, err := cli.Grant(ctx, 5)
	if err != nil {
		log.Fatal("grant lease: " + err.Error())
	}

	// after 5 seconds, the key 'foo' will be removed
	_, err = cli.Put(ctx, "foo", "bar", clientv3.WithLease(resp.ID))
	if err != nil {
		log.Fatal("put key with lease: " + err.Error())
	}
}
```


## 2.2 删除 lease

```go
func revoke() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	resp, err := cli.Grant(ctx, 5)
	if err != nil {
		log.Fatal("grant lease: " + err.Error())
	}

	_, err = cli.Put(ctx, "foo", "bar", clientv3.WithLease(resp.ID))
	if err != nil {
		log.Fatal(err)
	}

	// revoking lease expires the key attached to its lease ID
	_, err = cli.Revoke(ctx, resp.ID)
	if err != nil {
		log.Fatal(err)
	}
}
```


## 2.3 续租

```go
func keepAlive() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	resp, err := cli.Grant(ctx, 5)
	if err != nil {
		log.Fatal("grant lease: " + err.Error())
	}

	_, err = cli.Put(ctx, "foo", "bar", clientv3.WithLease(resp.ID))
	if err != nil {
		log.Fatal(err)
	}

	ch, err := cli.KeepAlive(ctx, resp.ID)
	if err != nil {
		log.Fatal(err.Error())
	}

	ka := <- ch
	fmt.Println("ttl:", ka.TTL)

    // 官方提示：多数情况下使用 KeepAlive 来代替 KeepAliveOnce
	kaa, err := cli.KeepAliveOnce(ctx, resp.ID)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("ttl:", kaa.TTL)
}
```


## 2.4 查询 lease

```go
func leases() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	_, err := cli.Grant(ctx, 5)
	if err != nil {
		log.Fatal("grant lease: " + err.Error())
	}

	_, err = cli.Grant(ctx, 10)
	if err != nil {
		log.Fatal("grant lease: " + err.Error())
	}

	_, err = cli.Grant(ctx, 15)
	if err != nil {
		log.Fatal("grant lease: " + err.Error())
	}

	resp, err := cli.Lease.Leases(ctx)
	if err != nil {
		log.Fatal(err)
	}

	for _, lease := range resp.Leases {
		ttl, err := cli.Lease.TimeToLive(ctx, lease.ID, clientv3.WithAttachedKeys())
		if err == nil {
			fmt.Printf("lease: %d, ttl: %d, grantedTTL: %d\n", ttl.ID, ttl.TTL, ttl.GrantedTTL)
		}
	}
}
```


# 四、访问控制

```go
func auth() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	auth := clientv3.NewAuth(cli)

	// create role
	if _, err := auth.RoleAdd(ctx, "root"); err != nil {
		log.Fatal(err)
	}

	// create role
	if _, err := auth.UserAdd(ctx, "root", "123"); err != nil {
		log.Fatal(err)
	}

	// grant role root to user root
	if _, err := auth.UserGrantRole(ctx, "root", "root"); err != nil {
		log.Fatal(err)
	}
	if _, err := auth.UserChangePassword(ctx, "root", "123"); err != nil {
		log.Fatal(err)
	}

	if _, err := auth.RoleAdd(ctx, "guest"); err != nil {
		log.Fatal(err)
	}
	if _, err := auth.UserAdd(ctx, "xingyys", ""); err != nil {
		log.Fatal(err)
	}
	if _, err := auth.UserGrantRole(ctx, "xingyys", "guest"); err != nil {
		log.Fatal(err)
	}
	// 不知道为什么，需要在grant后更新密码
	// 否则密码无效
	if _, err := auth.UserChangePassword(ctx, "xingyys", "123"); err != nil {
		log.Fatal(err)
	}

    // 添加指定key的访问权限
    // read, write, readwrite
	if _, err := auth.RoleGrantPermission(ctx,
		"guest",
		"foo",
		"zoo",
		clientv3.PermissionType(clientv3.PermReadWrite)); err != nil {
		log.Fatal(err)
	}

	if _, err := auth.AuthEnable(ctx); err != nil {
		log.Fatal(err)
	}


	authCli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
		Username: "xingyys",
		Password: "123",
	})
	defer authCli.Close()

	_, _ = authCli.Put(ctx, "foo", "1")
	resp, _ := authCli.Get(ctx, "foo")
	for _, v := range resp.Kvs {
		log.Printf("%s => %q\n", v.Key, v.Value)
	}

	_, err := authCli.Txn(ctx).
		If(clientv3.Compare(clientv3.Value("zoo1"), ">", "abc")).
		Then(clientv3.OpPut("zoo1", "XYZ")).
		Else(clientv3.OpPut("zoo1", "ABC")).
		Commit()
	log.Println(err)
}
```


# 五、集群

```go
func member() {
	cli, _ := clientv3.New(clientv3.Config{
		// etcd 集群的地址集合
		Endpoints: []string{"192.168.10.10:2379"},
		// 请求超时时间
		DialTimeout: time.Second * 3,
	})
	defer cli.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cluster := clientv3.NewCluster(cli)
	resp, err := cluster.MemberList(ctx)
	if err != nil {
		log.Fatal(err)
	}

	for _, member := range resp.Members {
		fmt.Printf("ID: %d | Name: %s | ClientURL: %q | PeerURL: %q\n",
			member.ID,
			member.Name,
			member.ClientURLs,
			member.PeerURLs)
	}

	//_, _ = cluster.MemberAdd(ctx, []string{"192.168.10.10:2370", "192.168.10.11:2379"})
	//_, _ = cluster.MemberRemove(ctx, // id)
	//_, _ = cluster.MemberUpdate(ctx, // id, // peer)
}
```


# 六、并发

## 6.1 锁

```go
func lock() {
	cli, err := clientv3.New(clientv3.Config{
		Endpoints: []string{"192.168.10.10:2379"},
	})
	if err != nil {
		log.Fatal(err)
	}
	defer cli.Close()

	// 注册session
	s1, err := concurrency.NewSession(cli)
	if err != nil {
		log.Fatal(err)
	}
	defer s1.Close()
	m1 := concurrency.NewMutex(s1, "/lock")

	s2, err := concurrency.NewSession(cli)
	if err != nil {
		log.Fatal(err)
	}
	defer s2.Close()
	m2 := concurrency.NewMutex(s2, "/lock")

	// acquired lock for s1
	if err := m1.Lock(context.TODO()); err != nil {
		log.Fatal(err)
	}
	fmt.Println("acquired lock for s1")

	m2Locked := make(chan struct{})
	go func() {
		defer close(m2Locked)
		// wait util s1 is locks /lock
		if err := m2.Lock(context.TODO()); err != nil {
			log.Fatal(err)
		}
	}()

	if err := m1.Unlock(context.TODO()); err != nil {
		log.Fatal(err)
	}
	fmt.Println("release lock for s1")

	<-m2Locked
	fmt.Println("acquired lock for s2")
}

func tryLock() {
	cli, err := clientv3.New(clientv3.Config{
		Endpoints: []string{"192.168.10.10:2379"},
	})
	if err != nil {
		log.Fatal(err)
	}
	defer cli.Close()

	// 注册session
	s1, err := concurrency.NewSession(cli)
	if err != nil {
		log.Fatal(err)
	}
	defer s1.Close()
	m1 := concurrency.NewMutex(s1, "/lock")

	s2, err := concurrency.NewSession(cli)
	if err != nil {
		log.Fatal(err)
	}
	defer s2.Close()
	m2 := concurrency.NewMutex(s2, "/lock")

	// acquire lock for s1
	if err = m1.Lock(context.TODO()); err != nil {
		log.Fatal(err)
	}
	fmt.Println("acquired lock for s1")

	if err = m2.TryLock(context.TODO()); err == nil {
		log.Fatal("should not acquire lock")
	}
	if err == concurrency.ErrLocked {
		fmt.Println("cannot acquire lock for s2, as already locked in another session")
	}

	if err = m1.Unlock(context.TODO()); err != nil {
		log.Fatal(err)
	}
	fmt.Println("released lock for s1")
	if err = m2.TryLock(context.TODO()); err != nil {
		log.Fatal(err)
	}
	fmt.Println("acquired lock for s2")
}
```


## 6.2 领导选举

```go
func election() {
	cli, err := clientv3.New(clientv3.Config{Endpoints: []string{"192.168.10.10:2379"}})
	if err != nil {
		log.Fatal(err)
	}
	defer cli.Close()

	// create two separate sessions for election competition
	s1, err := concurrency.NewSession(cli)
	if err != nil {
		log.Fatal(err)
	}
	defer s1.Close()
	e1 := concurrency.NewElection(s1, "/my-election/")

	s2, err := concurrency.NewSession(cli)
	if err != nil {
		log.Fatal(err)
	}
	defer s2.Close()
	e2 := concurrency.NewElection(s2, "/my-election/")

	// create competing candidates, with e1 initially losing to e2
	var wg sync.WaitGroup
	wg.Add(2)
	electc := make(chan *concurrency.Election, 2)
	go func() {
		defer wg.Done()
		// delay candidacy so e2 wins first
		time.Sleep(3 * time.Second)
		if err := e1.Campaign(context.Background(), "e1"); err != nil {
			log.Fatal(err)
		}
		electc <- e1
	}()
	go func() {
		defer wg.Done()
		if err := e2.Campaign(context.Background(), "e2"); err != nil {
			log.Fatal(err)
		}
		electc <- e2
	}()

	cctx, cancel := context.WithCancel(context.TODO())
	defer cancel()

	e := <-electc
	fmt.Println("completed first election with", string((<-e.Observe(cctx)).Kvs[0].Value))

	// resign so next candidate can be elected
	if err := e.Resign(context.TODO()); err != nil {
		log.Fatal(err)
	}

	e = <-electc
	fmt.Println("completed second election with", string((<-e.Observe(cctx)).Kvs[0].Value))

	wg.Wait()
}
```


## 6.3 软件事务内存

```go
func stm() {
	cli, err := clientv3.New(clientv3.Config{Endpoints: []string{"192.168.10.10:2379"}})
	if err != nil {
		log.Fatal(err)
	}
	defer cli.Close()

	// set up "accounts"
	totalAccounts := 5
	for i := 0; i < totalAccounts; i++ {
		k := fmt.Sprintf("accts/%d", i)
		if _, err = cli.Put(context.TODO(), k, "100"); err != nil {
			log.Fatal(err)
		}
	}

	exchange := func(stm concurrency.STM) error {
		from, to := rand.Intn(totalAccounts), rand.Intn(totalAccounts)
		if from == to {
			// nothing to do
			return nil
		}
		// read values
		fromK, toK := fmt.Sprintf("accts/%d", from), fmt.Sprintf("accts/%d", to)
		fromV, toV := stm.Get(fromK), stm.Get(toK)
		fromInt, toInt := 0, 0
		fmt.Sscanf(fromV, "%d", &fromInt)
		fmt.Sscanf(toV, "%d", &toInt)

		// transfer amount
		xfer := fromInt / 2
		fromInt, toInt = fromInt-xfer, toInt+xfer

		// write back
		stm.Put(fromK, fmt.Sprintf("%d", fromInt))
		stm.Put(toK, fmt.Sprintf("%d", toInt))
		return nil
	}

	// concurrently exchange values between accounts
	var wg sync.WaitGroup
	wg.Add(10)
	for i := 0; i < 10; i++ {
		go func() {
			defer wg.Done()
			if _, serr := concurrency.NewSTM(cli, exchange); serr != nil {
				log.Fatal(serr)
			}
		}()
	}
	wg.Wait()

	// confirm account sum matches sum from beginning.
	sum := 0
	accts, err := cli.Get(context.TODO(), "accts/", clientv3.WithPrefix())
	if err != nil {
		log.Fatal(err)
	}
	for _, kv := range accts.Kvs {
		v := 0
		fmt.Sscanf(string(kv.Value), "%d", &v)
		sum += v
	}

	fmt.Println("account sum is", sum)
}
```


