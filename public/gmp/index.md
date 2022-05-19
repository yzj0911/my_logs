# GMP


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
```go 
package runtime
// One round of scheduler: find a runnable goroutine and execute it.
// Never returns.
func schedule() {
	_g_ := getg()

	if _g_.m.locks != 0 {
		throw("schedule: holding locks")
	}

	if _g_.m.lockedg != 0 {
		stoplockedm()
		execute(_g_.m.lockedg.ptr(), false) // Never returns.
	}

	// We should not schedule away from a g that is executing a cgo call,
	// since the cgo call is using the m's g0 stack.
	if _g_.m.incgo {
		throw("schedule: in cgo")
	}

top:
	pp := _g_.m.p.ptr()
	pp.preempt = false

	if sched.gcwaiting != 0 {
		gcstopm()
		goto top
	}
	if pp.runSafePointFn != 0 {
		runSafePointFn()
	}

	// Sanity check: if we are spinning, the run queue should be empty.
	// Check this before calling checkTimers, as that might call
	// goready to put a ready goroutine on the local run queue.
	if _g_.m.spinning && (pp.runnext != 0 || pp.runqhead != pp.runqtail) {
		throw("schedule: spinning with local work")
	}

	checkTimers(pp, 0)

	var gp *g
	var inheritTime bool

	// Normal goroutines will check for need to wakeP in ready,
	// but GCworkers and tracereaders will not, so the check must
	// be done here instead.
	tryWakeP := false
	if trace.enabled || trace.shutdown {
		gp = traceReader()
		if gp != nil {
			casgstatus(gp, _Gwaiting, _Grunnable)
			traceGoUnpark(gp, 0)
			tryWakeP = true
		}
	}
	if gp == nil && gcBlackenEnabled != 0 {
		gp = gcController.findRunnableGCWorker(_g_.m.p.ptr())
		if gp != nil {
			tryWakeP = true
		}
	}
	if gp == nil {
		// Check the global runnable queue once in a while to ensure fairness.
		// Otherwise two goroutines can completely occupy the local runqueue
		// by constantly respawning each other.
		if _g_.m.p.ptr().schedtick%61 == 0 && sched.runqsize > 0 {
			lock(&sched.lock)
			gp = globrunqget(_g_.m.p.ptr(), 1)
			unlock(&sched.lock)
		}
	}
	if gp == nil {
		gp, inheritTime = runqget(_g_.m.p.ptr())
		// We can see gp != nil here even if the M is spinning,
		// if checkTimers added a local goroutine via goready.
	}
	if gp == nil {
		gp, inheritTime = findrunnable() // blocks until work is available
	}

	// This thread is going to run a goroutine and is not spinning anymore,
	// so if it was marked as spinning we need to reset it now and potentially
	// start a new spinning M.
	if _g_.m.spinning {
		resetspinning()
	}

	if sched.disable.user && !schedEnabled(gp) {
		// Scheduling of this goroutine is disabled. Put it on
		// the list of pending runnable goroutines for when we
		// re-enable user scheduling and look again.
		lock(&sched.lock)
		if schedEnabled(gp) {
			// Something re-enabled scheduling while we
			// were acquiring the lock.
			unlock(&sched.lock)
		} else {
			sched.disable.runnable.pushBack(gp)
			sched.disable.n++
			unlock(&sched.lock)
			goto top
		}
	}

	// If about to schedule a not-normal goroutine (a GCworker or tracereader),
	// wake a P if there is one.
	if tryWakeP {
		wakep()
	}
	if gp.lockedm != 0 {
		// Hands off own p to the locked m,
		// then blocks waiting for a new p.
		startlockedm(gp)
		goto top
	}

	execute(gp, inheritTime)
}
```


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



---
   
 >该文章主要详细具体的介绍Goroutine调度器过程及原理，可以对Go调度器的详细调度过程有一个清晰的理解，花    费4天时间作了30+张图(推荐收藏)，包括如下几个章节。

