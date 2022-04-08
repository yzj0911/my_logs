---
title: "CentOS7 安装 qemu-5.2.0"
date: 2021-12-03T10:17:16+08:00
draft: false
---

# CentOS7 安装 qemu-5.2.0


本文介绍在 CentOS7.9 上编译安装 qemu-5.2.0

# 安装 Python3
编译安装 qemu-5.2.0 依赖 Python3.6 及以上的版本。所以首先安装 Python3.6。这里选择编译安装。

## 下载 Python3.6.12
从 Python 官网下载 Python3.6.12 源码包：
```bash
wget https://www.python.org/ftp/python/3.6.12/Python-3.6.12.tar.xz
```
## 解压
```bash
tar -xvf Python-3.6.12.tar.gz 
```

## 安装 openssl
pip 下载是需要 ssl 支持，所以下载 openssl
```bash
yum install -y openssl openssl-devel zlib-devel bzip2-devel bzip2
```

## 编译安装
```bash
cd Python-3.6.12
./configure --prefix=/usr/local/python3 --enable-optimizations
make -j8 build_all && make -j8 install
```

## 设置软链接
```bash
ln -s /usr/local/python3/bin/python3 /usr/bin/python3
ln -s /usr/local/python3/bin/pip3 /usr/bin/pip3
```

## 验证
```bash
# python3
Python 3.6.12 (default, Dec 27 2020, 07:52:33)
[GCC 4.8.5 20150623 (Red Hat 4.8.5-44)] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>>
```

# 安装 ninja
qemu-5.2.0 编译时使用构建工具 ninja
下载 ninja
```bash
git clone git://github.com/ninja-build/ninja.git && cd ninja
./configure.py --bootstrap
cp ninja /usr/bin/
```
使用 `ninja --version`, 验证 ninja 版本:
```bash
# ninja --version
1.10.2.git
```

# 编译安装 qemu-5.2.0
完成以上步骤之后就可以开始安装qemu了。其实可以通过 yum 安装，但是会缺少一些二进制文件。

## 安装依赖
首先安装 qemu-5.2.0 所需的依赖，这里追加一个小提示：
> CentOS7 编译安装软件时经常需要安装对应的依赖。编译过程中如果发现缺少依赖，则编译后报错并退出，这时候就需要安装依赖包。以qemu-5.2.0安装为例，编译时提示缺少 `glib2` 包。这时候不是下载 `glib2`，而是下载对应的开发包，CentOS里是 `glib2-devel`，Ubuntu 下则是 `glib2-dev`。

```bash
yum install -y pkgconfig-devel glib2-devel pixman-devel
```
> 这里提供的依赖可能补全，编译过程中如果提示缺少依赖，请根据以上给出的提示安装对应依赖。

## 下载 qemu-5.2.0
在 qemu 官网下载源码包

```bash
wget https://download.qemu.org/qemu-5.2.0.tar.xz
```

## 编译安装
```bash
tar xvJf qemu-5.2.0.tar.xz
cd qemu-5.2.0
./configure --enable-debug --target-list=x86_64-softmmu --enable-kvm
make && make install
```

## 验证
```bash
# qemu-
qemu-edid            qemu-img             qemu-nbd             qemu-storage-daemon
qemu-ga              qemu-io              qemu-pr-helper       qemu-system-x86_64
```

