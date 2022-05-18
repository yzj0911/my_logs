---
title: "Interface"
date: 2022-04-13T21:03:11+08:00
draft: true
tags: ["面试"]
series: [""]
categories: ["面试"]
---

## interface的底层实现
所有interface，包括有方法和空接口，在内存中都是占据两个字长，在32位机器上就是8个字节，在64位机器上就是16个字节。
```go
runtime.eface：
type eface struct{
    _type *_type	// 数据的真实类型
    data unsafe.Pointer
}
```
空接口由两个指针组成，_type表示接口的类型相关的信息，data表示数据的指针。
```go
type _type struct {
    size       uintptr	// 内存大小
    ptrdata    uintptr 	// 内存前缀大小
    hash       uint32	// 类型的hash值
    tflag      tflag	// 类型信息标志，和反射相关
    align      uint8	// 内存对齐大小
    fieldalign uint8	// 结构体字段内存对齐大小
    kind       uint8	// 类别
    equal func(unsafe.Pointer, unsafe.Pointer) bool
    // gcdata stores the GC type data for the garbage collector.
    // If the KindGCProg bit is set in kind, gcdata is a GC program.
    // Otherwise it is a ptrmask bitmap. See mbitmap.go for details.
    gcdata    *byte		// gc相关
    str       nameOff
    ptrToThis typeOff
}
```
```go
runtime.iface
type iface struct {
    tab  *itab
    data unsafe.Pointer
}
```
有方法的接口也由两个指针组成，tab存放接口的类型以及方法表，data表示数据的指针
```go
type itab struct {
    inter  *interfacetype	// 接口类型（比如Bird）
    _type  *_type			// 数据真实类型，动态类型（比如Sparrow）
    hash   uint32 // copy of _type.hash. Used for type switches.
	_      [4]byte
	fun    [1]uintptr // variable sized. fun[0]==0 means _type does not implement inter.
}

type nameOff int32
type typeOff int32

type imethod struct {
	name nameOff
	ityp typeOff
}

type interfacetype struct {
    typ     _type	// 具体的类型
    pkgpath name	// 接口的包名
    mhdr    []imethod  //接口定义的函数列表
}
```
itab中 inter 表示接口类型，包含类型、包名、方法等信息，_type 表示数据的真实类型。
fun字段为与接口方法对应的具体数据类型的方法地址，fun的数组大小为1，存放的是第一个方法的地址，如果有多个方法，因为内存是连续的，可以通过增加指针获取后面的方法地址。
reflect.Typeof() 返回的是数据的真实类型。

## interface的类型转换
```go
func main() {
	var x int64 = 1
	var a interface{} = x
	fmt.Println(a)
}
```
这段代码将int64的x赋值给a，将发生类型转换。打印其汇编代码：

```go 
go tool compile -S mian.go > mian.s
```

观察汇编可以发现，在执行 var a interface{} = x的时候，发现其调用了runtime.convT64(SB)方法。

实际上根据所赋与值的类型的不同，会调用不同的转换方法，类似的还有 convTstring，convT32等。

## 类型断言
```go
var any interface{} = 1
i,ok := any.(int)

var any interface{}
switch any.(type){
case int:
	fmt.Println("type int")
case string:
	fmt.Println("type string)
default:
	fmt.Println("type unknow)
}
```
类型断言interface的类型就是它的数据真实类型。例如：
```go
type a int64

func main(){
    var i interface{} = a(1) // i的真实数据类型为 main.a而不是int64
    fmt.Println(i.(a))
}
```

类型断言参考：runtime.assertxx 方法的实现。

## 指针接收者还是值接收者？
先看指针接收者和值接收者的区别：

当Fly的接收者为值类型时：
```go
type Bird interface {
	Fly()
}

type Sparrow struct {
}

func (Sparrow) Fly() {
	fmt.Println("sparrow fly")
}

func main() {
	var s1 Bird = Sparrow{}
	s1.Fly()
	var s2 Bird = &Sparrow{}
	s2.Fly()
}
```
打印结果为：
```go
sparrow fly
sparrow fly
```
```go
当Fly的接收者为指针类型时：
func (*Sparrow) Fly() {
	fmt.Println("sparrow fly")
}

func main() {
	var s1 Bird = Sparrow{}
	s1.Fly()
	var s2 Bird = &Sparrow{}
	s2.Fly()
}
```
打印结果为：
```go
cannot use Sparrow literal (type Sparrow) as type Bird in assignment:
Sparrow does not implement Bird (Fly method has pointer receiver)
```
可以看出，当方法的接收者为值类型时，不管是指针类型的值还是值类型的值都可以调用该方法，因为go会把指针进行隐式的转换得到指针的值，而当方法的接收者为指针类型时，值类型的值调用该方法会报错。

*类型 T 变量只有接受者是 T 的方法；而类型 *T变量拥有接受者是 T 和 T 的方法

选择指针接收者主要考虑以下因素：

- 期望修改结构体的值
- 当结构体比较大的时候，避免每次都进行值拷贝
- 避免类型可能不为空的interface和nil直接进行比较，因为interface底层是由类型和值组成，当两者都为nil时，他的值才等于nil。
- var _ intertype= (*mytype)(nil)，定义一个类型实现了某个接口时，go编译器可以检测mytype是否实现了intertype接口。

## 接口的比较
两个接口可以通过比较运算符 == ，**!=**来进行比较。如果是两个空接口，那么这两个总是相等的。所以 == 操作符返回 true。
```go
var a, b interface{}
fmt.Println(a==b)	// true
fmt.Println(a!=b)	// false
```
如果两个不是空接口，那么只有当他们的动态类型和动态值都相等的情况下，他们才相等（==操作符返回true）。

上面的情况都是基于动态类型都能比较的情况下进行的，如果动态类型不能比较呢（比如：slice，map，array， function和结构体等），那么，执行比较操作的时候会抛出运行时异常。
