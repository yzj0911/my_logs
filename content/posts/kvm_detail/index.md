---
title: "KVM介绍"
date: 2021-12-03T10:17:16+08:00
draft: false
---


# KVM介绍


# KVM 概述

KVM (Kernal-base Virtual Machine) 基于内核的虚拟机。是一种通过修改 linux 内核实现虚拟化功能的半虚拟化技术。由于是在内核基础上运行，所有具有接近物理机的高性能。

# KVM 和 Qemu 
Qemu（quick emulator）开源的软件虚拟化实现，通过软件来模拟硬件的功能，但缺点是性能低。通过和 KVM 相结合来提高性能。现在的版本已经内置 KVM。

# 全虚拟化和半虚拟化

全虚拟化是指不需要修改操作系统内核实现虚拟化功能，半虚拟化则需要修改内核来实现虚拟化。

KVM 就是一种半虚拟化实现。

全虚拟化又分为软件全虚拟化 (Qemu) 和硬件全虚拟化(Xen)。

# KVM 工具集合
- libvirt：操作和管理KVM虚机的虚拟化 API，使用 C 语言编写，可以由 Python,Ruby, Perl, PHP, Java 等语言调用。可以操作包括 KVM，vmware，XEN，Hyper-v, LXC 等在内的多种 Hypervisor。
- Virsh：基于 libvirt 的 命令行工具 （CLI）
- Virt-Manager：基于 libvirt 的 GUI 工具
- virt-v2v：虚机格式迁移工具
- virt-* 工具：包括 Virt-install （创建KVM虚机的命令行工具）， Virt-viewer （连接到虚机屏幕的工具），Virt-clone（虚机克隆工具），virt-top 等
- sVirt：安全工具

# KVM 文章
- [KVM介绍](https://www.cnblogs.com/sammyliu/p/4543110.html)
- [KVM源码分析](https://www.cnblogs.com/LoyenWang/p/13510925.html)


