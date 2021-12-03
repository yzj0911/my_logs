---
title: "KVM之虚拟机管理"
date: 2021-12-03T10:17:16+08:00
draft: false
---

# KVM之虚拟机管理


> 本篇文章介绍 KVM 虚拟机的管理，包括虚拟机的创建、修改、启动、删除等内容

# 安装虚拟机

## 使用 virt-install 安装

virt-install 是一个命令行工具，专门用于安装 kvm 虚拟机。执行以下命令：

```bash
virt-install \
  --name centos \
  --ram 1024 \
  --disk path=/data/kvm/centos.img,size=20 \
  --vcpus 1 \
  --os-type linux --os-variant rhel7 \
  --network bridge=br0 \
  --graphics vnc,listen=0.0.0.0,port=5999 --noautoconsole \
  --console pty,target_type=serial \
  --cdrom CentOS-7-x86_64-DVD-1810.iso 
```
进入安装流程：
```bash
# virsh list --all
 Id    名称                         状态
----------------------------------------------------
 2     centos                         running
```
可以使用 vnc 客户端连接虚拟机。

参数说明：
- -–name 指定虚拟机的名字
- –-ram 指定内存分配多少
- –-disk path 指定虚拟磁盘放到哪里，size=30 指定磁盘大小为30G,这样磁盘文件格式为raw，raw格式不能做快照，后面有说明，需要转换为qcow2格式，如果要使用qcow2格式的虚拟磁盘，需要事先创建qcow2格式的虚拟磁盘。 参考 http://www.361way.com/kvm-qcow2-preallocation-metadata/3354.html 示例:qemu-img create -f qcow2 -o preallocation=metadata /data/test02.img 7G; –disk path=/data/test02.img,format=qcow2,size=7,bus=virtio
- –-vcpus 指定分配cpu几个
- -–os-type 指定系统类型为linux
- –-os-variant 指定系统版本
- -–network 指定网络类型
- -–graphics 指定安装通过哪种类型，可以是vnc，也可以没有图形，在这里我们没有使用图形直接使用文本方式
- -–console 指定控制台类型
- -–location 指定安装介质地址，可以是网络地址，也可以是本地的一个绝对路径，（–location ‘/mnt/’, 其中/mnt/下就是我们挂载的光盘镜像mount /dev/cdrom /mnt)如果是绝对路径，那么后面还需要指定一个安装介质，比如NFS
- --extra-args 额外参数，需要和 --location 配置使用
- --cdrom 指定操作系统镜像位置

## 错误处理
安装过程中出现三个错误:

### 错误一
第一个错误如下:
```bash
CPU mode 'custom' for x86_64 kvm domain on x86_64 host is not supported by hypervisor
```
解决方式是重启宿主机

### 错误二
第二个错误如下：
```bash
Creating storage file centos.img                                                                           |  20 GB     00:00     
ERROR    internal error Process exited while reading console log output: char device redirected to /dev/pts/4
2016-01-27T08:56:58.986952Z ...: Permission denied

Domain installation does not appear to have been successful.
If it was, you can restart your domain by running:
  virsh --connect qemu:///system start centos65
otherwise, please restart your installation.
```
解决方式修改 `/etc/libvirt/qemu.conf` 配置文件，添加 user 和 group 配置：
```bash
# /etc/libvirt/qemu.conf
# ...
user = "root"
# ...
group = "root"
```
重启服务:
```bash
systemctl restart libvirtd
```

### 错误三
第三个错误是执行命令 `virsh console centos` 时卡住:
```bash
# virsh console centos


连接到域 centos
换码符为 ^]

```
解决方式如下： 


确认 `ttyS0` 存在在 `/etc/securetty` 文件中，没有就执行以下命令:
```bash
echo "ttyS0" >> /etc/securetty
```
修改 `/etc/default/grub` 文件：
```bash
# GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=cl/root rd.lvm.lv=cl/swap rhgb quiet”
# 改成
GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet net.ifnames=0 console=ttyS0,115200"
```
重新生成 grub 文件：
```bash
grub2-mkconfig -o /boot/grub2/grub.cfg
```
启动 serial-getty 服务:
```bash
systemctl start serial-getty@ttyS0.service
systemctl enable serial-getty@ttyS0.service
```

# 操作虚拟机
KVM 在 Hypervisor 中被称作域(domain)。使用 `virsh` 命令可以很有效的管理域。
virsh 中管理域的命令:

