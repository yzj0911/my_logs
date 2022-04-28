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





# golang GMP模式（golang 的调度模式）

CSP（communicating sequential processes）并发模型。不同于传统的多线程通过共享内存来通信，CSP讲究的是“以通信的方式来共享内存”。不要以共享内存的方式来通信，相反，要通过通信来共享内存。


- M指的是Machine，一个M直接关联了一个内核线程。
- P指的是”processor”，代表了M所需的上下文环境，也是处理用户级代码逻辑的处理器。
- G指的是Goroutine，其实本质上也是一种轻量级的线程。


M关联了一个内核线程，通过调度器P（上下文）的调度，可以连接1个或者多个G,相当于把一个内核线程切分成了了N个用户线程，M和P是一对一关系（但是实际调度中关系多变），通过P调度N个G（P和G是一对多关系），实现内核线程和G的多对多关系（M:N），通过这个方式，一个内核线程就可以起N个Goroutine，同样硬件配置的机器可用的用户线程就成几何级增长，并发性大幅提高。



## PMG中切换正在等待或者阻塞的协程

### gopark函数
gopark函数在协程的实现上扮演着非常重要的角色，用于协程的切换，协程切换的原因一般有以下几种情况：

- 系统调用；
- channel读写条件不满足；
- 抢占式调度时间片结束；

gopark函数做的主要事情分为两点：

- 解除当前goroutine的m的绑定关系，将当前goroutine状态机切换为等待状态；
- 调用一次schedule()函数，在局部调度器P发起一轮新的调度。

下面我们来研究一下gopark函数是怎么实现协程切换的。

先看看源码：
```go
func gopark(unlockf func(*g, unsafe.Pointer) bool, lock unsafe.Pointer, reason waitReason, traceEv byte, traceskip int) {
    if reason != waitReasonSleep {
        checkTimeouts() // timeouts may expire while two goroutines keep the scheduler busy
    }
    mp := acquirem()
    gp := mp.curg
    status := readgstatus(gp)
    if status != _Grunning && status != _Gscanrunning {
        throw("gopark: bad g status")
    }
    mp.waitlock = lock
    mp.waitunlockf = *(*unsafe.Pointer)(unsafe.Pointer(&unlockf))
    gp.waitreason = reason
    mp.waittraceev = traceEv
    mp.waittraceskip = traceskip
    releasem(mp)
    // can't do anything that might move the G between Ms here.
    mcall(park_m)
}
```
源码里面最重要的一行就是调用 ```mcall(park_m)``` 函数，```park_m``` 是一个函数指针。```mcall``` 在golang需要进行协程切换时被调用，做的主要工作是：

1. 切换当前线程的堆栈从g的堆栈切换到g0的堆栈；
2. 并在g0的堆栈上执行新的函数fn(g)；
3. 保存当前协程的信息( PC/SP存储到g->sched)，当后续对当前协程调用goready函数时候能够恢复现场；
mcall函数执行原理

mcall的函数原型是：

```go
func mcall(fn func(*g))
```
这里函数fn的参数g指的是在调用mcall之前正在运行的协程。

我们前面说到，```mcall```的主要作用是协程切换，它将当前正在执行的协程状态保存起来，然后在`m->g0` 的堆栈上调用新的函数。 在新的函数内会将之前运行的协程放弃，然后调用一次`schedule()`来挑选新的协程运行。 ( 也就是在fn函数里面会调用一次`schedule()`函数进行一次scheduler的重新调度，让m去运行其余的goroutine )

mcall函数是通过汇编实现的，在asm_amd64.s里面有64位机的实现，源码如下：

