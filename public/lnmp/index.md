# 

# 搭建lnmp环境


# 搭建lnmp环境

![](http://image.xingyys.club/blog/linux.png)
lnmp即：nginx + mysql + php
与lamp不同的是，lnmp的php不在只是httpd中的一个库，lnmp架构中php作为一个服务，专门解析php。
同样的php依赖mysql，所以首先安装mysql
这里环境为CentOS6.5
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

# 安装php
## 下载
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

./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc  --enable-fpm   --with-fpm-user=php-fpm  --with-fpm-group=php-fpm   --with-mysql=/usr/local/mysql --with-mysql-sock=/tmp/mysql.sock --with-libxml-dir  --with-gd   --with-jpeg-dir   --with-png-dir   --with-freetype-dir  --with-iconv-dir   --with-zlib-dir   --with-mcrypt   --enable-soap   --enable-gd-native-ttf   --enable-ftp --enable-mbstring --enable-exif --enable-zend-multibyte --disable-ipv6 --with-pear  --with-curl

# 出现错误：
configure: error: jpeglib.h not found.
	
#解决方法：
yum install -y libjpeg-devel
	
#出现错误：
configure: error: mcrypt.h not found.
	
# 解决方法：
wget http://www.lishiming.net/data/attachment/forum/epel-release-6-8_32.noarch.rpm #CentOS的yum扩展源
rpm -ivh epel-release-6-8_32.noarch.rpm
yum install -y libmcrypt-devel
	 
make

make install
```

- /usr/local/php/bin/php -m :查看静态模块
- /usr/local/php/bin/php -i ：查看相关配置

## php的配置文件
```bash
cp /usr/src/php-5.4.45/php.ini-production /usr/local/php/etc/php.ini
```

## php开机启动
```bash
cp /usr/src/php-5.4.45/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
mv /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf  #服务启动的脚本配置文件
```
```bash
chkconfig --add php-fpm
chkconfig --level 345 php-fpm on
```

## 启动php
```bash
useradd -s /sbin/nologin php-fpm
chmod +x /etc/init.d/php-fpm
service php-fpm start
```

# 安装nginx
## 下载nginx
```bash
cd /usr/src
wget http://nginx.org/download/nginx-1.6.2.tar.gz
```

## 解压
```bash
tar -xvf nginx-1.6.2.tar.gz
```

## 编译安装
```bash
./configure --prefix=/usr/local/nginx --with-pcre

#出现错误：
./configure: error: the HTTP rewrite module requires the PCRE library.
  
#解决方法： 

yum install -y pcre-devel

make

make install
```
## 启动
编辑启动脚本
```bash
vim /etc/init.d/nginx

#!/bin/bash
# chkconfig: - 30 21
# description: http service.
# Source Function Library
. /etc/init.d/functions
# Nginx Settings

NGINX_SBIN="/usr/local/nginx/sbin/nginx"
NGINX_CONF="/usr/local/nginx/conf/nginx.conf"
NGINX_PID="/usr/local/nginx/logs/nginx.pid"
RETVAL=0
prog="Nginx"

start() {
     echo -n $"Starting $prog: "
     mkdir -p /dev/shm/nginx_temp
     daemon $NGINX_SBIN -c $NGINX_CONF
     RETVAL=$?
     echo
     return $RETVAL
}

stop() {
     echo -n $"Stopping $prog: "
     killproc -p $NGINX_PID $NGINX_SBIN -TERM
     rm -rf /dev/shm/nginx_temp
     RETVAL=$?
     echo
     return $RETVAL
 }

 reload(){
     echo -n $"Reloading $prog: "
     killproc -p $NGINX_PID $NGINX_SBIN -HUP
     RETVAL=$?
     echo
     return $RETVAL
}

restart(){
     stop
     start
}

configtest(){
 $NGINX_SBIN -c $NGINX_CONF -t
 return 0
}

case "$1" in
 start)
     start
     ;;
 stop)
     stop
     ;;
 reload)
     reload
     ;;
 restart)
     restart
     ;;
 configtest)
     configtest
     ;;
 *)
     echo $"Usage: $0 {start|stop|reload|restart|configtest}"
     RETVAL=1
 esac

 exit $RETVAL
```
保存后，更改权限:
```bash
chmod 755 /etc/init.d/nginx
chkconfig --add nginx
```
开机启动
```bash
chkconfig nginx on
```
启动服务
```bash
service nginx start
```

## 测试解析php
编辑配置文件/usr/local/nginx/conf/nginx.conf
修改制定行
```bash
......
location ~ \.php$ {
	root           html;
	fastcgi_pass   127.0.0.1:9000;
	fastcgi_index  index.php;
	fastcgi_param  SCRIPT_FILENAME  /usr/local/nginx/html$fastcgi_script_name;           #路径为网站根目录
	include        fastcgi_params;
}
......
```
在/usr/local/nginx/html/下创建一个info.php文件
```php
<?php
	 phpinfo();
?>
```
浏览器访问：`http://127.0.0.1/info.php`测试


