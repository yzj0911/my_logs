---
title: "GMP"
date: 2022-04-12T21:26:15+08:00
draft: true
---

# GMP模型

## M

M代表内核级线程,一个M就是一个线程,goroutine就是跑在M之上的;M是一个很大的结构,里面维护了小对象内存cache、当前执行的goroutine、随机数发生器

等等。M的PC寄存器存储着指向G的函数。

```go
type m struct {
	g0 *g // 带有调度栈的goroutine
    gsignal *g // 处理信号的goroutine
    tls [6]uintptr
    mstartfn func()
    curg	*g //当前运行的goroutine
    caughtsig guintptr
    p		puintptr //关联p和执行的go代码
    nextp	puintptr
    id		int32
    mallocing int32 // 状态
    
    spinning bool // m是否out of work
    blocked bool // m是否被阻塞
    inwb	bool // m是否在执行写屏蔽
    
    printlock int8 
    incgo bool //m在执行cgo吗
    fastrand      uint32
    ncgocall      uint64      // cgo调用的总数
    ncgo          int32       // 当前cgo调用的数目
    park          note
    alllink       *m // 用于链接allm
    schedlink     muintptr
    mcache        *mcache // 当前m的内存缓存
    lockedg       *g // 锁定g在当前m上执行，而不会切换到其他m
    createstack   [32]uintptr // thread创建的栈
}
```



## G

G代表一个goroutine,它有一个自己的栈,instrtuction pointer和其他的信息(正在等待的channel等等),用于调度。

```go
type g struct {
    stack stack //描述了真实的内存,包括上下界
    
    m *m // 当前的m
    sced gobuf // goroutine切换时,用于保存g的上下文
    param unsafe.Pointer // 用于传递参数, 睡眠时其他goroutine可以设置param, 唤醒时该goroutine可以获取
    atomicstatus uint32
    stackLock	uint32
    goid int64 //goroutine的ID
    waitsince int64 // g被阻塞的大体时间
    lockedm *m // G被锁定只在这个m上运行
}
```

```go
type gobuf struct {
	sp uintptr
    pc uintptr
    g guintptr
    ctxt unsafe.Pointer
    ret sys.Uintreg
    lr uintptr
    bp uinptr
}
```

保存了当前的栈指针、计数器、当然还有g自身,这里记录自身g的指针是为了快速访问到goroutine中的信息。

### P

P代表Processor,逻辑处理器,它的主要用途是用来执行goroutine的,所以它也维护了一个goroutine队列,里面存储了所有需要它来执行的goroutine,P/M需要进行绑定,构成一个执行单元。

```go
type p struct {
    lock mutex
    
    id int32
    status uint32 // 状态可以为pidle/prunning/...
    link 	puintptr
    schedtick uint32 //每调度一次加1
    syscalltick uint32 //每调度一次系统调用加1
    m			muintptr // 回链到关联的m
    mcache		*mcache
    racectx		uintptr
    
    goidcache	uint64 //goroutine的ID的缓存
    goidcacheend uint64 
    
    // 可运行的goroutine的队列
    runqhead uint32
    runqtail uint32
    runq	[256]guintptr
    
    runnext guintptr // 下一个运行的g
    
    sudogcache []*sudog
    sudogbuf [128]*sudog
    
    palloc persistentAlloc
    
    pad [sys.CacheLineSize]byte
}
```



## Sched

Sched代表调度器,它维护有存储M和G的队列以及调度器的一些状态信息等。

```go
type schedt struct {
	goidgen  uint64
    lastpoll uint64

    lock mutex

    midle        muintptr // idle状态的m
    nmidle       int32    // idle状态的m个数
    nmidlelocked int32    // lockde状态的m个数
    mcount       int32    // 创建的m的总数
    maxmcount    int32    // m允许的最大个数

    ngsys uint32 // 系统中goroutine的数目，会自动更新

    pidle      puintptr // idle的p
    npidle     uint32
    nmspinning uint32 

    // 全局的可运行的g队列
    runqhead guintptr
    runqtail guintptr
    runqsize int32

    // dead的G的全局缓存
    gflock       mutex
    gfreeStack   *g
    gfreeNoStack *g
    ngfree       int32

    // sudog的缓存中心
    sudoglock  mutex
    sudogcache *sudog
}
```



## GMP调度

新创建的Goroutine会存放在Global全局队列中,等待Go调度器进行调度,随后Goroutine被分配给其中的一个逻辑处理器P,并放到这个逻辑处理器对应的Local本地运行队列中,最终等待被逻辑处理器P执行即可。在M与P绑定后,M会不断从P的Local队列中无锁地取出G,并切换到G的堆栈执行,当P的Local队列中没有G时,再从Global队列中获取一个G,当Global队列中也没有待运行的G时,则尝试从其他的P窃取部分G来执行相当于P之间的负载均衡。

![img](https://github.com/KeKe-Li/data-structures-questions/raw/master/src/images/65.jpg)

从上图可以看到,有2个物理线程M,每一个M都拥有一个处理器P,每一个也都有一个正在运行的goroutine。P的数量可以通过GOMAXPROCS()设置,它其实也就代表了真正的并发度,即有多少个goroutine可以同时运行。

图中灰色的那些goroutine并没有运行,而是处于ready的就绪态,正在等待被调度。P维护着这个队列(称之为runqueue),Go语言里,启动一个goroutine很容易:go function 就行,所以每有一个go语句被执行,runqueue中队列就在其末尾加入一个goroutine,在下一个调度点,就从runqueue中取出一个goroutine执行。




![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/GMP.jpeg)