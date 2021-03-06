# 内存逃逸


# 内存逃逸

### 暂时性内存泄漏

- 获取长字符串中的一段导致长字符串未被释放
- 获取长slice中的一段导致长slice未被释放
- 在长slice中新建slice导致泄漏

### 永久性内存泄漏

- goroutine泄漏
- time.Ticker 未关闭导致泄漏
- Finalizer导致泄漏
- Deferring Function Call导致泄漏



-------
## 常见的内存逃逸
1. 指针逃逸
2. 栈空间不足
3. 变量大小不确定
4. 动态类型
5. 闭包引用对象


## 小总结
1. 栈上分配内存比在堆中分配内存效率更高

2. 栈上分配的内存不需要 GC 处理，而堆需要

3. 逃逸分析目的是决定内分配地址是栈还是堆

4. 逃逸分析在编译阶段完成

-------


## 堆与栈

![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/堆栈.png)



## 常见的逃逸现象
```go
package main

import "fmt" 

func main() {    
   name := test()    
   fmt.Println(name())
}

func test() func() string {    
   return func() string { //name 从原来的栈上，逃逸到堆上
          return "公众号-后端时光"     
   }
}

// go build -gcflags="-m -l" eee.go 
// -m：表示内存分析  -l：表示防止内联优化
```

原因是 ```go/src/fmt/print.go``` 文件中 ```Println``` 方法传参数类型 ```interface{}```, 编译器对传入的变量类型未知，所有统一处理分配到了堆上面去了。









# pprof排查

什么是pprof?

pprof是Go的性能分析工具,在程序运行中可以记录程序的运行信息,可以是CPU使用情况、内存使用情况、goroutine运行状况等,当需要性能调优或定位bug时候,这些记录的信息是相当重要。

```go
package main

import (
    "fmt"
    "net/http"
    _ "net/http/pprof"
)

func main() {
    ip := "127.0.0.1:6069"
    if err := http.ListenAndServe(ip, nil); err != nil {
        fmt.Printf("start pprof failed on %s\n", ip)
    }
}
```
