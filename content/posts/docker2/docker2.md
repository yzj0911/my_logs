---
title: "Docker2"
date: 2022-05-27T14:48:41+08:00
draft: true
tags: ["Docker"]
series: [""]
categories: ["Docker"]
---

# Docker

|组成	 |描述
| ------------------------------------------------------------ | ------------------------------------------------------------ |
|Image  |Docker镜像，用于创建Docker容器的模板
|Container	|Docker容器，独立运行的一个或一组应用
|Client	|Docker客户端，使用Docker Api与Docker的守护进程通信
|Host	|Docker主机，一个物理或者虚拟的机器用于执行Docker守护进程和容器
|Registry	|Docker仓库，用来保护镜像
|Machine	|一个简化Docker安装的命令行工具，比如VirtualBox、Digital OcEAN、Microsoft Azure



## Image（镜像）

      镜像的本质是磁盘上一系列文件的集合。Docker镜像文件，提供了一个快速部署的模板，包含了已经打包好的应用程序和运行环境，基于image可以快速部署多个相同的容器。

      Docker镜像是一个特殊的文件系统，除了提供容器运行时所需的程序、库、资源、配置文件外，还包含了一些为运行时准备的一些配置参数，镜像不包含任何动态数据，其内容在构建之后也不会改变。
      镜像包含OS完整的Root文件系统，其体积往往是庞大的，因此在Docker设计时，充分利用了Union FS的技术，设计为分层存储的架构，所以严格意义来说，镜像只是一个虚拟的概念，其由多层文件系统联合组成。

      镜像构建时，前一层是后一层的基础，每一层构建完不会再发生改变，后一层的任何改变只发生在自己这一层。分层存储的特征还使得镜像的复用、定制变得更加容易。

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/Image文件图.png)


镜像就是上图中加锁部分的一层层（`Image layer`）只读层（`read-only layer`），可以是一层或者多层构成。而容器则只是在 **镜像** 上添加一个可写层（`read-write-layer`）。已经构建的镜像会设置成只读模式。层与层之间不相互影响，除了底层外，其它层都会有一个指针指向下一层，Docker的统一文件系统（union file system）技术将不同的层整合成一个文件系统，为这些层提供了一个统一视角，这样便隐藏了多层的存在，在用户视角看来只存在一个文件系统。


