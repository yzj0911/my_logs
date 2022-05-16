---
title: "Redis"
date: 2022-05-09T13:23:30+08:00
draft: true
tags: ["面试"]
series: [""]
categories: ["面试"]
---

# redis
简介：Redis ，全称 Remote Dictionary Server ，是一个基于内存的高性能 Key-Value 数据库。

脚本自动安装任意版本 sh redis-install.sh 4.0.10
``` bash 
#! /usr/bin/bash
##redis任何版本全程自动化源码编译安装
##用法：sh redis-install.sh 4.0.10 （后面跟的是你需要的版本号，需要什么版本就写什么版本），我这里安装的4.0.10
version=$1
usage(){
echo "usage: $0 version"
}

if [ $# -ne 1 ]
then
usage
exit -1
fi

#Redis安装包下载
cd /usr/local/src
if [ ! -f redis-${version}.tar.gz ]
then
curl -o /usr/local/src/redis-${version}.tar.gz http://download.redis.io/releases/redis-${version}.tar.gz
fi

#Redis依赖包安装
yum clean all
yum makecache fast
yum -y install gcc gcc-c++ tcl

#编译Redis所需要的gcc
yum -y install centos-release-scl
yum -y install devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-binutils
source /opt/rh/devtoolset-9/enable
echo "source /opt/rh/devtoolset-9/enable" >>/etc/profile
gcc --version

##内系统参数核优化
cat >> /etc/rc.d/rc.local << "EOF"

##关闭Linux的THP（内存管理系统）通过使用更大的内存页面，来减少具有大量内存的计算机上的TLB的开销
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]
then
echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi

if [ -f /sys/kernel/mm/transparent_hugepage/defrag ]
then
echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF
chmod u+x /etc/rc.d/rc.local

if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]
then
echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi

if [ -f /sys/kernel/mm/transparent_hugepage/defrag ]
then
echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

cat >> /etc/sysctl.conf << "EOF"

#Linux系统内核参数优化
net.core.somaxconn = 2048
net.ipv4.tcp_max_syn_backlog = 2048
vm.overcommit_memory = 1
EOF
sysctl -p

cat > /etc/security/limits.conf << "EOF"
root soft nofile 65535
root hard nofile 65535
* soft nofile 65535
* hard nofile 65535
EOF

#Redis编译安装
cd /usr/local/src
tar -zxvf redis-${version}.tar.gz
cd /usr/local/src/redis-${version}
make
make PREFIX=/usr/local/redis install

#Redis基础配置
mkdir -p /usr/local/redis/{etc,logs,data}
egrep -v "^$|^#" /usr/local/src/redis-${version}/redis.conf > /usr/local/redis/etc/redis.conf
#sed -i "s/bind 127.0.0.1/bind 0.0.0.0/g" /usr/local/redis/etc/redis.conf
sed -i "s/protected-mode yes/protected-mode no/g" /usr/local/redis/etc/redis.conf
sed -i "s/daemonize no/daemonize yes/g" /usr/local/redis/etc/redis.conf
sed -i "s/pidfile \/var\/run\/redis_6379.pid/pidfile \/usr\/local\/redis\/redis.pid/g" /usr/local/redis/etc/redis.conf
sed -i "s/dir \.\//dir \/usr\/local\/redis\/data/g" /usr/local/redis/etc/redis.conf
sed -i "s/logfile \"\"/logfile \"\/usr\/local\/redis\/logs\/redis.log\"/g" /usr/local/redis/etc/redis.conf
sed -i "s/dbfilename dump.rdb/dbfilename dump.rdb/g" /usr/local/redis/etc/redis.conf
sed -i "s/appendfilename \"appendonly.aof\"/appendfilename \"appendonly.aof\"/g" /usr/local/redis/etc/redis.conf

#PATH配置
echo "export PATH=${PATH}:/usr/local/redis/bin" >>/etc/profile
source /etc/profile
#启动redis服务
/usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf
#查看redis监听端口
netstat -tanp|grep redis
```



