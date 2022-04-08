# 

# Docker容器和网络架构设计



# Docker容器和网络架构设计


## 常用的容器化技术

### Chroot
特点:
- 改变正在运行的进程和它的子进程根目录。
- 经chroot设置根目录的程序，不能够对这个指定根目录之外的文件进行访问和读取，也不能写操作。

原理:
- 修改PCB实现限制功能 (PCB: process control block)

缺点: 
- 隔离文件系统
- 但是无法限制 CPU, 内存, 网络端口号的命名空间

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210928202733.png)

### Jails
特点：
- 基于Chroot的操作系统层虚拟化技术。
- 只能访问某个部分的文件系统，但是FreeBSD jail机制限制了在软件监狱中运作的行程，不能够影响操作系统的其他部分

场景：
- 虚拟化
- 安全性
- 易维护

缺点:
- 使用复杂
- 隔离级别较弱

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210928202801.png)

出现沙盒概念

### Linux vserver / openVZ
特点:
- 类似Jails机制，可以对计算机系统上的资源（文件系统、网络地址、内存）进行分区
- Linux操作系统级虚拟化技术，它通过Linux内核补丁形式进行虚拟化、隔离、资源管理和状态检查

优点:
- 资源隔离性(CPU超卖，内存共享)

缺点:
- 隔离级别较弱

进一步强化沙盒概念。

### LXC
特点:
- linux 自带功能，几乎没有额外的性能损耗。
- 轻量级的 "虚拟化 "方法，同时运行多个虚拟单元。
- 容器是用内核控制组（cgroups）和内核命名空间来隔离的。

优势
- 通过容器隔离应用程序和操作系统
- 通过LXC实时管理资源的分配，提供近乎原生的性能。
- 通过cgroups控制网络接口和应用容器内的资源。

缺陷
- 所有LXC容器都使用相同的内核。
- 只能在Linux操作系统运行。
- LXC 并不安全，安全性取决于主机系统。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210928203455.png)

### cgroup 和 namespace
Cgroups:
- 用于限制和隔离一组进程对系统资源的使用
- 对不同资源的具体管理是由各个子系统分工完成的

Namespace:
- 内核全局资源的封装
- 每个namespace是一份独立的资源
- 不同进程在各自namespace中对同一种资源的使用互不干扰
- 常用的namespace有IPC、Network、Mount、PID、User和UTC     

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210928204249.png)

## docker 的架构和原理

容器技术的目标
- 提高系统资源利用率
- 提高进程运行稳定性

docker 之前的解决方案: 虚拟化解决方案
- 软件虚拟化
- 硬件虚拟化

虚拟化方案提高了进程稳定性，一定程度提高了资源利用率。但仍然有很大程度的资源浪费(虚拟化成本)

容器化解决方案:在操作系统层面实现资源隔离
- OpenVZ
- LXC
- Process Container(cgroups)

均衡了资源利用率和稳定性。 稳定性比虚拟化差，但资源利用率比虚拟化高，适合分布式环境。

## Docker 网络架构和原理

### 网络基础知识
Lan/VLan/VXLan:
- LAN (Local Area Network)本地局域网
- VLAN(Virtual Local Area Network)虚拟本地局域网
- VXLAN(Virtual eXtensible Local Area Network) 在一套物理网络设备上虚拟出多个二层网络

VXLAN:
- VLAN ID数量限制
- 交换机MAC地址表限制
- 灵活的虚机部署和部署
- 复用网络链路

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210928220632.png)

桥接:
- 从一个网卡设备发出的以太帧，原封不动地到达另外一个网卡设备。
- 将多个广播域组合成一个广播域，在链路层允许设备互联。

桥接与路由的区别:
1. 分割广播域
- 桥接无法控制广播在不同物理接口之间的穿梭。广播嘈杂，对主机的干扰程度严重。
- 路由可以将某些主机放在一个广播域，将另外一些主机放在另外的广播域。

2. 控制网络流量
- 不同协议类型的物理接口，只能使用路由。
- 二层封装方式不一样，桥接无法解析数据。路由器可以替换二层数据帧

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210928220917.png)

### docker 跨主机互访方案
- Bridge
- Host
- Overlay
- Flannel


