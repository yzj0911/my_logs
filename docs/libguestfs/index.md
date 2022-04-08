# KVM镜像管理工具libguestfs


# KVM镜像管理工具libguestfs


# 简介
[`libguestfs`](https://libguestfs.org/) 是一套管理虚拟机镜像的工具。它提供以一系列命令和API来修改和管理虚拟机的镜像。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20210131105105.png)

# 安装
直接使用 `yum` 安装 `libguestfs` :
```bash
yum install -y libguestfs-tool libguestfs-devel
``` 
默认不支持修改 windows 镜像，可以安装 `libguestfs-winsupport` :
```bash
yum install -y libguestfs-winsupport
```

# libguestfs 命令

libguestfs 的通用参数
- -a|--add image  : 指定查看的镜像文件路径
- -c|--connect uri : 指定远程 libvirt 地址 
- -d|--domain guest : 指定 libvirt 上的 domain 名称

> 注: libguestfs 的命令需要调用 libvirt 所以响应的速度会比较慢。同时，如果命令会修改镜像的内容，需要先关闭域，避免造成数据不同步。

## virt-inspector 
`virt-inspector` 命令用来查看镜像信息，输出格式为 xml
```bash
$ virt-inspector -d centos
<?xml version="1.0"?>
<operatingsystems>
  <operatingsystem>
    <root>/dev/centos/root</root>
    <name>linux</name>
    <arch>x86_64</arch>
    <distro>centos</distro>
    <product_name>CentOS Linux release 7.6.1810 (Core) </product_name>
    <major_version>7</major_version>
    <minor_version>6</minor_version>
    <package_format>rpm</package_format>
    <package_management>yum</package_management>
    <hostname>localhost.localdomain</hostname>
    <osinfo>centos7.0</osinfo>
    <mountpoints>
      <mountpoint dev="/dev/centos/root">/</mountpoint>
      <mountpoint dev="/dev/sda1">/boot</mountpoint>
    </mountpoints>
    <filesystems>
      <filesystem dev="/dev/centos/root">
        <type>xfs</type>
        <uuid>12e94e0d-93e6-4714-9c61-116fbe994936</uuid>
      </filesystem>
      ...
      ...
<xml>
```

## virt-watch
`virt-watch` 查看本机虚拟化环境
```bash
$ virt-what
vmware
```

## virt-host-validator
`virt-host-validator` 检查本地环境是否符合虚拟化
```bash
$ virt-host-validate
  QEMU: 正在检查 for hardware virtualization                                 : PASS
  QEMU: 正在检查 if device /dev/kvm exists                                   : PASS
  QEMU: 正在检查 if device /dev/kvm is accessible                            : PASS
  QEMU: 正在检查 if device /dev/vhost-net exists                             : PASS
  ...
  ...
```


## virt-get-kernel
`virt-get-kernel` 获取镜像的内核文件
```bash
$ virt-get-kernel -d centos
download: /boot/vmlinuz-3.10.0-957.el7.x86_64 -> ./vmlinuz-3.10.0-957.el7.x86_64
download: /boot/initramfs-3.10.0-957.el7.x86_64.img -> ./initramfs-3.10.0-957.el7.x86_64.img
```

## virt-filesystems
`virt-filesystems` 查看镜像的文件系统
```bash
$ virt-filesystems -d centos
/dev/sda1
/dev/centos/root
```

## virt-df
`virt-df` 用来查看镜像的文件系统容量，同 `df` 命令
```bash
$ virt-df -d centos -h
文件系统                            大小 已用空间 可用空间 使用百分比%
centos:/dev/sda1                         1014M       100M       914M   10%
centos:/dev/centos/root                    17G       974M        16G    6%
```

## virt-ls
`virt-ls` 查看镜像的文件信息，同 `ls` 命令
```bash
$ virt-ls -d centos /root/ -l
total 28
dr-xr-x---.  2 root root  135 Jan 26 15:07 .
dr-xr-xr-x. 17 root root  224 Jan 16 09:56 ..
-rw-------.  1 root root   45 Jan 26 15:07 .bash_history
-rw-r--r--.  1 root root   18 Dec 29  2013 .bash_logout
-rw-r--r--.  1 root root  176 Dec 29  2013 .bash_profile
-rw-r--r--.  1 root root  176 Dec 29  2013 .bashrc
-rw-r--r--.  1 root root  100 Dec 29  2013 .cshrc
-rw-r--r--.  1 root root  129 Dec 29  2013 .tcshrc
-rw-------.  1 root root 1259 Jan 16 09:57 anaconda-ks.cfg
```

## virt-cat
`virt-cat` 查看镜像内的文件内容，同 `cat` 命令
```bash
$ virt-cat -d centos /etc/passwd
root:xx:0:0:root:/root:/bin/bash
...
...
```

## virt-log
`virt-log` 查看镜像的日志信息
```bash
$ virt-log -d centos
Jan 30 20:13:01 localhost rsyslogd: [origin software="rsyslogd" swVersion="8.24.0-34.el7" x-pid="3123" x-info="http://www.rsyslog.com"] rsyslogd was HUPed
Jan 30 20:33:37 localhost qemu-ga: info: guest-shutdown called, mode: powerdown
Jan 30 20:33:37 localhost systemd: Started Delayed Shutdown Service.
```

## virt-tail
`virt-tail` 监听文件内容，同 `tail` 命令
```bash
$ virt-tail -d centos /var/log/messages


--- /var/log/messages ---
...
```

## virt-alignment-scan
`virt-alignment-scan` 查看镜像分区是否对齐
```bash
$ virt-alignment-scan -a centos.qcow2
/dev/sda1      1048576         1024K   ok
/dev/sda2   1074790400         1024K   ok
```

## virt-diff
`virt-diff` 比较镜像间的不同
```bash
$ # virt-diff -a centos.qcow2 -A centos.img
- d 0550        150 /root
+ d 0550        135 /root
# changed: st_size
- - 0644          4 /root/kvm.txt
- d 1777        187 /tmp
+ d 1777        172 /tmp
# changed: st_size
- - 0644          4 /tmp/kvm.txt
```

## virt-sparisify
`virt-sparisify` 用来消除镜像内的空洞文件，减少镜像大小
```bash
$ virt-sparsify centos.qcow2 -f qcow2 centos2.qcow2
[   0.0] Create overlay file in /tmp to protect source disk
[   0.0] Examine source disk
[   3.4] Fill free space in /dev/centos/root with zero
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ 00:00
[  33.5] Clearing Linux swap on /dev/centos/swap
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ --:--
[  36.2] Fill free space in /dev/sda1 with zero
[  38.5] Copy to destination and make sparse
[  51.4] Sparsify operation completed with no errors.
virt-sparsify: Before deleting the old disk, carefully check that the
target disk boots and works correctly.
```
执行完成后生成 centos2.qcow2 文件:
```bash
$ ll -h
总用量 4.0G
-rw-r--r-- 1 root root 1.1G 1月  30 23:39 centos2.qcow2
-rw-r--r-- 1 root root 1.5G 1月  30 20:33 centos.img
-rw-r--r-- 1 root root 1.5G 1月  30 20:43 centos.qcow2
```

## virt-copy-in
`virt-copy-in` 将本地文件复制到镜像中
```bash
$ virt-copy-in -a centos.qcow2 kvm.txt /tmp/
$ virt-ls -a centos.qcow2 /tmp/
kvm.txt
```

## virt-copy-out
`virt-copy-out` 将镜像中的文件复制到本地
```bash
$ virt-copy-out -a centos.qcow2 /tmp/kvm.txt .
```

## virt-edit
`virt-edit` 编译镜像内的文件，默认会打开本地的 Vim 进行编辑
```bash
$ virt-edit -a centos.qcow2 /tmp/kvm.txt
$ virt-cat -a centos.qcow2 /tmp/kvm.txt
kvm
kvm11
```

## virt-make-fs
`virt-make-fs` 根据本地的目录创建一个镜像
```bash
$ mkdir /input
$ echo "input" > /input/1.txt
$ virt-make-fs --partition=gpt --type=ntfs --size=1G --format=qcow2 /input sdb.qcow2
```

## virt-tar-in 

`virt-tar-in` tar 压缩文件拷贝进虚拟机并解压

```bash
$ virt-tar-in -a centos.qcow2 kvm.tar /root/
```

## virt-tar-out

`virt-tar-out` 镜像内指定目录文件拷贝并压缩
```bash
$ virt-tar-out -a centos.qcow2 /root root.tar
```

## guestmount
`guestmount` 将镜像中的文件系统分区挂载到本地目录
```bash
$ guestmount -a centos.qcow2 -m /dev/sda1 /mnt
```

## guestumount 
`guestumount` 卸载 `guestmount` 挂载的目录
```bash
$ guestumount /mnt
```

## virt-rescue
`virt-rescue` 进入救援模式，修复镜像 

```bash
$ virt-rescue -a centos.qcow2
```

## virt-resize
`virt-resize` 镜像分区缩容和扩容

给其中某个分区扩容 5G
```bash
$ virt-filesystems --long -h --all -a olddisk
 
$ truncate -r olddisk newdisk
$ truncate -s +5G newdisk
 
$ virt-resize --expand /dev/sda2 olddisk newdisk
```
/boot 分区扩容 200MB bigger, 剩下的分配给 /dev/sda2:
```bash
$ virt-resize --resize /dev/sda1=+200M --expand /dev/sda2 olddisk newdisk
```
lvm 分区扩容
```bash
$ virt-resize --expand /dev/sda2 --LV-expand /dev/vg_guest/lv_root olddisk newdisk
```