> 本章节含视频版:
[![](https://cdn.learnku.com/uploads/images/202201/25/58489/rxrnLas6f5.png!large)](https://www.bilibili.com/video/BV19r4y1w7Nx)

`第一章`  Golang调度器的由来

`第二章`   Goroutine调度器的GMP模型及设计思想

`第三章`  Goroutine调度场景过程全图文解析

#### 一、Golang“调度器”的由来？

##### (1) 单进程时代不需要调度器

我们知道，一切的软件都是跑在操作系统上，真正用来干活(计算)的是CPU。早期的操作系统每个程序就是一个进程，直到一个程序运行完，才能进行下一个进程，就是“单进程时代”

一切的程序只能串行发生。
![5-单进程操作系统.png](https://cdn.learnku.com/uploads/images/202003/11/58489/06IoYRyruP.png!large)


早期的单进程操作系统，面临2个问题：

1.单一的执行流程，计算机只能一个任务一个任务处理。

2.进程阻塞所带来的CPU时间浪费。



那么能不能有多个进程来宏观一起来执行多个任务呢？

后来操作系统就具有了**最早的并发能力：多进程并发**，当一个进程阻塞的时候，切换到另外等待执行的进程，这样就能尽量把CPU利用起来，CPU就不浪费了。



##### (2)多进程/线程时代有了调度器需求
![6-多进程操作系统.png](https://cdn.learnku.com/uploads/images/202003/11/58489/sLve6TagD3.png!large)

在多进程/多线程的操作系统中，就解决了阻塞的问题，因为一个进程阻塞cpu可以立刻切换到其他进程中去执行，而且调度cpu的算法可以保证在运行的进程都可以被分配到cpu的运行时间片。这样从宏观来看，似乎多个进程是在同时被运行。

但新的问题就又出现了，进程拥有太多的资源，进程的创建、切换、销毁，都会占用很长的时间，CPU虽然利用起来了，但如果进程过多，CPU有很大的一部分都被用来进行进程调度了。

**怎么才能提高CPU的利用率呢？** 

但是对于Linux操作系统来讲，cpu对进程的态度和线程的态度是一样的。
![7-cpu切换浪费成本.png](https://cdn.learnku.com/uploads/images/202003/11/58489/dNWd00AiEZ.png!large)

很明显，CPU调度切换的是进程和线程。尽管线程看起来很美好，但实际上多线程开发设计会变得更加复杂，要考虑很多同步竞争等问题，如锁、竞争冲突等。



##### (3)协程来提高CPU利用率

多进程、多线程已经提高了系统的并发能力，但是在当今互联网高并发场景下，为每个任务都创建一个线程是不现实的，因为会消耗大量的内存(进程虚拟内存会占用4GB[32位操作系统], 而线程也要大约4MB)。

大量的进程/线程出现了新的问题

* 高内存占用
* 调度的高消耗CPU



好了，然后工程师们就发现，其实一个线程分为“内核态“线程和”用户态“线程。

一个“用户态线程”必须要绑定一个“内核态线程”，但是CPU并不知道有“用户态线程”的存在，它只知道它运行的是一个“内核态线程”(Linux的PCB进程控制块)。

![8-线程的内核和用户态.png](https://cdn.learnku.com/uploads/images/202003/11/58489/TfStmYsfyF.png!large)

这样，我们再去细化去分类一下，内核线程依然叫“线程(thread)”，用户线程叫“协程(co-routine)".

![9-协程和线程.png](https://cdn.learnku.com/uploads/images/202003/11/58489/vgzlKzvOUL.png!large)


​	看到这里，我们就要开脑洞了，既然一个协程(co-routine)可以绑定一个线程(thread)，那么能不能多个协程(co-routine)绑定一个或者多个线程(thread)上呢。

​		之后，我们就看到了有3中协程和线程的映射关系：



> #### N:1关系

N个协程绑定1个线程，优点就是**协程在用户态线程即完成切换，不会陷入到内核态，这种切换非常的轻量快速**。但也有很大的缺点，1个进程的所有协程都绑定在1个线程上



缺点：

* 某个程序用不了硬件的多核加速能力
* 一旦某协程阻塞，造成线程阻塞，本进程的其他协程都无法执行了，根本就没有并发的能力了。

![10-N-1关系.png](https://cdn.learnku.com/uploads/images/202003/12/58489/kfPbThcyRU.png!large)

> #### 1:1 关系

1个协程绑定1个线程，这种最容易实现。协程的调度都由CPU完成了，不存在N:1缺点，

缺点：

* 协程的创建、删除和切换的代价都由CPU完成，有点略显昂贵了。


![11-1-1.png](https://cdn.learnku.com/uploads/images/202003/11/58489/EhNQY2VCpk.png!large)


> #### M:N关系

M个协程绑定1个线程，是N:1和1:1类型的结合，克服了以上2种模型的缺点，但实现起来最为复杂。


![12-m-n.png](https://cdn.learnku.com/uploads/images/202003/12/58489/ANDQLx3g9U.png!large)

​	协程跟线程是有区别的，线程由CPU调度是抢占式的，**协程由用户态调度是协作式的**，一个协程让出CPU后，才执行下一个协程。

​		

##### (4)Go语言的协程goroutine

**Go为了提供更容易使用的并发方法，使用了goroutine和channel**。goroutine来自协程的概念，让一组可复用的函数运行在一组线程之上，即使有协程阻塞，该线程的其他协程也可以被`runtime`调度，转移到其他可运行的线程上。最关键的是，程序员看不到这些底层的细节，这就降低了编程的难度，提供了更容易的并发。

Go中，协程被称为goroutine，它非常轻量，一个goroutine只占几KB，并且这几KB就足够goroutine运行完，这就能在有限的内存空间内支持大量goroutine，支持了更多的并发。虽然一个goroutine的栈只占几KB，但实际是可伸缩的，如果需要更多内容，`runtime`会自动为goroutine分配。



Goroutine特点：

* 占用内存更小（几kb）
* 调度更灵活(runtime调度)



##### (5)被废弃的goroutine调度器

​	好了，既然我们知道了协程和线程的关系，那么最关键的一点就是调度协程的调度器的实现了。

Go目前使用的调度器是2012年重新设计的，因为之前的调度器性能存在问题，所以使用4年就被废弃了，那么我们先来分析一下被废弃的调度器是如何运作的？

> 大部分文章都是会用G来表示Goroutine，用M来表示线程，那么我们也会用这种表达的对应关系。

![13-gm.png](https://cdn.learnku.com/uploads/images/202003/11/58489/Af6GQ3GSlb.png!large)

下面我们来看看被废弃的golang调度器是如何实现的？

![14-old调度器.png](https://cdn.learnku.com/uploads/images/202003/11/58489/uWk9pzdREk.png!large)

M想要执行、放回G都必须访问全局G队列，并且M有多个，即多线程访问同一资源需要加锁进行保证互斥/同步，所以全局G队列是有互斥锁进行保护的。



老调度器有几个缺点：

1. 创建、销毁、调度G都需要每个M获取锁，这就形成了**激烈的锁竞争**。
2. M转移G会造成**延迟和额外的系统负载**。比如当G中包含创建新协程的时候，M创建了G’，为了继续执行G，需要把G’交给M’执行，也造成了**很差的局部性**，因为G’和G是相关的，最好放在M上执行，而不是其他M'。
3. 系统调用(CPU在M之间的切换)导致频繁的线程阻塞和取消阻塞操作增加了系统开销。



#### 二、Goroutine调度器的GMP模型的设计思想

面对之前调度器的问题，Go设计了新的调度器。

在新调度器中，除了M(thread)和G(goroutine)，又引进了P(Processor)。

![15-gmp.png](https://cdn.learnku.com/uploads/images/202003/11/58489/zaZ4nQYcZe.png!large)

**Processor，它包含了运行goroutine的资源**，如果线程想运行goroutine，必须先获取P，P中还包含了可运行的G队列。



##### (1)GMP模型

在Go中，**线程是运行goroutine的实体，调度器的功能是把可运行的goroutine分配到工作线程上**。

![16-GMP-调度.png](https://cdn.learnku.com/uploads/images/202003/11/58489/Ugu3C2WSpM.jpeg!large)

1. **全局队列**（Global Queue）：存放等待运行的G。
2. **P的本地队列**：同全局队列类似，存放的也是等待运行的G，存的数量有限，不超过256个。新建G'时，G'优先加入到P的本地队列，如果队列满了，则会把本地队列中一半的G移动到全局队列。
3. **P列表**：所有的P都在程序启动时创建，并保存在数组中，最多有`GOMAXPROCS`(可配置)个。
4. **M**：线程想运行任务就得获取P，从P的本地队列获取G，P队列为空时，M也会尝试从全局队列**拿**一批G放到P的本地队列，或从其他P的本地队列**偷**一半放到自己P的本地队列。M运行G，G执行之后，M会从P获取下一个G，不断重复下去。

**Goroutine调度器和OS调度器是通过M结合起来的，每个M都代表了1个内核线程，OS调度器负责把内核线程分配到CPU的核上执行**。



> ### 有关P和M的个数问题

1、P的数量：

- 由启动时环境变量`$GOMAXPROCS`或者是由`runtime`的方法`GOMAXPROCS()`决定。这意味着在程序执行的任意时刻都只有`$GOMAXPROCS`个goroutine在同时运行。

2、M的数量:

- go语言本身的限制：go程序启动时，会设置M的最大数量，默认10000.但是内核很难支持这么多的线程数，所以这个限制可以忽略。
- runtime/debug中的SetMaxThreads函数，设置M的最大数量
- 一个M阻塞了，会创建新的M。

M与P的数量没有绝对关系，一个M阻塞，P就会去创建或者切换另一个M，所以，即使P的默认数量是1，也有可能会创建很多个M出来。

> ### P和M何时会被创建

1、P何时创建：在确定了P的最大数量n后，运行时系统会根据这个数量创建n个P。

2、M何时创建：没有足够的M来关联P并运行其中的可运行的G。比如所有的M此时都阻塞住了，而P中还有很多就绪任务，就会去寻找空闲的M，而没有空闲的，就会去创建新的M。



##### (2)调度器的设计策略

**复用线程**：避免频繁的创建、销毁线程，而是对线程的复用。

1）work stealing机制

​		当本线程无可运行的G时，尝试从其他线程绑定的P偷取G，而不是销毁线程。

2）hand off机制

​		当本线程因为G进行系统调用阻塞时，线程释放绑定的P，把P转移给其他空闲的线程执行。



**利用并行**：`GOMAXPROCS`设置P的数量，最多有`GOMAXPROCS`个线程分布在多个CPU上同时运行。`GOMAXPROCS`也限制了并发的程度，比如`GOMAXPROCS = 核数/2`，则最多利用了一半的CPU核进行并行。





**抢占**：在coroutine中要等待一个协程主动让出CPU才执行下一个协程，在Go中，一个goroutine最多占用CPU 10ms，防止其他goroutine被饿死，这就是goroutine不同于coroutine的一个地方。



**全局G队列**：在新的调度器中依然有全局G队列，但功能已经被弱化了，当M执行work stealing从其他P偷不到G时，它可以从全局G队列获取G。

##### (3) go func()  调度流程

![18-go-func调度周期.jpeg](https://cdn.learnku.com/uploads/images/202003/11/58489/a4vWtvRWGQ.jpeg!large)

从上图我们可以分析出几个结论：

​	1、我们通过 go func()来创建一个goroutine；

​	2、有两个存储G的队列，一个是局部调度器P的本地队列、一个是全局G队列。新创建的G会先保存在P的本地队列中，如果P的本地队列已经满了就会保存在全局的队列中；

​	3、G只能运行在M中，一个M必须持有一个P，M与P是1：1的关系。M会从P的本地队列弹出一个可执行状态的G来执行，如果P的本地队列为空，就会想其他的MP组合偷取一个可执行的G来执行；

​	4、一个M调度G执行的过程是一个循环机制；

​	5、当M执行某一个G时候如果发生了syscall或则其余阻塞操作，M会阻塞，如果当前有一些G在执行，runtime会把这个线程M从P中摘除(detach)，然后再创建一个新的操作系统的线程(如果有空闲的线程可用就复用空闲线程)来服务于这个P；

​	6、当M系统调用结束时候，这个G会尝试获取一个空闲的P执行，并放入到这个P的本地队列。如果获取不到P，那么这个线程M变成休眠状态， 加入到空闲线程中，然后这个G会被放入全局队列中。



##### (4)调度器的生命周期

![17-pic-go调度器生命周期.png](https://cdn.learnku.com/uploads/images/202003/11/58489/j37FX8nek9.png!large)

特殊的M0和G0

**M0**

`M0`是启动程序后的编号为0的主线程，这个M对应的实例会在全局变量runtime.m0中，不需要在heap上分配，M0负责执行初始化操作和启动第一个G， 在之后M0就和其他的M一样了。

**G0**

`G0`是每次启动一个M都会第一个创建的 goroutine，G0仅用于负责调度的G，G0不指向任何可执行的函数, 每个M都会有一个自己的G0。在调度或系统调用时会使用G0的栈空间, 全局变量的G0是M0的G0。



我们来跟踪一段代码

```go
package main

import "fmt"

func main() {
    fmt.Println("Hello world")
}
```

接下来我们来针对上面的代码对调度器里面的结构做一个分析。



也会经历如上图所示的过程：

1. runtime创建最初的线程m0和goroutine g0，并把2者关联。
2. 调度器初始化：初始化m0、栈、垃圾回收，以及创建和初始化由GOMAXPROCS个P构成的P列表。
3. 示例代码中的main函数是`main.main`，`runtime`中也有1个main函数——`runtime.main`，代码经过编译后，`runtime.main`会调用`main.main`，程序启动时会为`runtime.main`创建goroutine，称它为main goroutine吧，然后把main goroutine加入到P的本地队列。
4. 启动m0，m0已经绑定了P，会从P的本地队列获取G，获取到main goroutine。
5. G拥有栈，M根据G中的栈信息和调度信息设置运行环境
6. M运行G
7. G退出，再次回到M获取可运行的G，这样重复下去，直到`main.main`退出，`runtime.main`执行Defer和Panic处理，或调用`runtime.exit`退出程序。

调度器的生命周期几乎占满了一个Go程序的一生，`runtime.main`的goroutine执行之前都是为调度器做准备工作，`runtime.main`的goroutine运行，才是调度器的真正开始，直到`runtime.main`结束而结束。



##### (5)可视化GMP编程

有2种方式可以查看一个程序的GMP的数据。

**方式1：go tool trace**

trace记录了运行时的信息，能提供可视化的Web页面。

简单测试代码：main函数创建trace，trace会运行在单独的goroutine中，然后main打印"Hello World"退出。

> trace.go

```go
package main

import (
    "os"
    "fmt"
    "runtime/trace"
)

func main() {

    //创建trace文件
    f, err := os.Create("trace.out")
    if err != nil {
        panic(err)
    }

    defer f.Close()

    //启动trace goroutine
    err = trace.Start(f)
    if err != nil {
        panic(err)
    }
    defer trace.Stop()

    //main
    fmt.Println("Hello World")
}

```

运行程序

```bash
$ go run trace.go 
Hello World
```

会得到一个`trace.out`文件，然后我们可以用一个工具打开，来分析这个文件。

```golang
$ go tool trace trace.out 
2020/02/23 10:44:11 Parsing trace...
2020/02/23 10:44:11 Splitting trace...
2020/02/23 10:44:11 Opening browser. Trace viewer is listening on http://127.0.0.1:33479

```

我们可以通过浏览器打开`http://127.0.0.1:33479`网址，点击`view trace` 能够看见可视化的调度流程。

![19-go-trace1.png](https://cdn.learnku.com/uploads/images/202003/11/58489/Xr9qi3emlx.png!large)

![20-go-trace2.png](https://cdn.learnku.com/uploads/images/202003/11/58489/vYyO9YJmam.png!large)

**G信息**

点击Goroutines那一行可视化的数据条，我们会看到一些详细的信息。

![20-go-trace3.png](https://cdn.learnku.com/uploads/images/202003/11/58489/QLm0KK1hhd.png!large)

      一共有两个G在程序中，一个是特殊的G0，是每个M必须有的一个初始化的G，这个我们不必讨论。

其中G1应该就是main goroutine(执行main函数的协程)，在一段时间内处于可运行和运行的状态。



**M信息**

点击Threads那一行可视化的数据条，我们会看到一些详细的信息。

![22-go-trace4.png](https://cdn.learnku.com/uploads/images/202003/11/58489/mYYA4V17yF.png!large)

一共有两个M在程序中，一个是特殊的M0，用于初始化使用，这个我们不必讨论。

**P信息**
![23-go-trace5.png](https://cdn.learnku.com/uploads/images/202003/11/58489/QbWwbth8uN.png!large)

G1中调用了`main.main`，创建了`trace goroutine g18`。G1运行在P1上，G18运行在P0上。

这里有两个P，我们知道，一个P必须绑定一个M才能调度G。

我们在来看看上面的M信息。

![24-go-trace6.png](https://cdn.learnku.com/uploads/images/202003/11/58489/5kS6NfpQAI.png!large)

我们会发现，确实G18在P0上被运行的时候，确实在Threads行多了一个M的数据，点击查看如下：

![25-go-trace7.png](https://cdn.learnku.com/uploads/images/202003/11/58489/EN1OESafVZ.png!large)

多了一个M2应该就是P0为了执行G18而动态创建的M2.

**方式2：Debug trace**



```go
package main

import (
    "fmt"
    "time"
)

func main() {
    for i := 0; i < 5; i++ {
        time.Sleep(time.Second)
        fmt.Println("Hello World")
    }
}
```



编译

```bash
$ go build trace2.go
```



通过Debug方式运行

```bash
$ GODEBUG=schedtrace=1000 ./trace2 
SCHED 0ms: gomaxprocs=2 idleprocs=0 threads=4 spinningthreads=1 idlethreads=1 runqueue=0 [0 0]
Hello World
SCHED 1003ms: gomaxprocs=2 idleprocs=2 threads=4 spinningthreads=0 idlethreads=2 runqueue=0 [0 0]
Hello World
SCHED 2014ms: gomaxprocs=2 idleprocs=2 threads=4 spinningthreads=0 idlethreads=2 runqueue=0 [0 0]
Hello World
SCHED 3015ms: gomaxprocs=2 idleprocs=2 threads=4 spinningthreads=0 idlethreads=2 runqueue=0 [0 0]
Hello World
SCHED 4023ms: gomaxprocs=2 idleprocs=2 threads=4 spinningthreads=0 idlethreads=2 runqueue=0 [0 0]
Hello World

```



- `SCHED`：调试信息输出标志字符串，代表本行是goroutine调度器的输出；
- `0ms`：即从程序启动到输出这行日志的时间；
- `gomaxprocs`: P的数量，本例有2个P, 因为默认的P的属性是和cpu核心数量默认一致，当然也可以通过GOMAXPROCS来设置；
- `idleprocs`: 处于idle状态的P的数量；通过gomaxprocs和idleprocs的差值，我们就可知道执行go代码的P的数量；
- t`hreads: os threads/M`的数量，包含scheduler使用的m数量，加上runtime自用的类似sysmon这样的thread的数量；
- `spinningthreads`: 处于自旋状态的os thread数量；
- `idlethread`: 处于idle状态的os thread的数量；
- `runqueue=0`： Scheduler全局队列中G的数量；
- `[0 0]`: 分别为2个P的local queue中的G的数量。



下一篇，我们来继续详细的分析GMP调度原理的一些场景问题。



#### 三、Go调度器调度场景过程全解析



##### (1)场景1

P拥有G1，M1获取P后开始运行G1，G1使用`go func()`创建了G2，为了局部性G2优先加入到P1的本地队列。
![26-gmp场景1.png](https://cdn.learnku.com/uploads/images/202003/11/58489/Pm8LOYcsWQ.png!large)


---

##### (2)场景2

G1运行完成后(函数：`goexit`)，M上运行的goroutine切换为G0，G0负责调度时协程的切换（函数：`schedule`）。从P的本地队列取G2，从G0切换到G2，并开始运行G2(函数：`execute`)。实现了线程M1的复用。


![27-gmp场景2.png](https://cdn.learnku.com/uploads/images/202003/12/58489/JWDtmKG3rK.png!large)


---

##### (3)场景3

假设每个P的本地队列只能存3个G。G2要创建了6个G，前3个G（G3, G4, G5）已经加入p1的本地队列，p1本地队列满了。


![28-gmp场景3.png](https://cdn.learnku.com/uploads/images/202003/12/58489/UpjRxzIBd3.png!large)


---
##### (4)场景4

G2在创建G7的时候，发现P1的本地队列已满，需要执行**负载均衡**(把P1中本地队列中前一半的G，还有新创建G**转移**到全局队列)

> （实现中并不一定是新的G，如果G是G2之后就执行的，会被保存在本地队列，利用某个老的G替换新G加入全局队列）


![29-gmp场景4.png](https://cdn.learnku.com/uploads/images/202003/11/58489/chqTgsiuWi.png!large)

这些G被转移到全局队列时，会被打乱顺序。所以G3,G4,G7被转移到全局队列。

---

##### (5)场景5

G2创建G8时，P1的本地队列未满，所以G8会被加入到P1的本地队列。


![30-gmp场景5.png](https://cdn.learnku.com/uploads/images/202003/12/58489/nukEY92G6D.png!large)


G8加入到P1点本地队列的原因还是因为P1此时在与M1绑定，而G2此时是M1在执行。所以G2创建的新的G会优先放置到自己的M绑定的P上。

---

##### (6)场景6

规定：**在创建G时，运行的G会尝试唤醒其他空闲的P和M组合去执行**。

![31-gmp场景6.png](https://cdn.learnku.com/uploads/images/202003/11/58489/2FWNXSuHfX.png!large)


假定G2唤醒了M2，M2绑定了P2，并运行G0，但P2本地队列没有G，M2此时为自旋线程**（没有G但为运行状态的线程，不断寻找G）**。

---



##### (7)场景7

M2尝试从全局队列(简称“GQ”)取一批G放到P2的本地队列（函数：`findrunnable()`）。M2从全局队列取的G数量符合下面的公式：

```go
n = min(len(GQ)/GOMAXPROCS + 1, len(GQ/2))
```

至少从全局队列取1个g，但每次不要从全局队列移动太多的g到p本地队列，给其他p留点。这是**从全局队列到P本地队列的负载均衡**。

![32-gmp场景7.001.jpeg](https://cdn.learnku.com/uploads/images/202003/12/58489/0fn8DGqI8N.jpeg!large)

假定我们场景中一共有4个P（GOMAXPROCS设置为4，那么我们允许最多就能用4个P来供M使用）。所以M2只从能从全局队列取1个G（即G3）移动P2本地队列，然后完成从G0到G3的切换，运行G3。

---

##### (8)场景8

假设G2一直在M1上运行，经过2轮后，M2已经把G7、G4从全局队列获取到了P2的本地队列并完成运行，全局队列和P2的本地队列都空了,如场景8图的左半部分。

![33-gmp场景8.png](https://cdn.learnku.com/uploads/images/202003/12/58489/qn1NRMLqnp.png!large)


**全局队列已经没有G，那m就要执行work stealing(偷取)：从其他有G的P哪里偷取一半G过来，放到自己的P本地队列**。P2从P1的本地队列尾部取一半的G，本例中一半则只有1个G8，放到P2的本地队列并执行。

---

##### (9)场景9

G1本地队列G5、G6已经被其他M偷走并运行完成，当前M1和M2分别在运行G2和G8，M3和M4没有goroutine可以运行，M3和M4处于**自旋状态**，它们不断寻找goroutine。

![34-gmp场景9.png](https://cdn.learnku.com/uploads/images/202003/12/58489/1DjlseEGTT.png!large)


为什么要让m3和m4自旋，自旋本质是在运行，线程在运行却没有执行G，就变成了浪费CPU.  为什么不销毁现场，来节约CPU资源。因为创建和销毁CPU也会浪费时间，我们**希望当有新goroutine创建时，立刻能有M运行它**，如果销毁再新建就增加了时延，降低了效率。当然也考虑了过多的自旋线程是浪费CPU，所以系统中最多有`GOMAXPROCS`个自旋的线程(当前例子中的`GOMAXPROCS`=4，所以一共4个P)，多余的没事做线程会让他们休眠。

---

##### (10)场景10

​		假定当前除了M3和M4为自旋线程，还有M5和M6为空闲的线程(没有得到P的绑定，注意我们这里最多就只能够存在4个P，所以P的数量应该永远是M>=P, 大部分都是M在抢占需要运行的P)，G8创建了G9，G8进行了**阻塞的系统调用**，M2和P2立即解绑，P2会执行以下判断：如果P2本地队列有G、全局队列有G或有空闲的M，P2都会立马唤醒1个M和它绑定，否则P2则会加入到空闲P列表，等待M来获取可用的p。本场景中，P2本地队列有G9，可以和其他空闲的线程M5绑定。


![35-gmp场景10.png](https://cdn.learnku.com/uploads/images/202003/12/58489/k3HKE9U21M.png!large)


##### (11)场景11

G8创建了G9，假如G8进行了**非阻塞系统调用**。
![36-gmp场景11.png](https://cdn.learnku.com/uploads/images/202003/12/58489/zBvpl8ENSb.png!large)

​	M2和P2会解绑，但M2会记住P2，然后G8和M2进入**系统调用**状态。当G8和M2退出系统调用时，会尝试获取P2，如果无法获取，则获取空闲的P，如果依然没有，G8会被记为可运行状态，并加入到全局队列,M2因为没有P的绑定而变成休眠状态(长时间休眠等待GC回收销毁)。

---

#### 四、小结

总结，Go调度器很轻量也很简单，足以撑起goroutine的调度工作，并且让Go具有了原生（强大）并发的能力。**Go调度本质是把大量的goroutine分配到少量线程上去执行，并利用多核并行，实现更强大的并发。**


