---
title: "Context2"
date: 2022-05-21T14:52:20+08:00
draft: true
tags: ["面试"]
series: [""]
categories: ["面试"]
---




## context
    Golang 中的context 是Go语言在 golang1.7 发布时新增的标准包

    目的是增强Golang开发中并发控制技术

    简单来讲当一个服务启动时,可能由此服务派生出多个多层级的 goroutine , 但是本质上来讲每个层级的 goroutine 
	都是平行调度使用,不存在goroutine ‘父子’ 关系 , 当其中一个 goroutine 执行的任务被取消了或者处理超时了,
	那么其他被启动起来的Goroutine 都应该迅速退出,另外多个多层的Goroutine 想传递请求域的数据该如何处理?

    如果单个请求的Goroutine 结构比较简单,或者处理起来也不麻烦,但是如果启动的Goroutine 是多个并且结构层次很深
	那么光是保障每个Goroutine 正常退出也不很容易了

**为此Go1.7以来提供了 context 来解决类似的问题 , context 可以跟踪 Goroutine 的调用, 在调用内部维护一个调用树,通过这个调用树可以在传递超时或者退出通知,还能在调用树中传递元数据**

context的中文翻译是`上下文` ,我们可以理解为 `context` 管理了一组呈现树状结构的 `Goroutine` ,让每个`Goroutine` 都拥有相同的上下文,并且可以在这个上下文中传递数据

1. context.go
2.0 结构图
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/20200624183301296.png)


    我们看一 context.go 的源文件了解一下context 的构成 该文件通常位于
```go
$GOROOT/src/context/context.go
```


2. Context interface

`context` 实际上只是定义的4个方法的接口,凡是实现了该接口的都称为一种 `context`
```go
// A Context carries a deadline, a cancelation signal, and other values across
// API boundaries.
//
// Context's methods may be called by multiple goroutines simultaneously.
type Context interface {
    // 标识deadline是否已经设置了,没有设置时,ok的值是false,并返回初始的time.Time
	Deadline() (deadline time.Time, ok bool)
    // 返回一个channel, 当返回关闭的channel时可以执行一些操作
	Done() <-chan struct{}
    // 描述context关闭的原因,通常在Done()收到关闭通知之后才能知道原因
	Err() error
    // 获取上游Goroutine 传递给下游Goroutine的某些数据
	Value(key interface{}) interface{}
}
```
3.  emptyCtx
```go
// An emptyCtx is never canceled, has no values, and has no deadline. It is not
// struct{}, since vars of this type must have distinct addresses.
type emptyCtx int

func (*emptyCtx) Deadline() (deadline time.Time, ok bool) {
	return
}

func (*emptyCtx) Done() <-chan struct{} {
	return nil
}

func (*emptyCtx) Err() error {
	return nil
}

func (*emptyCtx) Value(key interface{}) interface{} {
	return nil
}

func (e *emptyCtx) String() string {
	switch e {
	case background:
		return "context.Background"
	case todo:
		return "context.TODO"
	}
	return "unknown empty Context"
}

var (
	background = new(emptyCtx)
	todo       = new(emptyCtx)
)

// Background returns a non-nil, empty Context. It is never canceled, has no
// values, and has no deadline. It is typically used by the main function,
// initialization, and tests, and as the top-level Context for incoming
// requests.
func Background() Context {
	return background
}

// TODO returns a non-nil, empty Context. Code should use context.TODO when
// it's unclear which Context to use or it is not yet available (because the
// surrounding function has not yet been extended to accept a Context
// parameter).
func TODO() Context {
	return todo
}
```
    我们看到 emptyCtx 实现了Context 接口,但是其实现的方法都是空nil 那么我们就可以知道其实emptyCtx 是不具备任何
	实际功能的,那么它存在的目的是什么呢?

    emptyCtx 存在的意义是作为 Context 对象树根节点 root节点 , 在context.go 包中提供 Background() 和 TODO() 
	两个函数 ,这两个函数都是返回的都是 emptyCtx 实例 ,通常我们使用他们来构建Context的根节点 , 有了root根节点之后
	就可同事 context.go 包中提供的其他的包装函数创建具有意义的context 实例 ,并且没有context 实例的创建都是以上一
	个 context 实例对象作为参数的(所以必须有一个根节点) ,最终形成一个树状的管理结构

3.  cancelCtx

    定义了cancelCtx 类型的结构体

    其中字段children 记录派生的child,当该类型的context(上下文) 被执行cancel是会将所有派生的child都执行cancel

    对外暴露了 Err() Done() String() 方法