```go
// func mcall(fn func(*g))
// Switch to m->g0's stack, call fn(g).
// Fn must never return. It should gogo(&g->sched)
// to keep running g.
TEXT runtime·mcall(SB), NOSPLIT, $0-8
    //DI中存储参数fn
    MOVQ    fn+0(FP), DI
    
    get_tls(CX)
    // 获取当前正在运行的协程g信息
    // 将其状态保存在g.sched变量
    MOVQ    g(CX), AX    // save state in g->sched
    MOVQ    0(SP), BX    // caller's PC
    MOVQ    BX, (g_sched+gobuf_pc)(AX)
    LEAQ    fn+0(FP), BX    // caller's SP
    MOVQ    BX, (g_sched+gobuf_sp)(AX)
    MOVQ    AX, (g_sched+gobuf_g)(AX)
    MOVQ    BP, (g_sched+gobuf_bp)(AX)


    // switch to m->g0 & its stack, call fn
    MOVQ    g(CX), BX
    MOVQ    g_m(BX), BX
    MOVQ    m_g0(BX), SI
    CMPQ    SI, AX    // if g == m->g0 call badmcall
    JNE    3(PC)
    MOVQ    $runtime·badmcall(SB), AX
    JMP    AX
    MOVQ    SI, g(CX)    // g = m->g0
    // 切换到m->g0堆栈
    MOVQ    (g_sched+gobuf_sp)(SI), SP    // sp = m->g0->sched.sp
    // 参数AX为之前运行的协程g
    PUSHQ    AX
    MOVQ    DI, DX
    MOVQ    0(DI), DI
     // 在m->g0堆栈上执行函数fn
    CALL    DI
    POPQ    AX
    MOVQ    $runtime·badmcall2(SB), AX
    JMP    AX
    RET
```
上面的汇编代码我也不是很懂，但是能够大致能够推断出主要做的事情：

1. 保存当前goroutine的状态(PC/SP)到g->sched中，方便下次调度；
2. 切换到m->g0的栈；
3. 然后g0的堆栈上调用fn；
4. 回到gopark函数里面，我们知道mcall会切换到m->g0的栈，然后执行park_m函数

下面看一下park_m函数源码：

```go
func park_m(gp *g) {
    // g0
    _g_ := getg()


    if trace.enabled {
        traceGoPark(_g_.m.waittraceev, _g_.m.waittraceskip)
    }
    //线程安全更新gp的状态，置为_Gwaiting
    casgstatus(gp, _Grunning, _Gwaiting)
    // 移除gp与m的绑定关系
    dropg()


    if _g_.m.waitunlockf != nil {
        fn := *(*func(*g, unsafe.Pointer) bool)(unsafe.Pointer(&_g_.m.waitunlockf))
        ok := fn(gp, _g_.m.waitlock)
        _g_.m.waitunlockf = nil
        _g_.m.waitlock = nil
        if !ok {
            if trace.enabled {
                traceGoUnpark(gp, 2)
            }
            casgstatus(gp, _Gwaiting, _Grunnable)
            execute(gp, true) // Schedule it back, never returns.
        }
    }
    // 重新做一次调度
    schedule()
}
```
park_m函数主要做的几件事情就是：

1. 线程安全更新goroutine的状态，置为_Gwaiting 等待状态；
2. 解除goroutine与OS thread的绑定关系；
3. 调用schedule()函数，调度器会重新调度选择一个goroutine去运行；
4. schedule函数里面主要调用路径就是：

```go
schedule()–>execute()–>gogo()
```
gogo函数的作用正好相反，用来从gobuf中恢复出协程执行状态并跳转到上一次指令处继续执行。因此，其代码也相对比较容易理解，当然，其实现也是通过汇编代码实现的。


## goready函数：

goready函数相比gopark函数来说简单一些，主要功能就是唤醒某一个goroutine，该协程转换到runnable的状态，并将其放入P的local queue，等待调度。

```go
func goready(gp *g, traceskip int) {
    // 切换到g0的栈
    systemstack(func() {
        ready(gp, traceskip, true)
    })
}
```

该函数主要就是切换到g0的栈空间然后执行ready函数。

下面我们看看ready函数源码(删除非主流程代码)：

```go
// Mark gp ready to run.
func ready(gp *g, traceskip int, next bool) {
    status := readgstatus(gp)


    // Mark runnable.
    _g_ := getg()//g0
    _g_.m.locks++ // disable preemption because it can be holding p in a local var
    if status&^_Gscan != _Gwaiting {
        dumpgstatus(gp)
        throw("bad g->status in ready")
    }


    //设置gp状态为runnable，然后加入到P的可运行local queue;
    casgstatus(gp, _Gwaiting, _Grunnable)
    runqput(_g_.m.p.ptr(), gp, next)
    if atomic.Load(&sched.npidle) != 0 && atomic.Load(&sched.nmspinning) == 0 {
        wakep()
    }
    _g_.m.locks--
    if _g_.m.locks == 0 && _g_.preempt { // restore the preemption request in Case we've cleared it in newstack
        _g_.stackguard0 = stackPreempt
    }
}
```







