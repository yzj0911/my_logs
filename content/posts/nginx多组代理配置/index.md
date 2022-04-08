---
title: "Nginx多组代理配置"
date: 2021-12-03T10:17:16+08:00
draft: false
---

# Nginx多组代理配置



# 一、需求
具体实现以下功能：使用 nginx 作为对外的服务机器，让客户端通过访问 nginx 所在的IP+端口的方式能访问内部多个系统，这样一来通过对单台机器作访问控制就可以保证内部系统的访问安全。实现思路如下：在对外的机器上部署 nginx 服务，通过 nginx 虚拟机功能和代理功能相结合实现多组代理。具体场景如下：


| 代理服务器 | 代理服务 |
| :---: | :---: |
| nginx 192.168.10.10:8080 | 192.168.10.11:8080 |
| nginx 192.168.10.10:8081 | 192.168.10.11:9000 |




# 二、环境
测试环境如下：

- 代理服务器：ip 192.168.10.10；系统 CentOS7 ; 
- 需要代理的服务：192.168.10.11:8080 nginx ；192.168.10.11:9000 tomcat




# 三、配置代理
假如有两个服务需要配置代理，一个 web，一个 tomcat。web 运行在 192.168.10.11:8080
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110455.png)

tomcat 运行在 192.168.10.11:9000
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110507.png)

现在配置 nginx 代理。
**1.安装 nginx**先在代理服务器上安装 nginx，使用命令：

```bash
$ yum install -y nginx
```

安装成功后就可以尝试启动 nginx 服务器：

```bash
$ systemctl start nginx
```

启动服务成功后，nginx 就运行在 80 端口。
**2.修改配置文件**安装nginx就可以修改配置文件，配置文件的默认路径为 

```bash
$ ll /etc/nginx/nginx.conf
-rw-r--r-- 1 root root 1822 Nov 24 19:30 /etc/nginx/nginx.conf
```

修改 nginx.conf 如下

```bash
# 系统用户
user nginx;
# 工作进程数，配置高的机器可以适当增加
worker_processes 4;
# 错误日志
error_log /var/log/nginx/error.log;
# pid 文件存放目录
pid /run/nginx.pid;


events {
    # linux 使用 epoll 事件机制
    use epoll;
    # 连接数
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    # 配置虚拟机，在该目录下配置多个配置文件对应多台需要代理的机器
    include /etc/nginx/conf.d/*.conf;

# 配置 https
# Settings for a TLS enabled server.
#
#    server {
#        listen       443 ssl http2 default_server;
#        listen       [::]:443 ssl http2 default_server;
#        server_name  _;
#        root         /usr/share/nginx/html;
#
#        ssl_certificate "/etc/pki/nginx/server.crt";
#        ssl_certificate_key "/etc/pki/nginx/private/server.key";
#        ssl_session_cache shared:SSL:1m;
#        ssl_session_timeout  10m;
#        ssl_ciphers HIGH:!aNULL:!MD5;
#        ssl_prefer_server_ciphers on;
#
#        # Load configuration files for the default server block.
#        include /etc/nginx/default.d/*.conf;
#
#        location / {
#        }
#
#        error_page 404 /404.html;
#            location = /40x.html {
#        }
#
#        error_page 500 502 503 504 /50x.html;
#            location = /50x.html {
#        }
#    }

}
```

注意 23 行的配置：`include /etc/nginx/conf.d/*.conf;` 这个目录下就是要存放代理的配置文件。一般这个文件默认是存在的，如果目录不存在，就创建并修改权限。

```bash
$ mkdir /etc/nginx/conf.d
$ chmod 755 /etc/nginx/conf.d
```

**3.配置代理文件**在这个目录下存放代理服务的文件，最好一个代理对应一个配置文件。我们之前需求上需要代理的服务是两个，直接创建两个代理文件，并修改

```bash
# /etc/nginx/conf.d/nginx.conf 
# 代理的节点
# upstream <代理名称 唯一>
upstream nginx_server {
  # 代理的ip:port,可添加多个ip地址就行负载均衡
  server 192.168.10.11:8080;
}

server 
{
  # 监听的地址和端口
  # 对应一个代理一个端口
  listen       192.168.10.10:8080;
  # 对外的域名 
  server_name  aaa.test.com;
  location / {
    # 代理配置，名称和以上的代理名称对应 
    proxy_pass http://nginx_server;
    # 配置使用真实的地址访问，如果不配置此项会导致代理tomcat服务器 400 错误
    proxy_set_header Host $host;
  }   
}
```


```bash
# cat /etc/nginx/conf.d/tomcat.conf 
upstream tomcat_server {
  server 192.168.10.11:9000;
}

server 
{
  listen       192.168.10.10:8081; 
  server_name  bbb.test.com;
  location / { 
    proxy_pass http://tomcat_server;
    proxy_set_header Host $host;
  }   
}
```

修改并保存后，使用 nginx 命令来验证文件的语法：

```bash
$ # nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

之后就可以重启 nginx 服务

```bash
$ systemctl restart nginx
$ netstat -tnlp | grep nginx
tcp        0      0 192.168.10.10:8080      0.0.0.0:*               LISTEN      11643/nginx: master 
tcp        0      0 192.168.10.10:8081      0.0.0.0:*               LISTEN      11643/nginx: master
```

可以看到成功绑定两个端口，代理两个服务。通过浏览器访问8080和8081![image.png]
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110527.png)

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20201030110541.png)

到这里配置就完成了。如果需要再代理，在 /etc/nginx/conf.d 目录下再添加相应的配置文件就可以。如果没有访问成功，请检查各种防火墙和安全策略。