|  命令   | 功能描述  |
|  ----  | ----  |
| list  | 获取当前节点上的所有域的列表 |
| domstate \<ID or Name or UUID\>  | 获取一个域的运行状态 |
| dominfo \<ID\>  | 获取一个域的基本信息 |
| domid \<Name or UUID\>  | 根据域的名称或UUID返回域的ID |
| domname \<ID or UUID\>  | 根据域的ID或UUID返回域的名称 |
| dommemstat \<ID\>  | 获取一个域的内存使用情况的统计信息 |
| setmem \<ID\> \<mem-size\> | 设置一个域的内存大小(默认单位为KB) |
| vcpupin \<ID\> \<vCPU\> \<pCPU\> | 将一个域的 vCPU 绑定到某个物理 CPU 上运行 |
| setvcpus \<ID\> \<vCPU-num\>  | 设置一个域的 vCPU 的个数 |
| vncdisplay \<ID\> | 获取一个域的 VNC 连接 IP 地址的端口 |
| create \<dom.xml\> | 根据域的 XML 配置文件创建一个域(客户机) |
| suspend \<ID\> | 暂停一个域 |
| resume \<ID\> | 唤醒一个域 |
| shutdown \<ID\> | 让一个域执行关机操作 |
| reboot \<ID\> | 让一个域执行重启操作 |
| reset \<ID\> | 强制重启一个域，相当于在物理机上按带电源 "reset" 按钮 (可能会破坏该域的文件系统) |
| destroy \<ID\> | 立即销毁一个域，相当于直接拔掉物理机机器的电源线（可能会破坏该域的文件系统） |
| save \<ID\> \<file.img\> | 保存一个运行中的域的状态到一个文件中 |
| restore \<file.img\> | 从一个被保存的文件中恢复一个域的运行 |
| migrate \<ID\> \<dest_url\> | 将一个域迁移到另外一个目的地址 |
| dumpxml \<ID\>  | 以 XML 格式转存出一个域的信息到标准输出中 |
| attach-device \<ID\> \<device.xml\> | 向一个域添加 XML 文件中的设备(热插拔) |
| detach-device \<ID\> \<device.xml\> | 将 XML 文件中的设备从一个域中移除 |
| console \<ID\> | 连接到一个域的控制台 |

## 虚拟机生命周期
```bash
# 启动虚拟机
virsh start centos

# 关闭虚拟机
virsh shutdown centos

# 重启虚拟机
virsh reboot centos

# 销毁虚拟机
virsh destroy centos

# 暂停虚拟机
virsh suspend centos

# 恢复虚拟机
virsh resume centos

# 删除虚拟机
virsh undefine centos
rm -fr /etc/libvirt/qemu/centos.xml
```

## 限制和修改虚拟机 cpu
先关闭虚拟机，修改虚拟机 xml 文件:
```bash
# 设置 cpu 最大个数为 4 个，当前为 1
<vcpu placement='static' current='1'>4</vcpu>
```
开启虚拟机后，动态设置虚拟机 cpu
```bash
# 最大个数不能超过指定值
virsh setvcpus centos 2
```

## 限制和修改虚拟机内存
修改虚拟机内存最大值需要先关闭虚拟机
```bash
# 最大值不能超过宿主机内存最大值
virsh setmaxmem centos 4G
```
动态设置虚拟机内存
```bash
virsh setmem centos 2G
```

## 在线添加和删除虚拟机硬盘
先创建硬盘:
```bash
# qemu-img create -f qcow2 disk1.qcow2 2G
Formatting 'disk1.qcow2', fmt=qcow2 cluster_size=65536 extended_l2=off compression_type=zlib size=2147483648 lazy_refcounts=off refcount_bits=16
```
创建 disk.xml 文件
```bash
$ vim disk.xml
<disk type='file' device='disk'>
    <driver name='qemu' type='qcow2'/>
    <source file='/data/kvm/disk1.qcow2'/>
    <target dev='vdb' bus='virtio'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x08' function='0x0'/>
</disk>
```
添加硬盘设备:
```bash
virsh attach-device centos disk.xml
```
卸载硬盘设备
```bash
virsh dettach-device centos disk.xml
```

## 在线添加和删除虚拟机网卡
添加 bridge 网卡
```bash
virsh attach-interface centos --type bridge --source br0
```
卸载网卡
```bash
virsh detach-interface centos --type bridge --mac 52:54:00:d9:90:bb
```

## 修改虚拟机 vnc 
先关闭虚拟机
```bash
virsh stop centos
```
修改虚拟机文件
```bash
# irsh edit centos
    <graphics type='vnc' port='6000' autoport='no' listen='0.0.0.0' passwd='123456'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>
```
> 注: 虚拟机 vnc 的端口必须在 5900 - 65535 之间

加载配置文件
```bash
virsh define /etc/libvirt/qemu/centos.xml
```
最后启动虚拟机
```bash
virsh start centos
```