```go
// A cancelCtx can be canceled. When canceled, it also cancels any children
// that implement canceler.
type cancelCtx struct {
	Context

	mu       sync.Mutex            // protects following fields
	done     chan struct{}         // created lazily, closed by first cancel call
	children map[canceler]struct{} // set to nil by the first cancel call
	err      error                 // set to non-nil by the first cancel call
}

func (c *cancelCtx) Done() <-chan struct{} {
	c.mu.Lock()
	if c.done == nil {
		c.done = make(chan struct{})
	}
	d := c.done
	c.mu.Unlock()
	return d
}

func (c *cancelCtx) Err() error {
	c.mu.Lock()
	err := c.err
	c.mu.Unlock()
	return err
}

func (c *cancelCtx) String() string {
	return fmt.Sprintf("%v.WithCancel", c.Context)
}

// cancel closes c.done, cancels each of c's children, and, if
// removeFromParent is true, removes c from its parent's children.
func (c *cancelCtx) cancel(removeFromParent bool, err error) {
	if err == nil {
		panic("context: internal error: missing cancel error")
	}
	c.mu.Lock()
	if c.err != nil {
		c.mu.Unlock()
		return // already canceled
	}
	c.err = err
	if c.done == nil {
		c.done = closedchan
	} else {
		close(c.done)
	}
	for child := range c.children {
		// NOTE: acquiring the child's lock while holding parent's lock.
		child.cancel(false, err)
	}
	c.children = nil
	c.mu.Unlock()

	if removeFromParent {
		removeChild(c.Context, c)
	}
}
```
4. valueCtx

    通过 valueCtx 结构知道仅是在Context 的基础上增加了元素 key 和 value

    通常用于在层级协程之间传递数据
```go
// A valueCtx carries a key-value pair. It implements Value for that key and
// delegates all other calls to the embedded Context.
type valueCtx struct {
	Context
	key, val interface{}
}

func (c *valueCtx) String() string {
	return fmt.Sprintf("%v.WithValue(%#v, %#v)", c.Context, c.key, c.val)
}

func (c *valueCtx) Value(key interface{}) interface{} {
	if c.key == key {
		return c.val
	}
	return c.Context.Value(key)
}
```
5. timerCtx
    在cancelCtx 基础上增加了字段 timer 和 deadline

    timer 触发自动cancel的定时器

    deadline 标识最后执行cancel的时间
```go
type timerCtx struct {
	cancelCtx
	timer *time.Timer // Under cancelCtx.mu.

	deadline time.Time
}

func (c *timerCtx) Deadline() (deadline time.Time, ok bool) {
	return c.deadline, true
}

func (c *timerCtx) String() string {
	return fmt.Sprintf("%v.WithDeadline(%s [%s])", c.cancelCtx.Context, c.deadline, time.Until(c.deadline))
}

func (c *timerCtx) cancel(removeFromParent bool, err error) {
	c.cancelCtx.cancel(false, err)
	if removeFromParent {
		// Remove this timerCtx from its parent cancelCtx's children.
		removeChild(c.cancelCtx.Context, c)
	}
	c.mu.Lock()
	if c.timer != nil {
		c.timer.Stop()
		c.timer = nil
	}
	c.mu.Unlock()
}
```
## 使用示例
    context.go 包中提供了4个以 With 开头的函数, 这几个函数的主要功能是实例化不同类型的context

    通过 Background() 和 TODO() 创建最 emptyCtx 实例 ,通常是作为根节点

    通过 WithCancel() 创建 cancelCtx 实例

    通过 WithValue() 创建 valueCtx 实例

    通过 WithDeadline 和 WithTimeout 创建 timerCtx 实例

1.  WithCancel

源码如下
```go
// newCancelCtx returns an initialized cancelCtx.
func newCancelCtx(parent Context) cancelCtx {
	return cancelCtx{Context: parent}
}
func WithCancel(parent Context) (ctx Context, cancel CancelFunc) {
    // 创建cancelCtx实例
    c := newCancelCtx(parent)
    // 添加到父节点的children中
	propagateCancel(parent, &c)
    // 返回实例和方法
	return &c, func() { c.cancel(true, Canceled) }
}
```
```go
**使用示例 : **

package main

import (
	"context"
	"fmt"
	"time"
)

func MyOperate1(ctx context.Context) {
	for {
		select {
		default:
			fmt.Println("MyOperate1", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		case <-ctx.Done():
			fmt.Println("MyOperate1 Done")
			return
		}
	}
}
func MyOperate2(ctx context.Context) {
	fmt.Println("Myoperate2")
}
func MyDo2(ctx context.Context) {
	go MyOperate1(ctx)
	go MyOperate2(ctx)
	for {
		select {
		default:
			fmt.Println("MyDo2 : ", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		case <-ctx.Done():
			fmt.Println("MyDo2 Done")
			return
		}
	}

}
func MyDo1(ctx context.Context) {
	go MyDo2(ctx)
	for {
		select {
		case <-ctx.Done():
			fmt.Println("MyDo1 Done")
			// 打印 ctx 关闭原因
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("MyDo1 : ", time.Now().Format("2006-01-02 15:04:05"))
			time.Sleep(2 * time.Second)
		}
	}
}
func main() {
	// 创建 cancelCtx 实例
	// 传入context.Background() 作为根节点
	ctx, cancel := context.WithCancel(context.Background())
	// 向协程中传递ctx
	go MyDo1(ctx)
	time.Sleep(5 * time.Second)
	fmt.Println("stop all goroutines")
	// 执行cancel操作
	cancel()
	time.Sleep(2 * time.Second)
}

```
2. WithDeadline
    设置了deadline的context

    这个deadline(最终期限) 表示context在指定的时刻结束

