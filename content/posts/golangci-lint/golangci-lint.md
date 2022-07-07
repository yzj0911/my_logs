---
title: "Golangci Lint"
date: 2022-07-07T10:50:57+08:00
draft: true
tags: ["golangci-lint"] 
series: [""] 
categories: ["golangci-lint"]
---

# golangci-lint
[golangci-lint 配置中心](\https://golangci-lint.run/usage/linters/)

Golang 常用的 checkstyle 有 golangci-lint 和 golint, 
今天我们主要介绍 golangci-lint, golangci-lint 用于许多开源项目中, 
比如 kubernetes、Prometheus、TiDB 等都使用 golangci-lint 用于代码检查, 
TIDB 的 makefile 中的 check-static 使用 golangci-lint 进行代码检查, 
可参考: https://github.com/pingcap/tidb/blob/master/Makefile

源码地址: https://github.com/golangci/golangci-lint

安装及使用 : https://golangci-lint.run/

## golangci-lint 使用

1. 检查当前目录下所有的文件

`golangci-lint run ` 等同于 `golangci-lint run ./...`
2. 可以指定某个目录和文件

`golangci-lint run dir1 dir2/... dir3/file1.go`

检查 dir1 和 dir2 目录下的代码及 dir3 目录下的 file1.go 文件
3. 可以通过 `--enable/-E` 开启指定 Linter, 也可以通 `--disable/-D` 关闭指定 Linter

## 禁用 lint 检查
有的时候会需要禁用 lint 检查, 可以在需要禁用检测的函数或者语句附近这样使用:

```//nolint:lll,funlen```
1. 在配置里面禁用
```go
[[issues.exclude-rules]]
path = "(.+)_test.go"
linters = ["typecheck"]
text = "imported but not used"
```

2. Linter
Linters 是代码检查的项, 默认开启的 Linters 如下:

还有许多默认没有开启的 Linter, 可以通过 —enable 开启默认未开启的 Linter。

3. 常用的 Linter 介绍
- deadcode 未使用且未导出的函数 (比如: 首字母小写且未被调用的方法)
- errcheck 返回的 error 未处理
- structcheck 检测结构体中未使用的字段
- unused 方法中方法名首字母小写 (未导出) 并且未使用的方法
- gosimple 代码中有需要优化的地方

比如:

1. `err = errors.New(fmt.Sprintf("%s", val))` 代码检查会直接推荐你使用 `fmt.Errorf(...)`
2. `strChan := make(chan string,0) `代码检查会提示你直接使用 `make(chan string)`
3. select 中只有一个 case 代码检查会提示你去掉 select
- ineffassign: 检测变量的赋值

示例:

```var index byte = 0```

以上代码会提示 ineffectual assignment to index(无效的分配, 因为 index 的默认值为 0)
- govet: 用于检测代码结构中可以的构造
示例:
1. `fmt.Errorf("%s", val)` 有声明但没有使用
2. `loopclosure: loop variable xxx captured by func literal (govet) `某个方法中重复定义了相同的局部变量

## golang lint 错误解决

1. type assertion must be checked
finds type assertions which did forcely such as below.
```go
func f() {
    var a interface{}
    _ = a.(int) // type assertion must be checked
}
```

You need to check if the assertion failed like so:
```go
func f() {
var a interface{}
    _, ok := a.(int)
    if !ok { // type assertion failed
    // handle error
    }
}
```
