# Kubernetes


# Kubernetes 

高可用集群的副本数量最好是 >=3 的奇数个数量

kubernetes 基础组件:
1. APISERVER: 所有服务访问的同意口径
2. Crontroller-Manager: 持续副本期望数目
3. Scheduler : 负责介绍任务，选择最合适的节点，进行任务的执行
4. Etcd : 键值对数据库，负责存储k8s集群中，所有重要信息( 自带持久化 )
5. Kubelet : 直接跟容器引擎交，实现容器的生命周期管理
6. Kube-Proxy : 负责写入规则到 IPTABLES,IPVS 实现服务映射访问
7. CoreDNS : 可以为集群中的SVC创建一个域名IP的对应关系解析
8. Dashboard : 给k8s 集群体提供一个B/S 结构访问体系
9. InGress controller : 官方实现四层代理。他可以实现七层代理
10. FEDERATION : 提供一个可以跨集群中心 多K8s 统一管理功能
11. PROMETHEUS ：提供K8s 集群的监控能力
12. ELK : 提供K8S 集群日志统一分析介入平台


## Pod 