源码如下
```go
func WithDeadline(parent Context, d time.Time) (Context, CancelFunc) {
	if cur, ok := parent.Deadline(); ok && cur.Before(d) {
		// The current deadline is already sooner than the new one.
		return WithCancel(parent)
	}
	c := &timerCtx{
		cancelCtx: newCancelCtx(parent),
		deadline:  d,
	}
	propagateCancel(parent, c)
	dur := time.Until(d)
	if dur <= 0 {
		c.cancel(true, DeadlineExceeded) // deadline has already passed
		return c, func() { c.cancel(false, Canceled) }
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.err == nil {
		c.timer = time.AfterFunc(dur, func() {
			c.cancel(true, DeadlineExceeded)
		})
	}
	return c, func() { c.cancel(true, Canceled) }
}
```
```go
使用示例

package main

import (
	"context"
	"fmt"
	"time"
)

func dl2(ctx context.Context) {
	n := 1
	for {
		select {
		case <-ctx.Done():
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("dl2 : ", n)
			n++
			time.Sleep(time.Second)
		}
	}
}

func dl1(ctx context.Context) {
	n := 1
	for {
		select {
		case <-ctx.Done():
			fmt.Println(ctx.Err())
			return
		default:
			fmt.Println("dl1 : ", n)
			n++
			time.Sleep(2 * time.Second)
		}
	}
}
func main() {
	// 设置deadline为当前时间之后的5秒那个时刻
	d := time.Now().Add(5 * time.Second)
	ctx, cancel := context.WithDeadline(context.Background(), d)
	defer cancel()
	go dl1(ctx)
	go dl2(ctx)
	for{
		select {
			case <-ctx.Done():
				fmt.Println("over",ctx.Err())
				return
		}
	}
}
```
3. WithTimeout
    实际就是调用了WithDeadline()

源码如下
```go
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc) {
	return WithDeadline(parent, time.Now().Add(timeout))
}
```
```go
使用示例 :

package main

import (
   "context"
   "fmt"
   "time"
)

func to1(ctx context.Context) {
   n := 1
   for {
   	select {
   	case <-ctx.Done():
   		fmt.Println("to1 is over")
   		return
   	default:
   		fmt.Println("to1 : ", n)
   		n++
   		time.Sleep(time.Second)
   	}
   }
}
func main() {
   // 设置为6秒后context结束
   ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
   defer cancel()
   go to1(ctx)
   n := 1
   for {
   	select {
   	case <-time.Tick(2 * time.Second):
   		if n == 9 {
   			return
   		}
   		fmt.Println("number :", n)
   		n++
   	}
   }
}
```
4. WithValue
    仅是在Context 基础上添加了 key : value 的键值对

    context 形成的树状结构,后面的节点可以访问前面节点传导的数据

源码如下 :
```go
func WithValue(parent Context, key, val interface{}) Context {
   if key == nil {
   	panic("nil key")
   }
   if !reflect.TypeOf(key).Comparable() {
   	panic("key is not comparable")
   }
   return &valueCtx{parent, key, val}
}

// A valueCtx carries a key-value pair. It implements Value for that key and
// delegates all other calls to the embedded Context.
type valueCtx struct {
   Context
   key, val interface{}
}
```
```go
使用示例 :

package main

import (
   "context"
   "fmt"
   "time"
)

func v3(ctx context.Context) {
   for {
   	select {
   	case <-ctx.Done():
   		fmt.Println("v3 Done : ", ctx.Err())
   		return
   	default:
   		fmt.Println(ctx.Value("key"))
   		time.Sleep(3 * time.Second)
   	}
   }
}
func v2(ctx context.Context) {
   fmt.Println(ctx.Value("key"))
   fmt.Println(ctx.Value("v1"))
   // 相同键,值覆盖
   ctx = context.WithValue(ctx, "key", "modify from v2")
   go v3(ctx)
}
func v1(ctx context.Context) {
   if v := ctx.Value("key"); v != nil {
   	fmt.Println("key = ", v)
   }
   ctx = context.WithValue(ctx, "v1", "value of v1 func")
   go v2(ctx)
   for {
   	select {
   	default:
   		fmt.Println("print v1")
   		time.Sleep(time.Second * 2)
   	case <-ctx.Done():
   		fmt.Println("v1 Done : ", ctx.Err())
   		return
   	}
   }
}
func main() {
   ctx, cancel := context.WithCancel(context.Background())
   // 向context中传递值
   ctx = context.WithValue(ctx, "key", "main")
   go v1(ctx)
   time.Sleep(10 * time.Second)
   cancel()
   time.Sleep(3 * time.Second)
}
```