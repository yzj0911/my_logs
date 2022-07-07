# 单例模式


![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/单例模式.jpeg)

# 单例模式


代码实现
单例模式采用了 饿汉式 和 懒汉式 两种实现，个人其实更倾向于饿汉式的实现，简单，并且可以将问题及早暴露，懒汉式虽然支持延迟加载，但是这只是把冷启动时间放到了第一次使用的时候，并没有本质上解决问题，并且为了实现懒汉式还不可避免的需要加锁。

## 饿汉式
代码实现:

```go
package singleton

// Singleton 饿汉式单例
type Singleton struct{}

var singleton *Singleton

func init() {
	singleton = &Singleton{}
}

// GetInstance 获取实例
func GetInstance() *Singleton {
	return singleton
}
```
单元测试:

```go
package singleton_test

import (
	"testing"

	singleton "github.com/mohuishou/go-design-pattern/01_singleton"

	"github.com/stretchr/testify/assert"
)

func TestGetInstance(t *testing.T) {
	assert.Equal(t, singleton.GetInstance(), singleton.GetInstance())
}

func BenchmarkGetInstanceParallel(b *testing.B) {
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			if singleton.GetInstance() != singleton.GetInstance() {
				b.Errorf("test fail")
			}
		}
	})
}
```
## 懒汉式（双重检测）
代码实现:
```go
package singleton

import "sync"

var (
	lazySingleton *Singleton
	once          = &sync.Once{}
)

// GetLazyInstance 懒汉式
func GetLazyInstance() *Singleton {
	if lazySingleton == nil {
		once.Do(func() {
			lazySingleton = &Singleton{}
		})
	}
	return lazySingleton
}
```
单元测试:

```go
package singleton_test

import (
	"testing"

	singleton "github.com/mohuishou/go-design-pattern/01_singleton"

	"github.com/stretchr/testify/assert"
)

func TestGetLazyInstance(t *testing.T) {
	assert.Equal(t, singleton.GetLazyInstance(), singleton.GetLazyInstance())
}

func BenchmarkGetLazyInstanceParallel(b *testing.B) {
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			if singleton.GetLazyInstance() != singleton.GetLazyInstance() {
				b.Errorf("test fail")
			}
		}
	})
}
```
测试结果
感谢 @lixianyang 的指正

可以看到直接 init 获取的性能要好一些

```go
▶ C:\Users\laili\sdk\go1.15\bin\go.exe test -benchmem -bench="." -v
=== RUN   TestGetLazyInstance
--- PASS: TestGetLazyInstance (0.00s)
=== RUN   TestGetInstance
--- PASS: TestGetInstance (0.00s)
goos: windows
goarch: amd64
pkg: github.com/mohuishou/go-design-pattern/01_singleton
BenchmarkGetLazyInstanceParallel
BenchmarkGetLazyInstanceParallel-4      535702941                2.24 ns/op           0 B/op
      0 allocs/op
BenchmarkGetInstanceParallel
BenchmarkGetInstanceParallel-4          1000000000               0.586 ns/op          0 B/op
      0 allocs/op
PASS
ok      github.com/mohuishou/go-design-pattern/01_singleton     3.161s
```