## Redis 有哪些数据结构？
如果你是 ```Redis``` 普通玩家，可能你的回答是如下五种数据结构：

- 字符串 String
- 字典 Hash
- 列表 List
- 集合 Set
- 有序集合 SortedSet

如果你是 Redis 中级玩家，还需要加上下面几种数据结构：

- HyperLogLog
- Geo
- Bitmap

如果你是 Redis 高端玩家，你可能玩过 Redis Module ，可以再加上下面几种数据结构：

- BloomFilter
- RedisSearch
- Redis-ML
- JSON

另外，在 Redis 5.0 增加了 Stream 功能，一个新的强大的支持多播的可持久化的消息队列，提供类似 Kafka 的功能。



##  Redis 的线程模型
redis 内部使用文件事件处理器 file event handler，这个文件事件处理器是单线程的，所以 Redis 才叫做单线程的模型。它采用 IO 多路复用机制同时监听多个 Socket，根据 Socket 上的事件来选择对应的事件处理器进行处理。

文件事件处理器的结构包含 4 个部分：

- 多个 Socket 。
- IO 多路复用程序。
- 文件事件分派器。
- 事件处理器（连接应答处理器、命令请求处理器、命令回复处理器）。

多个 Socket 可能会并发产生不同的操作，每个操作对应不同的文件事件，但是 IO 多路复用程序会监听多个 socket，会将 socket 产生的事件放入队列中排队，事件分派器每次从队列中取出一个事件，把该事件交给对应的事件处理器进行处理。

来看客户端与 redis 的一次通信过程：
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20200509Redis1.png)

### redis-single-thread-model

客户端 ```Socket01``` 向 ```Redis``` 的 ```Server Socket``` 请求建立连接，此时 ```Server Socket``` 会产生一个 ```AE_READABLE``` 事件，IO 多路复用程序监听到 ```server socket``` 产生的事件后，将该事件压入队列中。文件事件分派器从队列中获取该事件，交给连接应答处理器。连接应答处理器会创建一个能与客户端通信的 ```Socket01```，并将该 ```Socket01``` 的 ```AE_READABLE ```事件与命令请求处理器关联。

假设此时客户端发送了一个 ```set key value``` 请求，此时 ```Redis``` 中的 ```Socket01``` 会产生 AE_READABLE 事件，IO 多路复用程序将事件压入队列，此时事件分派器从队列中获取到该事件，由于前面 ```Socket01``` 的 AE_READABLE 事件已经与命令请求处理器关联，因此事件分派器将事件交给命令请求处理器来处理。命令请求处理器读取 ```Scket01``` 的 ```set key value``` 并在自己内存中完成 set key value 的设置。操作完成后，它会将 ```Scket01``` 的 ```AE_WRITABLE``` 事件与令回复处理器关联。

如果此时客户端准备好接收返回结果了，那么 ```Redis``` 中的 ```Socket01``` 会产生一个 AE_WRITABLE 事件，同样压入队列中，事件分派器找到相关联的命令回复处理器，由命令回复处理器对 ```socket01``` 输入本次操作的一个结果，比如 ok，之后解除 ```Socket01``` 的 AE_WRITABLE 事件与命令回复处理器的关联。
这样便完成了一次通信。


----
##  Redis 单线程模型也能效率这么高？

1. C 语言实现。

    我们都知道，C 语言的执行速度非常快。

2. 纯内存操作。

    Redis 为了达到最快的读写速度，将数据都读到内存中，并通过异步的方式将数据写入磁盘。所以 Redis 具有快速和数据持久化的特征。

    如果不将数据放在内存中，磁盘 I/O 速度为严重影响 Redis 的性能。

3. 基于非阻塞的 IO 多路复用机制。

4. 单线程，避免了多线程的频繁上下文切换问题。

    Redis 利用队列技术，将并发访问变为串行访问，消除了传统数据库串行控制的开销。

    实际上，Redis 4.0 开始，也开始有了一些异步线程，用于处理一些耗时操作。例如说，异步线程，实现惰性删除（解决大 KEY 删除，阻塞主线程）和异步 AOF （解决磁盘 IO 紧张时，fsync 执行一次很慢）等等。

