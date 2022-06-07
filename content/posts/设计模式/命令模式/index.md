---
title: "命令模式"
date: 2022-06-07T10:27:01+08:00
draft: true
tags: ["设计模式"]
series: [""]
categories: ["设计模式"]
---


![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/命令模式.jpeg)

# 命令模式
接下来会有两个例子，第一个是按照原文定义的方式，将函数封装成对象，第二个例子我们直接将函数作为参数传递。

## 将函数封装为对象
### Code
```go 
// Package command 命令模式
// Blog: https://lailin.xyz/post/command.html
// 这是示例一，采用将函数封装为对象的方式实现，
// 示例说明:
// 假设现在有一个游戏服务，我们正在实现一个游戏后端
// 使用一个 goroutine 不断接收来自客户端请求的命令，并且将它放置到一个队列当中
// 然后我们在另外一个 goroutine 中来执行它
package command

import "fmt"

// ICommand 命令
type ICommand interface {
	Execute() error
}

// StartCommand 游戏开始运行
type StartCommand struct{}

// NewStartCommand NewStartCommand
func NewStartCommand( /*正常情况下这里会有一些参数*/ ) *StartCommand {
	return &StartCommand{}
}

// Execute Execute
func (c *StartCommand) Execute() error {
	fmt.Println("game start")
	return nil
}

// ArchiveCommand 游戏存档
type ArchiveCommand struct{}

// NewArchiveCommand NewArchiveCommand
func NewArchiveCommand( /*正常情况下这里会有一些参数*/ ) *ArchiveCommand {
	return &ArchiveCommand{}
}

// Execute Execute
func (c *ArchiveCommand) Execute() error {
	fmt.Println("game archive")
	return nil
}
```

### Test
```go 
package command

import (
	"fmt"
	"testing"
	"time"
)

func TestDemo(t *testing.T) {
	// 用于测试，模拟来自客户端的事件
	eventChan := make(chan string)
	go func() {
		events := []string{"start", "archive", "start", "archive", "start", "start"}
		for _, e := range events {
			eventChan <- e
		}
	}()
	defer close(eventChan)

	// 使用命令队列缓存命令
	commands := make(chan ICommand, 1000)
	defer close(commands)

	go func() {
		for {
			// 从请求或者其他地方获取相关事件参数
			event, ok := <-eventChan
			if !ok {
				return
			}

			var command ICommand
			switch event {
			case "start":
				command = NewStartCommand()
			case "archive":
				command = NewArchiveCommand()
			}

			// 将命令入队
			commands <- command
		}
	}()

	for {
		select {
		case c := <-commands:
			c.Execute()
		case <-time.After(1 * time.Second):
			fmt.Println("timeout 1s")
			return
		}
	}
}
```
## 将函数直接作为参数
### Code
```go

// Package command 命令模式
// Blog: https://lailin.xyz/post/command.html
// 这是示例二，采用将直接返回一个函数，不用对象
// 示例说明:
// 假设现在有一个游戏服务，我们正在实现一个游戏后端
// 使用一个 goroutine 不断接收来自客户端请求的命令，并且将它放置到一个队列当中
// 然后我们在另外一个 goroutine 中来执行它
package command

import "fmt"

// Command 命令
type Command func() error

// StartCommandFunc 返回一个 Command 命令
// 是因为正常情况下不会是这么简单的函数
// 一般都会有一些参数
func StartCommandFunc() Command {
	return func() error {
		fmt.Println("game start")
		return nil
	}
}

// ArchiveCommandFunc ArchiveCommandFunc
func ArchiveCommandFunc() Command {
	return func() error {
		fmt.Println("game archive")
		return nil
	}
}
```
### Test
```go
package command

import (
	"fmt"
	"testing"
	"time"
)

func TestDemoFunc(t *testing.T) {
	// 用于测试，模拟来自客户端的事件
	eventChan := make(chan string)
	go func() {
		events := []string{"start", "archive", "start", "archive", "start", "start"}
		for _, e := range events {
			eventChan <- e
		}

	}()
	defer close(eventChan)

	// 使用命令队列缓存命令
	commands := make(chan Command, 1000)
	defer close(commands)

	go func() {
		for {
			// 从请求或者其他地方获取相关事件参数
			event, ok := <-eventChan
			if !ok {
				return
			}

			var command Command
			switch event {
			case "start":
				command = StartCommandFunc()
			case "archive":
				command = ArchiveCommandFunc()
			}

			// 将命令入队
			commands <- command
		}
	}()

	for {
		select {
		case c := <-commands:
			c()
		case <-time.After(1 * time.Second):
			fmt.Println("timeout 1s")
			return
		}
	}
}
```


