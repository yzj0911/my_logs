# linux上使用udev创建裸设备


# linux上使用udev创建裸设备

**需求和分析**
在一次项目中需要将进行oracle数据库的备份，要求在oracle机器总是能认到备份的块设备的路径以保证备份和恢复的正常。同时还需要对磁盘进行修改，转化中asm格式的。
基于这种情况下，在linux中将磁盘转化成对应的裸设备是一种合适的方法。
简单的操作就是将配置写入`/etc/udev/rule.d/1401-oracle-asmdevice.rules`文件中，让udev管理。

**udev 规则的匹配键**
- ACTION： 事件 (uevent) 的行为，例如：add( 添加设备 )、remove( 删除设备 )。
- KERNEL： 内核设备名称，例如：sda, cdrom。
- DEVPATH：设备的 devpath 路径。
- SUBSYSTEM： 设备的子系统名称，例如：sda 的子系统为 block。
- BUS： 设备在 devpath 里的总线名称，例如：usb。
- DRIVER： 设备在 devpath 里的设备驱动名称，例如：ide-cdrom。
- ID： 设备在 devpath 里的识别号。
- SYSFS{filename}： 设备的 devpath 路径下，设备的属性文件“filename”里的内容。
例如：SYSFS{model}==“ST936701SS”表示：如果设备的型号为 ST936701SS，则该设备匹配该 匹配键。
在一条规则中，可以设定最多五条 SYSFS 的 匹配键。
- ENV{key}： 环境变量。在一条规则中，可以设定最多五条环境变量的 匹配键。
- PROGRAM：调用外部命令。
- RESULT： 外部命令 PROGRAM 的返回结果。

**配置文件**
这里是CentOS 6的版本
```bash
[root@rac1 ~]# cat /etc/udev/rules.d/99-oracle-asmdevice.rules 
KERNEL=="sd*",SUBSYSTEM=="block",PROGRAM=="/sbin/scsi_id --whitelisted --replace-whitespace --device=/dev/$name",RESULT=="360000000000000000e00000000020fa8",NAME+="oracleasm/disks/HL_360000000000000000e00000000020fa8",OWNER="grid",GROUP="asmadmin",MODE="0660"
```
然后加载配置文件
```bash
[root@rac1 ~]# start_udev 
正在启动 udev：                                            [确定]
[root@rac1 ~]# ll /dev/oracleasm/disks 
总用量 0
brw-rw---- 1 grid asmadmin 8, 16 1月  23 14:30 HL_360000000000000000e00000000020fa8
```
**注意**
在`CentOS6`和`CentOS7`的配置有所不同。
一个是`scsi_id`命令，还有是`udev`规则变化。
```bash
KERNEL=="sd*",SUBSYSTEM=="block",PROGRAM=="/usr/lib/udev/scsi_id --whitelisted --replace-whitespace --device=/dev/$name",RESULT=="360000000000000000e00000000160fa8",RUN+="/bin/sh -c 'mkdir -pv /dev/oracleasm/disks;mknod /dev/oracleasm/disks/HL_360000000000000000e00000000160fa8 b 1 3; chown grid:oinstall /dev/oracleasm/disks/HL_360000000000000000e00000000160fa8; chmod 0660 /dev/oracleasm/disks/HL_360000000000000000e00000000160fa8'"
```
`scsi_id`命令需要安装`systemd`包，如果知道命令对应的软件包名称，可以使用yum命令查看
```
yum provides "/*/scsi_id"
```
`udev`需要使用`RUN`来代替`NAME`，在`RUN`中能使用linux的命令，使用`；`分隔多个命令。
`mknod`是CentOS7中转化设备的新命令，格式为：
```bash
mknod /dev/sdb <DEVICE_TYPE> <主设备号> <次设备号>
```
同时修改`udev`的命令也发生了变化。
```bash
[root@localhost ~]#  /usr/sbin/udevadm trigger --type=devices --action=change
```
在同时添加多个设备时，后添加的设备同步较慢。比较好的方法是先全部添加到`.rules`文件中，最后再执行`udevadm trigger`加载。