5. 丰富的数据结构。

    Redis 全程使用 hash 结构，读取速度快，还有一些特殊的数据结构，对数据存储进行了优化。例如，压缩表，对短数据进行压缩存储；再再如，跳表，使用有序的数据结构加快读取的速度。
    也因为 Redis 是单线程的，所以可以实现丰富的数据结构，无需考虑并发的问题。

----


##  Redis 是单线程的，如何提高多核 CPU 的利用率？

可以在同一个服务器部署多个 Redis 的实例，并把他们当作不同的服务器来使用，在某些时候，无论如何一个服务器是不够的， 所以，如果你想使用多个 CPU ，你可以考虑一下分区。

----

## Redis 有几种持久化方式？
Redis 提供了两种方式，实现数据的持久化到硬盘。

- 1、【全量】```RDB``` 持久化，是指在指定的时间间隔内将内存中的数据集快照写入磁盘。实际操作过程是，fork 一个子进程，先将数据集写入临时文件，写入成功后，再替换之前的文件，用二进制压缩存储。
- 2、【增量】```AOF```持久化，以日志的形式记录服务器所处理的每一个写、删除操作，查询操作不会记录，以文本的方式记录，可以打开文件看到详细的操作记录。
---
## 有哪几种数据“淘汰”策略？


Redis 内存数据集大小上升到一定大小的时候，就会进行数据淘汰策略。

Redis 提供了 6 种数据淘汰策略：

- volatile-lru
- volatile-ttl
- volatile-random
- allkeys-lru
- allkeys-random
- 【默认策略】no-enviction

具体的每种数据淘汰策略的定义，和如何选择讨论策略，可见 《Redis实战（二） 内存淘汰机制》 。

在 Redis 4.0 后，基于 LFU（Least Frequently Used）最近最少使用算法，增加了 2 种淘汰策略：

- volatile-lfu
- allkeys-lfu

🦅 Redis LRU 算法

另外，Redis 的 LRU 算法，并不是一个严格的 LRU 实现。这意味着 Redis 不能选择最佳候选键来回收，也就是最久未被访问的那些键。相反，Redis 会尝试执行一个近似的 LRU 算法，通过采样一小部分键，然后在采样键中回收最适合(拥有最久未被访问时间)的那个。

Redis 没有使用真正实现严格的 LRU 算是的原因是，因为消耗更多的内存。然而对于使用 Redis 的应用来说，使用近似的 LRU 算法，事实上是等价的。

---
## 理解回收进程如何工作是非常重要的：

- 一个客户端运行了新的写命令，添加了新的数据。
- Redis 检查内存使用情况，如果大于 maxmemory 的限制, 则根据设定好的策略进行回收。
- Redis 执行新命令。

所以我们不断地穿越内存限制的边界，通过不断达到边界然后不断地回收回到边界以下（跌宕起伏）。

---

## 如果大量的 key 过期时间设置的过于集中，到过期的那个时间点，Redis可能会出现短暂的卡顿现象。

1. 一般需要在时间上加一个随机值，使得过期时间分散一些。

2. 是调大 hz 参数，每次过期的 key 更多，从而最终达到避免一次过期过多。

    这个定期的频率，由配置文件中的 hz 参数决定，代表了一秒钟内，后台任务期望被调用的次数。Redis 3.0.0 中的默认值是 10 ，代表每秒钟调用 10 次后台任务。

    hz 调大将会提高 Redis 主动淘汰的频率，如果你的 Redis 存储中包含很多冷数据占用内存过大的话，可以考虑将这个值调大，但 Redis 作者建议这个值不要超过 100 。我们实际线上将这个值调大到 100 ，观察到 CPU 会增加 2% 左右，但对冷数据的内存释放速度确实有明显的提高（通过观察 keyspace 个数和 used_memory 大小）。

---