## Docker基本操作
1. docker info|version|帮助命令
```bash
docker version 	#查看docker的版本信息
docker info 	#查看docker系统信息，包括镜像和容器以及部分配置信息
docker --help 	#docker帮助命令
```
2. 容器声明周期管理命令
```bash
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
	docker run -i [CONTAINER NAME]				#以交互模式运行容器，通常与-t同时使用
	docker run -t [CONTAINER NAME]				#为容器重新分配一个伪输入终端，通常与-i同时使用
	docker run --name [CONTAINER NAME]			#设置容器名称
	docker run -P 								#随机端口映射
	docker run -p [HOST PORT]:[CONTAINER PORT]	#指定端口映射，映射主机和容器内的端口
	docker run -e [ENV NAME]=[ENV VALUE]		#添加环境变量,如username="admin"
	docker run -d 								#后台运行，并返回容器ID
	docker run -v [HOST FOLDER PATH]:[CONTAINER FOLDER PATH]	#将主机目录挂在到容器内，可挂载多个目录如：docker run --name nginx81 -d -p 81:80 -v /data/nginx/html:/usr/share/nginx/html -v /data/nginx/conf/nginx.conf:/etc/nginx/nginx.conf  -v /data/nginx/logs:/var/log/nginx -v /data/nginx/conf.d:/etc/nginx/conf.d -d nginx:latest
docker start [CONTAINER ID|NAME]	#启动容器(指定容器ID或名称)
docker restart [CONTAINER ID|NAME]	#重新启动容器
docker stop [CONTAINER ID|NAME]		#停止容器
docker kill [CONTAINER ID|NAME] #杀掉一个运行中的容器
	docker kill -s [CONTAINER ID|NAME] #向容器发送一个信号，并杀掉运行中容器
docker rm [CONTAINER ID] #删除容器
	docker rm -f [CONTAINER ID]	#强制删除容器
	docker rm -f $(docker ps -a -q)		#删除多个容器
docker pause CONTAINER [CONTAINER ID|NAME] 	#暂停容器中所有的进程
docker unpause CONTAINER [CONTAINER ID|NAME]#恢复容器中所有的进程
docker create --name [NAME] [CONTAINER][:TAG] #创建一个新的容器但不启动它，如 docker create --name myJava java:latest 
docker exec -it [CONTAINER NAME|ID] /bin/bash	#进入容器内
docker exec -it [CONTAINER NAME|ID] ping [CONTAINER NAME|ID]	#一个容器ping另外一个容器
```
3. 容器操作
```bash
docker ps #列出当前所有正在运行的容器
	docker ps -q					#列出所有的容器
	docker ps -l					#列出最近创建的容器
	docker ps -n 3					#3列出最近创建的3个容器
	docker ps -q					#只显示容器ID
	docker ps --no-trunc			#显示当前所有正在运行的容器完整信息
	docker ps -f "status=exited"	#显示所有退出的容器
	docker ps -a -q					#显示所有容器id
	docker ps -f "status=exited" -q	#显示所有退出容器的id
docker inspect [CONTAINER NAME|ID] 	#查看容器/镜像的元数据
docker top [CONTAINER ID] #查看容器内运行的进程
docker attach [CONTAINER ID] 		#连接到正在运行中的容器，直接进入容器终端的命令，不启动新的进程
docker logs [CONTAINER ID] #显示运行容器的日志
	docker logs -f [CONTAINER ID] 				#跟踪实时日志输出
	docker logs --since=[TIME][CONTAINER ID]	#显示某个开始时间的所有日志，如 --since="2021-01-01" 即指定日期； --since=30m 即最近30分钟； --since="2021-02-08T13:23:37" --until "2021-02-09T12:23:37"；--since="2018-02-08T13:23:37"
	docker logs -t [CONTAINER ID]				#显示时间戳，即查看日志产生日期
	docker logs --tail=[N] [CONTAINER ID]		#仅列出最新(最后面)N条容器日志 如 docker logs -f -t --since=”2021-07-10” --tail=10 f9e29e8455a5
docker wait [CONTAINER ID] #阻塞运行直到容器停止，然后打印出它的退出代码
docker export [CONTAINER NAME|ID] > xxx.tar #导出的是容器，文件系统作为一个 tar 归档文件
	docker export -o xxx.tar [CONTAINER NAME] 
docker port [CONTAINER ID|NAME] 	#列出指定的容器的端口映射
docker stats #显示容器统计信息(正在运行)
    docker stats -a	#显示所有容器的统计信息(包括没有运行的)
    docker stats -a --no-stream	#显示所有容器的统计信息(包括没有运行的) ，只显示一次
    docker stats --no-stream | sort -k8 -h	#统计容器信息并以使用流量作为倒序
docker system 
	docker system df           #显示硬盘占用
	docker system events       #显示容器的实时事件
	docker system info         #显示系统信息
	docker system prune        #清理文件
exit		#退出并停止容器
Ctrl+p+q	#只退出容器，不停止容器
```
4. 容器rootfs命令
```bash
docker commit -m "提交备注信息" -a "作者名称" [CONTAINER ID] [TARGET CONTAINER NAME]:[TAG] #提交容器使之成为一个新的镜像，如 docker commit -m "新的tomcat" -a "alone" f9e29e8455a5 mytomcat:1.2
docker cp [CONTAINER ID]:[CONTAINER PATH] [HOST PATH] #从指定容器内路径下文件拷贝到主机指定路径中 如 docker cp 2drf43u1y8dfe:/tmp/test.log /root
docker diff [CONTAINER ID|NAME]		#检查容器里文件结构的更改，如 docker diff mymysql
```
5. 镜像仓库命令
```bash
docker login -u [USER NAME] -p [PASSWORD] [SERVER] #登陆到一个Docker镜像仓库,如果未指定[server]镜像仓库地址，默认为官方仓库 Docker Hub
docker logout [SERVER]	#登出一个Docker镜像仓库，如果未指定[SERVER]镜像仓库地址，默认为官方仓库Docker Hub 如 docker logout
docker pull [NAME] #下载镜像
	docker pull -a [NAME] #下载REPOSITORY为指定名称的所有镜像
docker push [DOCKER USER NAME]/[REPOSITORY][:TAG]	#将本地的镜像上传到镜像仓库,要先登陆到镜像仓库
docker search [NAME] #从仓库中搜索指定镜像，如 docker search nginx
	docker search --no-trunc [NAME] 	#显示完整的镜像描述
	docker search -s [NUM] [NAME] 		#列出收藏数不小于指定值的镜像
	docker search --automated [NAME] 	#只列出 automated build类型的镜像
```
6. 本地镜像管理命令
```bash
docker images #查看本地主机上的镜像
	docker images -a 			#列出本地所有的镜像（含中间镜像层）
	docker images -q 			#只显示镜像ID
	docker images --digests 	#显示镜像的摘要信息
	docker images --no-trunc 	#显示完整的镜像信息
docker rmi [NAME/ID] #删除镜像（根据镜像名/镜像ID）
	docker rmi -f [NAME|ID] 			#强制删除单个镜像
	docker rmi -f [NAME|ID] [NAME|ID] 	#强制删除多个镜像
	docker rmi -f $(docker images -qa) 	#强制删除全部镜像
docker tag [NAME][:TAG] [REGISTRYHOST/][USERNAME/][NAME][:TAG] #标记本地镜像， 将其归入某一仓库
docker build -t [NAME][:TAG] [PATH] #Dockerfile 创建镜像
docker history [NAME][:TAG] #查看指定镜像的创建历史
docker save [NAME][:TAG] > xxx.tar #将镜像保存成 tar 归档文件
	docker save -o xxx.tar [NAME][:TAG]
docker load < xxx.tar #从归档文件加载镜像
	docker --input xxx.tar
docker import [file|URL]- [REPOSITORY[:TAG]] #从归档文件中创建镜像，如 docker import http://example.com/example
```
