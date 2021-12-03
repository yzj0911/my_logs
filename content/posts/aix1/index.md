
---
title: "Aix添加和删除Iscsi存储卷"
date: 2021-12-03T10:17:16+08:00
draft: false
---

# Aix添加和删除Iscsi存储卷


> Aix为6.1版本
# 使用iscsi存储
首先需要创建一个iscsi target，并共享到IBM Aix上。
## 检查iscsi是否被安装
```bash
$ lslpp -L | grep -i iscsi 
  devices.common.IBM.iscsi.rte
                             6.1.5.0    C     F    Common iSCSI Files 
  devices.iscsi.disk.rte     6.1.5.0    C     F    iSCSI Disk Software 
  ...
```
## 配置iscsi
```bash
$ vi /etc/iscsi/targets
...
# 添加target
172.16.1.169 3260 iqn.2018-11.com.howlink.wbrt.portal.backup
```
## 重新扫盘
```bash
$ cfgmgr -l iscsi0
cfgmgr: 0514-621 WARNING: The following device packages are required for
        device support but are not currently installed.
devices.iscsi.array
```
## 查看iscsi盘
```bash
$ lsdev -Cc disk | grep iSCSI
hdisk18     Available          Other iSCSI Disk Drive
```
## 创建物理卷
```bash
$ chdev -l hdisk18 -a pv=yes
```
## 创建vg
```bash
$ mkvg -y wbrt_portal_bg hdisk18
```
## 创建lv
```bash
$ mklv -t jfs2 -y wbrt_portal_bl wbrt_portal_bg 700
```
> 注:lv的大小可以使用命令 
> `$ lsvg wbrt_portal_bg | grep "TOTAL PPs" | awk -F' ' '{ print $6}' 703`
> 但不要全部使用，需要一些剩余空间。

## 创建挂载目录
```bash
$ mkdir /mnt/iscsi
```
## 格式化并挂载
```bash
$ crfs -v jfs2 -m /mnt/iscsi -d wbrt_portal_bl
$ mount /mnt/iscsi
```
# 删除存储盘
## 卸载磁盘
```bash
$ umount /mnt/iscsi
```
## lv
```bash
$ rmlv wbrt_portal_bl
```
## 删除文件系统
```bash
$ rmfs -r /dev/wbrt_portal_bl
```
## 删除vg
```bash
$ reducevg -d wbrt_portal_bg hdisk18
```
## 删除物理盘
```bash
$ rmdev -dl hdisk18 -R
```
## 删除iscsi target
```bash
$ vi /etc/iscsi/targets
...
# 添加target
# 172.16.1.169 3260 iqn.2018-11.com.howlink.wbrt.portal.backup
```
重读磁盘
```bash
$ cfgmgr -l iscsi0
```

