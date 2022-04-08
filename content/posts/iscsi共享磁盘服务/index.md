---
title: "iscsi共享磁盘服务"
date: 2021-12-03T10:17:16+08:00
draft: false
---

# iscsi共享磁盘服务


![](http://image.xingyys.club/blog/iscsi.jpg)

# iscsi简单介绍
iSCSI（Internet Small Computer System Interface，发音为/ˈаɪskʌzi/），Internet小型计算机系统接口，又称为IP-SAN，是一种基于因特网及SCSI-3协议下的存储技术，由IETF提出，并于2003年2月11日成为正式的标准。与传统的SCSI技术比较起来，iSCSI技术有以下三个革命性的变化：
- 把原来只用于本机的SCSI协义透过TCP/IP网络发送，使连接距离可作无限的地域延伸；
- 连接的服务器数量无限（原来的SCSI-3的上限是15）；
- 由于是服务器架构，因此也可以实现在线扩容以至动态部署。

简单的说就是tcp协议仿真scsi，将本地的磁盘通过网络共享给其他机器，提供数据的远程存储。

# iscsi基本概念
iscsi中有一些常用的基本概念，了解这些能帮助我们认识iscsi服务的具体工作原理，下面就用一张图表来说明：

| 名词              | 说明                                                                               |
| ----------------- | ---------------------------------------------------------------------------------- |
| ACL               | 访问权限控制列表，用来验证客户端启动器的访问，通常是客户端 iSCSI 启动器的 IQN 名称 |
| IQN               | 用于标识单个 iSCSI 目标和启动器的唯一名称(全部小写)                                |
| WWN               | 用于标识单个光纤通道端口和节点的唯一编号                                           |
| TARGET            | iSCSI 服务器上的存储资源                                                           |
| LUN               | iSCSI 服务器上的块设备                                                             |
| initiator(启动器) | 以软件或硬件实施的 iSCSI 客户端                                                    |
| NODE              | 单个 iSCSI 启动器或者目标                                                          |
| TPG               | 启动器或者目标上的单个 IP 连接地址                                                 |
| Portal            | 网络接口及端口                                                                                   |

# iscsi 安装配置
iscsi  服务管理的软件有多个，这里就简单介绍两个，`targetcli`和`tgt`。
## 使用targetcli管理配置iscsi
**1.准备阶段**
有两台linux机器，分别作为服务端和客户端。实验环境最好在虚拟机上，方便修改的反复操作。同时在服务端上有一块磁盘作为iscsi共享磁盘。
```bash
[root@localhost ~]# lsblk 
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   40G  0 disk 
├─sda1   8:1    0  500M  0 part /boot
├─sda2   8:2    0    4G  0 part [SWAP]
└─sda3   8:3    0 35.5G  0 part /
sdb      8:16   0   10G  0 disk 
└─sdb1   8:17   0   10G  0 part 
sdc      8:32   0   10G  0 disk 
sr0     11:0    1 1024M  0 rom 
```
这个选择`/dev/sdb1`,没有的同学可以使用`fdisk`命令自己分配一个。
**2.安装targetcli**
```bash
yum install -y targetcli
```
还需要启动targetcli服务
```bash
systemctl start target
```
**3.配置targetcli**
配置targetcli有几个步骤，添加target，在target上添加lun，将target共享到指定网段。
先来创建一个块设备，使用命令为：
`/backstores/block create westos:storage1 /dev/sdb1`
进入targetcli操作：
```bash
[root@localhost ~]# targetcli
Warning: Could not load preferences file /root/.targetcli/prefs.bin.
targetcli shell version 2.1.fb46
Copyright 2011-2013 by Datera, Inc and others.
For help on commands, type 'help'.

/> /backstores/block create westos:storage1 /dev/sdb1
Created block storage object westos:storage1 using /dev/sdb1. # 注意这里就成功创建一个快设备
/> ls
o- / ......................................................................................................................... [...]
  o- backstores .............................................................................................................. [...]
  | o- block .................................................................................................. [Storage Objects: 1]
  | | o- westos:storage1 .............................................................. [/dev/sdb1 (0 bytes) write-thru deactivated]
  | |   o- alua ................................................................................................... [ALUA Groups: 1]
  | |     o- default_tg_pt_gp ....................................................................... [ALUA state: Active/optimized]
  | o- fileio ................................................................................................. [Storage Objects: 0]
  | o- pscsi .................................................................................................. [Storage Objects: 0]
  | o- ramdisk ................................................................................................ [Storage Objects: 0]
  o- iscsi ............................................................................................................ [Targets: 0]
  o- loopback ......................................................................................................... [Targets: 0]
/>
```
接着创建一个iscsi共享的target，使用命令为：
`/iscsi create iqn.2018-10.com.westos:storage1`
这里的target名称其实可以随意，但一般格式为`iqn.year.month.com.domain.xxx`,
执行的结果如下：
```bash
/> /iscsi create iqn.2018-10.com.westos:storage1
Created target iqn.2018-10.com.westos:storage1.
Created TPG 1.
Global pref auto_add_default_portal=true
Created default portal listening on all IPs (0.0.0.0), port 3260.
/> ls
o- / ......................................................................................................................... [...]
  o- backstores .............................................................................................................. [...]
  | o- block .................................................................................................. [Storage Objects: 1]
  | | o- westos:storage1 .............................................................. [/dev/sdb1 (0 bytes) write-thru deactivated]
  | |   o- alua ................................................................................................... [ALUA Groups: 1]
  | |     o- default_tg_pt_gp ....................................................................... [ALUA state: Active/optimized]
  | o- fileio ................................................................................................. [Storage Objects: 0]
  | o- pscsi .................................................................................................. [Storage Objects: 0]
  | o- ramdisk ................................................................................................ [Storage Objects: 0]
  o- iscsi ............................................................................................................ [Targets: 1]
  | o- iqn.2018-10.com.westos:storage1 ................................................................................... [TPGs: 1]
  |   o- tpg1 ............................................................................................... [no-gen-acls, no-auth]
  |     o- acls .......................................................................................................... [ACLs: 0]
  |     o- luns .......................................................................................................... [LUNs: 0]
  |     o- portals .................................................................................................... [Portals: 1]
  |       o- 0.0.0.0:3260 ..................................................................................................... [OK]
  o- loopback ......................................................................................................... [Targets: 0]
/> 
```
之后还需要将target共享出去：
`/iscsi/iqn.2018-06.com.westos:storage1/tpg1/acls create iqn.2018-06.com.example:westoskey` #cal配置
`/iscsi/iqn.2018-06.com.westos:storage1/tpg1/luns create /backstores/block/westos:storage1` #luns配置
`/iscsi/iqn.2018-06.com.westos:storage1/tpg1/portals/ create 172.25.254.101` #portals配置
```bash
/> /iscsi/iqn.2018-10.com.westos:storage1/tpg1/acls create iqn.2018-10.com.example:westoskey
Created Node ACL for iqn.2018-10.com.example:westoskey
/> /iscsi/iqn.2018-10.com.westos:storage1/tpg1/luns create /backstores/block/westos:storage1
Created LUN 0.
Created LUN 0->0 mapping in node ACL iqn.2018-10.com.example:westoskey
/> /iscsi/iqn.2018-10.com.westos:storage1/tpg1/portals/ create 192.168.3.150
Using default IP port 3260
Could not create NetworkPortal in configFS
/> ls
o- / ............................................................................................................. [...]
  o- backstores .................................................................................................. [...]
  | o- block ...................................................................................... [Storage Objects: 1]
  | | o- westos:storage1 .................................................... [/dev/sdb1 (0 bytes) write-thru activated]
  | |   o- alua ....................................................................................... [ALUA Groups: 1]
  | |     o- default_tg_pt_gp ........................................................... [ALUA state: Active/optimized]
  | o- fileio ..................................................................................... [Storage Objects: 0]
  | o- pscsi ...................................................................................... [Storage Objects: 0]
  | o- ramdisk .................................................................................... [Storage Objects: 0]
  o- iscsi ................................................................................................ [Targets: 1]
  | o- iqn.2018-10.com.westos:storage1 ....................................................................... [TPGs: 1]
  |   o- tpg1 ................................................................................... [no-gen-acls, no-auth]
  |     o- acls .............................................................................................. [ACLs: 1]
  |     | o- iqn.2018-10.com.example:westoskey ........................................................ [Mapped LUNs: 1]
  |     |   o- mapped_lun0 ........................................................... [lun0 block/westos:storage1 (rw)]
  |     o- luns .............................................................................................. [LUNs: 1]
  |     | o- lun0 ............................................... [block/westos:storage1 (/dev/sdb1) (default_tg_pt_gp)]
  |     o- portals ........................................................................................ [Portals: 1]
  |       o- 0.0.0.0:3260 ......................................................................................... [OK]
  o- loopback ............................................................................................. [Targets: 0]
/>
```
有一个报错信息：
```
Could not create NetworkPortal in configFS
```
原因是再/iscsi/portals/下已经存在IP地址。可以直接跳过，获取删除，重新创建。
```bash
/> /iscsi/iqn.2018-10.com.westos:storage1/tpg1/portals/ delete 0.0.0.0 3260
Deleted network portal 0.0.0.0:3260
/> /iscsi/iqn.2018-10.com.westos:storage1/tpg1/portals/ create 192.168.3.150
Using default IP port 3260
Created network portal 192.168.3.150:3260.
/> ls
o- / ............................................................................................................. [...]
  o- backstores .................................................................................................. [...]
  | o- block ...................................................................................... [Storage Objects: 1]
  | | o- westos:storage1 .................................................... [/dev/sdb1 (0 bytes) write-thru activated]
  | |   o- alua ....................................................................................... [ALUA Groups: 1]
  | |     o- default_tg_pt_gp ........................................................... [ALUA state: Active/optimized]
  | o- fileio ..................................................................................... [Storage Objects: 0]
  | o- pscsi ...................................................................................... [Storage Objects: 0]
  | o- ramdisk .................................................................................... [Storage Objects: 0]
  o- iscsi ................................................................................................ [Targets: 1]
  | o- iqn.2018-10.com.westos:storage1 ....................................................................... [TPGs: 1]
  |   o- tpg1 ................................................................................... [no-gen-acls, no-auth]
  |     o- acls .............................................................................................. [ACLs: 1]
  |     | o- iqn.2018-10.com.example:westoskey ........................................................ [Mapped LUNs: 1]
  |     |   o- mapped_lun0 ........................................................... [lun0 block/westos:storage1 (rw)]
  |     o- luns .............................................................................................. [LUNs: 1]
  |     | o- lun0 ............................................... [block/westos:storage1 (/dev/sdb1) (default_tg_pt_gp)]
  |     o- portals ........................................................................................ [Portals: 1]
  |       o- 192.168.3.150:3260 ................................................................................... [OK]
  o- loopback ............................................................................................. [Targets: 0]
/>
/> exit
Global pref auto_save_on_exit=true
Last 10 configs saved in /etc/target/backup/.
Configuration saved to /etc/target/saveconfig.json
```
退出之后配置结果持久化到`/etc/target/saveconfig.json`。
## 使用tgt配置iscsi
再来介绍另外一种软件，就是tgt。
**1.安装**
```bash
yum install -y epel-release
yum install -y scsi-target-utils
```
启动服务
```bash
systemctl start tgtd
```
**2.配置tgt**
配置tgt使用的命令是`tgtadm`，有以下常用选项：
- --lld <driver> --mode target --op new --tid <id> --targetname <name> # 新建target
- --lld <driver> --mode target --op delete [--force] --tid <id>  # 删除target
- --lld <driver> --mode target --op show # 查看所有的target
- --lld <driver> --mode target --op show --tid <id> # 查看指定id的target
- --lld <driver> --mode target --op update --tid <id> --name <param> --value <value> # 更新target
- --lld <driver> --mode target --op bind --tid <id> --initiator-address <address> # target共享到指定网段
- --lld <driver> --mode target --op bind --tid <id> --initiator-name <name> # target共享到指定的客户端名称
- --lld <driver> --mode target --op unbind --tid <id> --initiator-address <address> # 解绑
- --lld <driver> --mode target --op unbind --tid <id> --initiator-name <name>
- --lld <driver> --mode logicalunit --op new --tid <id> --lun <lun>
  --backing-store <path> --bstype <type> --bsopts <bs options> --bsoflags <options> # 创建lun
- --lld <driver> --mode logicalunit --op delete --tid <id> --lun <lun> # 删除lun
- --lld <driver> --mode account --op new --user <name> --password <pass> # 添加认证
- --lld <driver> --mode account --op delete --user <name> # 删除认证
- --lld <driver> --mode account --op bind --tid <id> --user <name> [--outgoing] # 绑定认证 
- --lld <driver> --mode account --op unbind --tid <id> --user <name> [--outgoing] # 解绑认证

添加target
```bash
[root@localhost ~]# tgtadm --lld iscsi --mode target --op new --tid 1 --targetname iqn-2019-11.com.iscsi.test
[root@localhost ~]# tgtadm --lld iscsi --mode target --op show
Target 1: iqn-2019-11.com.iscsi.test
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags: 
    Account information:
    ACL information:
```
添加lun
```bash
[root@localhost ~]# tgtadm --lld iscsi --mode logicalunit --op new --tid 1 --lun 22 -b /dev/sdb
[root@localhost ~]# tgtadm --lld iscsi --mode target --op show
Target 1: iqn-2019-11.com.iscsi.test
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags: 
        LUN: 22
            Type: disk
            SCSI ID: IET     00010016
            SCSI SN: beaf122
            Size: 10737 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/sdb
            Backing store flags: 
    Account information:
    ACL information:
```
注：这里有一个小提示，每个lun中的`SCSI ID`项是在客户端中的唯一标识，它的值是根据`target id`和`lun id`计算得到的，即：
```
SCSI ID = Target ID转16进制(前四位) + Lun ID转16进制(后四位)
```
所以lun 22的`SCSI ID`为`00010016`
共享到客户端：
```bash
[root@localhost ~]# tgtadm --lld iscsi --mode target --op bind --tid 1 --initiator-address 192.168.3.131
```
## 客户端连接
**1.安装客户端**
```bash
yum install -y epel-release
yum install -y iscsi-initiator-utils
```
客户端命令：
- iscsiadm -m session # 查看所有会话
- iscsiadm -m discovery -t st -p 192.168.3.150 #查看共享target
- iscsiadm -m node -T iqn.2018-10.com.westos:storage1 -p 192.168.3.150 -l #登陆连接
- iscsiadm -m node -T iqn.2018-10.com.westos:storage1 -u #退出登陆
- iscsiadm -m node -T iqn.2018-10.com.westos:storage1 -o delete #删除登陆数据

**2.发现设备**
```bash
[root@localhost ~]# iscsiadm -m discovery -t st -p 192.168.3.150
192.168.3.150:3260,1 iqn.2018-10.com.westos:storage1
```
登录
注：请关闭防火墙和selinux
```bash
[root@localhost mnt]# iscsiadm -m node -T iqn.2018-10.com.westos:storage1 -p 192.168.3.150 -l
Logging in to [iface: default, target: iqn.2018-10.com.westos:storage1, portal: 192.168.3.150,3260] (multiple)
Login to [iface: default, target: iqn.2018-10.com.westos:storage1, portal: 192.168.3.150,3260] successful.
[root@localhost ~]# lsblk 
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0      2:0    1    4K  0 disk 
sda      8:0    0   40G  0 disk 
├─sda1   8:1    0  500M  0 part /boot
├─sda2   8:2    0    8G  0 part [SWAP]
└─sda3   8:3    0 31.5G  0 part /
sdb      8:16   0    2G  0 disk 
└─sdb1   8:17   0    2G  0 part 
sr0     11:0    1 1024M  0 rom
```
同时在`/dev/disk/by-id`下生成块设备。
