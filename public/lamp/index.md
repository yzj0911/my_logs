# 

# 搭建lamp环境


# 搭建lamp环境


> lamp即 apache + mysql + php，是互联网常用架构。

要注意的是php依赖apache和mysql，所以要最后安装。系统环境为CentOS6.5


# 安装mysql
这里选择免编译安装，可以在官网找到。在mysql5.5之后的版本不在开源了，但还可以选择mariadb的分支版本作为这个架构的代替。接下来就可以开始mysql的安装了。

## 下载mysql
```bash
wget http://mirrors.sohu.com/mysql/MySQL-5.1/mysql-5.1.73-linux-i686-glibc23.tar.gz
```
这个版本有点低，可以自己选择合适版本
## 解压
```bash
tar -zxvf tar -zxvf mysql-5.1.73-linux-i686-glibc23.tar.gz
```
## 移动到指定目录
```bash
mv mysql-5.1.73-linux-i686-glibc23 /usr/local/mysql
```
## 创建mysql用户，但不允许登录，不创建家目录
```bash
useradd -s /sbin/nologin -M mysql
```
`-s`表示指定bash，这里出于安全性考虑设置不允许登录，`-M`不创建家目录
## 创建数据库目录，并改为mysql属主
```bash
mkdir /data/mysql -pv
chown -R mysql：mysql /data/mysql
```
## 初始化mysql
```bash
cd /usr/local/mysql
./scripts/mysql_install_db --user=mysql --datadir=/data/mysql
```
`--user=*`是指定用户mysql，`--datadir=*`是指定数据库目录。可以使用`echo $?`验证命令执行结果是否正确，0为正确。

## mysql配置文件
```bash
cp /usr/local/mysql/support-files/my-large.cnf /etc/my.cnf
vim /etc/my.cnf
......
port            = 3306        #监听端口
socket          = /tmp/mysql.sock  #socket
.....
log-bin=mysql-bin   #修改mysql数据库时，记录日志
```

## mysql启动脚本
```bash
cp /usr/local/mysql/mysql.server /etc/init.d/mysqld
vim /etc/init.d/mysqld

basedir=/usr/local/mysql   #指定安装目录
datadir=/data/mysql          #指定数据库目录
```

## 设置开机启动
```
chkconfig --add mysqld；chkconfig mysqld on 开机启动
```
编译安装mysql时编译参数记录在`cat /usr/local/mysql/bin/mysqlbug |grep -i configure`

# 安装httpd
使用apache的httpd提供网络web服务

## 下载httpd
```bash
wget http://mirrors.cnnic.cn/apache/httpd/httpd-2.2.31.tar.gz
```

## 解压
```bash
tar -zxvf httpd-2.2.31.tar.gz
```

## 编译安装
```bash
# 编译
./configure --prefix=/usr/local/apache \
>-with-include-apr --enable-so \
>--enable-deflate=shared \
>--enable-rewrite=shared \
>--enable-expires=shared \
>-with-pcre \
>-with-mpm=prefork

make

# 安装
make install
```
编译选项记录在`/usr/local/apache/build/config.nice` 中

## 启动httpd
```bash
/usr/local/apache/bin/apachectl start
```
- /usr/local/apache/bin/apachectl -M ：查看各种库
- 静态库(编译时直接放入下列文件)
/usr/local/apache/bin/httpd
- 动态库(用到时加载)
/usr/local/apache/modules/
- /usr/local/apache/bin/apachectl -l ：查看静态库以及apache工作模式
- /usr/local/apache/bin/apachectl -t ：查看配置文件有无语法错误
- 配置文件 /usr/local/apache/conf/httpd.conf
- /usr/local/apache/bin/apachectl graceful 加载配置文件

启动httpd时的警告：
```bash
httpd: apr_sockaddr_info_get() failed for 【linux】
httpd: Could not reliably determine the server's fully qualified domain name, using 127.0.0.1 for ServerName
```
解决方法(问题在于主机名不匹配)
警告1 ：在/etc/hosts中的127.0.0.1行后添加linux
警告2 ：在httpd的配置文件/usr/local/apache/conf/httpd.conf中的ServerName行中改为 ServerName linux:80

## 开机启动
修改启动脚本
```bash
cp /usr/local/apache/bin/apachectl /etc/init.d/httpd

vim /etc/init.d/httpd
在#!/bin/bash下加入

#chkconfig:345 61 61
#description:Apache httpd
```
设置开机启动
```bash
chkconfig --add httpd
chkconfig --level 345 httpd on
```

# 安装php
## 下载php
```bash
wget http://cn2.php.net/get/php-5.4.45.tar.bz2/from/this/mirror
```

## 解压
```bash
mv mirror php-5.4.45.tar.bz2
tar -jxvf php-5.4.45.tar.bz2
```

## 编译安装
```bash
cd php-5.4.45

./configure --prefix=/usr/local/php --with-apxs2=/usr/local/apache/bin/apxs --with-config-file-path=/usr/local/php/etc --with-mysql=/usr/local/mysql --with-libxml-dir --with-gd --with-jpeg-dir --with-png-dir --with-freetype-dir  --with-iconv-dir --with-zlib-dir --with-bz2 --with-openssl --with-mcrypt --enable-soap  --enable-gd-native-ttf --enable-mbstring --enable-sockets --enable-exif  --disable-ipv6

#出现错误：
configure: error: jpeglib.h not found.
	
# 解决方法：
yum install -y libjpeg-devel
	
#出现错误：
configure: error: mcrypt.h not found.
	
#解决方法：
wget http://www.lishiming.net/data/attachment/forum/epel-release-6-8_32.noarch.rpm #CentOS的yum扩展源
rpm -ivh epel-release-6-8_32.noarch.rpm
yum install -y libmcrypt-devel

make

make install
```
- /usr/local/php/bin/php -m :查看静态模块
- /usr/local/php/bin/php -i ：查看相关配置

## 修改配置文件
```bash
cp /usr/src/php-5.4.45/php.ini-production /usr/local/php/etc/php.ini

vim /usr/local/apache/conf/httpd.conf

在
AddType application/x-compress .Z
AddType application/x-gzip .gz .tgz

两行下加入
AddType application/x-httpd-php .php

将
DirectoryIndex index.html
后添加 1.php
DirectoryIndex index.html 1.php
```

## 测试
在Apache的安装文件中添加php文件
/usr/local/apache/htdocs/目录下创建
vim 1.php
```php5
<?php
    echo "Welcome to 1.php" ;
?>
```


