# CentOS下kvm安装


# CentOS下kvm安装


> 注：运行kvm保证机器支持虚拟化且在bios中开启。

# 准备工作
## 清除iptables规则
```bash
# CentOS6
service iptables stop; service iptables save
# CentOS7
systemctl stop firewalld
```
## 关闭selinux
```bash
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0
```

## 检测系统是否支持虚拟化
```bash
grep -Ei 'vmx|svm' /proc/cpuinfo
```
如果有输出内容，则支持，其中intel cpu支持会有vmx，amd cpu支持会有svm
# 安装
## 执行安装命令
```bash
yum install -y kvm virt-*  libvirt  bridge-utils qemu-img
```
说明：
- kvm:软件包中含有KVM内核模块，它在默认linux内核中提供kvm管理程序
- libvirt:安装虚拟机管理工具，使用virsh等命令来管理和控制虚拟机。
- bridge-utils:设置网络网卡桥接。
- virt-*:创建、克隆虚拟机命令，以及图形化管理工具virt-manager
- qemu-img:安装qemu组件，使用qemu命令来创建磁盘等。

## 检查kvm模块是否加载
```bash
lsmod |grep kvm
```
结果输出：
```bash
kvm_intel              55496  3
kvm                   337772  1 kvm_intel
```

如果没有，需要执行，还没有就重启一下试试
```bash
modprobe kvm-intel
```

## 配置网卡
```bash
cd /etc/sysconfig/network-scripts/
cp ifcfg-eth0 ifcfg-br0
```
编辑eth0
```bash
DEVICE=eth0
HWADDR=00:0C:29:55:A7:0A
TYPE=Ethernet
UUID=2be47d79-2a68-4b65-a9ce-6a2df93759c6
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=none
BRIDGE=br0
```
编辑br0
```bash
DEVICE=br0
#HWADDR=00:0C:29:55:A7:0A
TYPE=Bridge
#UUID=2be47d79-2a68-4b65-a9ce-6a2df93759c6
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=static
IPADDR=192.168.11.17
NETMASK=255.255.255.0
GATEWAY=192.168.11.1
DNS1=202.106.0.20
```
记得重启网卡：`/etc/init.d/network restart`

```bash
br0       Link encap:Ethernet  HWaddr 00:0C:29:55:A7:0A
          inet addr:192.168.11.17  Bcast:192.168.11.255  Mask:255.255.255.0
          inet6 addr: fe80::20c:29ff:fe55:a70a/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:141326 errors:0 dropped:0 overruns:0 frame:0
          TX packets:90931 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:456024940 (434.8 MiB)  TX bytes:10933593 (10.4 MiB)

eth0      Link encap:Ethernet  HWaddr 00:0C:29:55:A7:0A
          inet6 addr: fe80::20c:29ff:fe55:a70a/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:341978 errors:0 dropped:0 overruns:0 frame:0
          TX packets:90946 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:468848861 (447.1 MiB)  TX bytes:10934699 (10.4 MiB)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:0 (0.0 b)  TX bytes:0 (0.0 b)

virbr0    Link encap:Ethernet  HWaddr 52:54:00:14:EF:D5
          inet addr:192.168.122.1  Bcast:192.168.122.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:0 (0.0 b)  TX bytes:0 (0.0 b)
```

## 启动服务
```bash
/etc/init.d/libvirtd start
/etc/init.d/messagebus restart
```

此时可以查看网络接口列表
```bash
$ brctl show 
bridge name     bridge id               STP enabled     interfaces
br0             8000.000c2955a70a       no              eth0
virbr0          8000.52540014efd5       yes             virbr0-nic
```

# 创建虚拟机
创建一个存储虚拟机虚拟磁盘的目录，该目录所在分区必须足够大
```bash
mkdir /data/   
```

执行命令：
```bash
virt-install \
--name ping \
--ram 512 \
--disk path=/data/ping.img,size=20 \
--vcpus 1 \
--os-type linux \
--os-variant rhel6 \
--network bridge=br0 \
--graphics none \
--console pty,target_type=serial \
--location 'http://mirrors.163.com/centos/6.8/os/x86_64/' \
--extra-args 'console=ttyS0,115200n8 serial'
```

