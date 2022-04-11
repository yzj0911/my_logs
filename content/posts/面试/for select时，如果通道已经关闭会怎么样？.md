---
title: "面试题"
date: 2022-04-11T22:52:11+08:00
draft: true
tags: ["面试"]
series: [""]
categories: ["面试"]
---

## 1.for select时，如果通道已经关闭会怎么样？如果select中只有一个case呢？

答：
- for循环select时，如果其中一个case通道已经关闭，则每次都会执行到这个case。
- 如果select里边只有一个case，而这个case被关闭了，则会出现死循环。

```go 
package _for

import (
	"fmt"
	"testing"
	"time"
)

//问题：for select时，如果通道已经关闭会怎么样？如果select中只有一个case呢？
//结果：当未有值时，由于缓存为0，<-ch 没数据，则一直走default，当有值输入后，但是在通道关闭后，这个通道一直能读出内容。
func TestForCase(t *testing.T) {
	ch := make(chan int)

	go func() {
		time.Sleep(time.Second * 1)
		ch <- 1
		close(ch)
	}()
	for {
		select {
		case a, ok := <-ch:
			fmt.Printf("fmt:%d time:%v  %v \t\n", a, time.Now(), ok)
			time.Sleep(500 * time.Millisecond)
		default:
			fmt.Println("咩有读出来")
			time.Sleep(500 * time.Millisecond)
		}

	}

}

结果:
=== RUN   TestForCase
咩有读出来
咩有读出来
fmt:1 time:2022-04-11 23:01:15.691889 +0800 CST m=+1.005903641  true 	
fmt:0 time:2022-04-11 23:01:16.193244 +0800 CST m=+1.507252014  false 	
fmt:0 time:2022-04-11 23:01:16.694997 +0800 CST m=+2.008997910  false 	

```

## 2.怎么样才能不读关闭后通道

```go 
func TestForCase2(t *testing.T) {
	ch := make(chan int)

	go func() {
		time.Sleep(time.Second * 1)
		ch <- 1
		close(ch)
	}()
	for {
		select {
		case a, ok := <-ch:
			fmt.Printf("fmt:%d time:%v  %v \t\n", a, time.Now(), ok)
			time.Sleep(500 * time.Millisecond)
			if !ok {
				ch = nil //把关闭后的通道复值为nil，则select读取则会阻塞
			}
		default:
			fmt.Println("咩有读出来")
			time.Sleep(500 * time.Millisecond)
		}
	}
}

=== RUN   TestForCase2
咩有读出来
咩有读出来
咩有读出来
fmt:1 time:2022-04-11 23:16:03.751807 +0800 CST m=+1.506454927  true 	
fmt:0 time:2022-04-11 23:16:04.253248 +0800 CST m=+2.007888277  false 	
咩有读出来
咩有读出来
咩有读出来

```

## 3.如果select里只有一个已经关闭的case，会怎么样？
```go 
func TestForCase2(t *testing.T) {
	ch := make(chan int)

	go func() {
		time.Sleep(time.Second * 1)
		ch <- 1
		close(ch)
	}()
	for {
		select {
		case a, ok := <-ch:
			fmt.Printf("fmt:%d time:%v  %v \t\n", a, time.Now(), ok)
			time.Sleep(500 * time.Millisecond)
			if !ok {
				ch = nil //把关闭后的通道复值为nil，则select读取则会阻塞
			}
		//default:
		//	fmt.Println("咩有读出来")
		//	time.Sleep(500 * time.Millisecond)
		}

	}

}
=== RUN   TestForCase2
fmt:1 time:2022-04-11 23:19:03.189441 +0800 CST m=+1.003139137  true 	
fmt:0 time:2022-04-11 23:19:03.693051 +0800 CST m=+1.506741808  false 	
fatal error: all goroutines are asleep - deadlock!

goroutine 1 [chan receive]:
testing.(*T).Run(0xc000001500, 0x11a0fe9, 0xc, 0x11a94f0, 0x62544600)
	/usr/local/Cellar/go/1.15.5/libexec/src/testing/testing.go:1169 +0x676


```

# 总结
- select中如果任意某个通道有值可读时，它就会被执行，其他被忽略。
- 如果没有default字句，select将有可能阻塞，直到某个通道有值可以运行，所以select里最好有一个default，否则将有一直阻塞的风险。




