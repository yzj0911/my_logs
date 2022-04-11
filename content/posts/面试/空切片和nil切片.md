---
title: "空切片和nil切片"
date: 2022-04-11T23:24:19+08:00
draft: true
tags: ["面试"]
series: [""]
categories: ["面试"]
---


# 空切片和nil切片

问题：
```go 
package main

import (
	"fmt"
	"reflect"
	"unsafe"
)

func main() {

	var s1 []int   // nil切片
	s2 := make([]int,0)  // 空切片
	s4 := make([]int,0)   // 空切片
	
	fmt.Printf("s1 pointer:%+v, s2 pointer:%+v, s4 pointer:%+v, \n", *(*reflect.SliceHeader)(unsafe.Pointer(&s1)),*(*reflect.SliceHeader)(unsafe.Pointer(&s2)),*(*reflect.SliceHeader)(unsafe.Pointer(&s4)))
	fmt.Printf("%v\n", (*(*reflect.SliceHeader)(unsafe.Pointer(&s1))).Data==(*(*reflect.SliceHeader)(unsafe.Pointer(&s2))).Data)
	fmt.Printf("%v\n", (*(*reflect.SliceHeader)(unsafe.Pointer(&s2))).Data==(*(*reflect.SliceHeader)(unsafe.Pointer(&s4))).Data)
}

```
nil切片和空切片指向的地址一样吗？这个代码会输出什么？

答：
- nil切片和空切片指向的地址不一样。nil空切片引用数组指针地址为0（无指向任何实际地址）
- 空切片的引用数组指针地址是有的，且固定为一个值

```go 
s1 pointer:{Data:0 Len:0 Cap:0}, s2 pointer:{Data:824634207952 Len:0 Cap:0}, s4 pointer:{Data:824634207952 Len:0 Cap:0}, 
false //nil切片和空切片指向的数组地址不一样
true  //两个空切片指向的数组地址是一样的，都是824634207952

```

# 解释

- 切片的数据结构：
```go 
type SliceHeader struct {
 Data uintptr  //引用数组指针地址
 Len  int     // 切片的目前使用长度
 Cap  int     // 切片的容量
}
```
- nil切片和空切片最大的区别在于指向的数组引用地址是不一样的。
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/空切片.jpeg)
- 所有的空切片指向的数组引用地址都是一样的
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/空切片2.png)