说明：
- --name  指定虚拟机的名字
- --ram 指定内存分配多少
- --disk path 指定虚拟磁盘放到哪里，size=30 指定磁盘大小为30G,这样磁盘文件格式为raw，raw格式不能做快照，后面有说明，需要转换为qcow2格式，如果要使用qcow2格式的虚拟磁盘，需要事先创建qcow2格式的虚拟磁盘。 参考  http://www.361way.com/kvm-qcow2-preallocation-metadata/3354.html   示例:qemu-img create -f qcow2 -o preallocation=metadata  /data/test02.img 7G;  --disk path=/data/test02.img,format=qcow2,size=7,bus=virtio
- --vcpus 指定分配cpu几个
- --os-type 指定系统类型为linux
- --os-variant 指定系统版本
- --network  指定网络类型
- --graphics 指定安装通过哪种类型，可以是vnc，也可以没有图形，在这里我们没有使用图形直接使用文本方式
- --console 指定控制台类型
- --location 指定安装介质地址，可以是网络地址，也可以是本地的一个绝对路径，（--location '/mnt/', 其中/mnt/下就是我们挂载的光盘镜像mount /dev/cdrom /mnt)如果是绝对路径，那么后面还需要指定一个安装介质，比如NFS

之后就出现：
```bash
开始安装......
搜索文件 .treeinfo......                             |  720 B     00:00 ...
搜索文件 vmlinuz......                               | 7.7 MB     00:02 ...
搜索文件 initrd.img......                            |  63 MB     00:23 ...
创建存储文件 ping.img                       |  30 GB     00:00
创建域......                                          |    0 B     00:00
连接到域 ping
Escape character is ^]
```

然后就是我们非常熟悉的OK or  Next 了 ，只不过这个过程是文本模式，如果想使用图形，只能开启vnc啦

最后安装完，reboot就进入刚刚创建的虚拟机了。要想退回到宿主机，`ctrl +  ]` 即可。
`virsh list` 可以列出当前的子机列表。
`virsh start ping` 开启子机
`virsh console ping`  可以进入指定的子机

# 使用python管理API
## 安装相关包
```bash
yum install libvirt-devel 
```
## 安装python的libvirt库
```bash
pip install libvirt-python libvirt
```

## 测试
```python
import libvirt
conn = libvirt.open("qemu:///system")
```

## 远程管理
直接上述安装还只能在本地使用python管理。如果还需要远程管理的话还要额外的配置。

修该配置文件`/etc/libvirt/libvirtd.conf`
```bash
###/etc/libvirt/libvirtd.conf
listen_tls = 0　　　　　　　　　　#禁用tls登录
listen_tcp = 1　　　　　　　　　  #启用tcp方式登录
tcp_port = "16509"　　　　　　　#tcp端口16509
listen_addr = "0.0.0.0"
unix_sock_group = "libvirtd"
unix_sock_rw_perms = "0770"
auth_unix_ro = "none"
auth_unix_rw = "none"
auth_tcp = "none"　　　　　　   #TCP不使用认证
max_clients = 1024　　　　　　  #最大总的连接客户数1024
min_workers = 50　　　　　　    #libvirtd启动时，初始的工作线程数目
max_workers = 200　　　　　　 #同上，最大数目
max_requests = 1000　　　　　 #最大同时支持的RPC调用，必须大于等于max_workers
max_client_requests = 200　　 #每个客户端支持的最大连接数
```

修改配置文件`/etc/sysconfig/libvirtd`：
```bash
LIBVIRTD_ARGS="--listen"
```

重启服务后libvirtd会绑定在16509端口

在远程的机器上安装python库
```bash
yum install libvirt-devel python-devel # 要先安装libvirt-devel包，因为libvirt-python依赖于libvirt-devel
pip install libvirt libvirt-python
```

测试代码：
```python
import libvirt
conn = libvirt.open("qemu+tcp://192.168.11.17/system")
```

没有报错，安装完毕。

