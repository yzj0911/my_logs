# 代理模式



![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/代理模式.jpeg)

# 代理模式

接下来会通过 golang 实现静态代理，有 Golang 和 java 的差异性，我们无法比较方便的利用反射实现动态代理，但是我们可以利用** go generate **实现类似的效果，并且这样实现有两个比较大的好处，一个是有静态代码检查，我们在编译期间就可以及早发现问题，第二个是性能会更好。

## 代码实现
Code
```go
package proxy

import (
	"log"
	"time"
)

// IUser IUser
type IUser interface {
	Login(username, password string) error
}

// User 用户
type User struct {
}

// Login 用户登录
func (u *User) Login(username, password string) error {
	// 不实现细节
	return nil
}

// UserProxy 代理类
type UserProxy struct {
	user *User
}

// NewUserProxy NewUserProxy
func NewUserProxy(user *User) *UserProxy {
	return &UserProxy{
		user: user,
	}
}

// Login 登录，和 user 实现相同的接口
func (p *UserProxy) Login(username, password string) error {
	// before 这里可能会有一些统计的逻辑
	start := time.Now()

	// 这里是原有的业务逻辑
	if err := p.user.Login(username, password); err != nil {
		return err
	}

	// after 这里可能也有一些监控统计的逻辑
	log.Printf("user login cost time: %s", time.Now().Sub(start))

	return nil
}
```



## 单元测试
```go
package proxy

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestUserProxy_Login(t *testing.T) {
	proxy := NewUserProxy(&User{})

	err := proxy.Login("test", "password")

	require.Nil(t, err)
}
```

## Go Generate 实现 “动态代理”
关于 `go generate` 之前已经写过一篇入门的介绍文章:` go generate and ast`，这里就不再赘述了，如果对相关的知识点不太清楚，可以先看前面的那篇文章。
注意: 在真实的项目中并不推荐这么做，因为有点得不偿失，本文只是在探讨一种可能性，并且可以复习一下 go 语法树先关的知识点
接下来我们先来看看需求。

### 需求
动态代理相比静态代理主要就是为了解决生产力，将我们从繁杂的重复劳动中解放出来，正好，在 Go 中 `Generate` 也是干这个活的

如下面的代码所示，我们的 `generate` 会读取 `struct` 上的注释，如果出现 `@proxy` 接口名  的注释，我们就会为这个 `struct` 生成一个 `proxy` 类，同时实现相同的接口，这个接口就是在注释中指定的接口

```go
// User 用户
// @proxy IUser
type User struct {
}
```
Code
接来下我们会简单的实现这个需求，由于篇幅和时间的关系，我们会略过一些检查之类的代码，例如 `User`  是否真正实现了 `IUser`  这种情况。
代码有点长，主要思路:

- 读取文件, 获取文件的 ast 语法树
- 通过 NewCommentMap 构建 node 和 comment 的关系
- 通过 comment 是否包含 @proxy 接口名  的接口，判断该节点是否需要生成代理类
- 通过 Lookup 方法找到接口
- 循环获取接口的每个方法的，方法名、参数、返回值信息
- 将方法信息，包名、需要代理类名传递给构建好的模板文件，生成代理类
- 最后用 format 包的方法格式化源代码
```go
package proxy

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/format"
	"go/parser"
	"go/token"
	"strings"
	"text/template"
)

func generate(file string) (string, error) {
	fset := token.NewFileSet() // positions are relative to fset
	f, err := parser.ParseFile(fset, file, nil, parser.ParseComments)
	if err != nil {
		return "", err
	}

	// 获取代理需要的数据
	data := proxyData{
		Package: f.Name.Name,
	}

	// 构建注释和 node 的关系
	cmap := ast.NewCommentMap(fset, f, f.Comments)
	for node, group := range cmap {
		// 从注释 @proxy 接口名，获取接口名称
		name := getProxyInterfaceName(group)
		if name == "" {
			continue
		}

		// 获取代理的类名
		data.ProxyStructName = node.(*ast.GenDecl).Specs[0].(*ast.TypeSpec).Name.Name

		// 从文件中查找接口
		obj := f.Scope.Lookup(name)

		// 类型转换，注意: 这里没有对断言进行判断，可能会导致 panic
		t := obj.Decl.(*ast.TypeSpec).Type.(*ast.InterfaceType)

		for _, field := range t.Methods.List {
			fc := field.Type.(*ast.FuncType)

			// 代理的方法
			method := &proxyMethod{
				Name: field.Names[0].Name,
			}

			// 获取方法的参数和返回值
			method.Params, method.ParamNames = getParamsOrResults(fc.Params)
			method.Results, method.ResultNames = getParamsOrResults(fc.Results)

			data.Methods = append(data.Methods, method)
		}
	}

	// 生成文件
	tpl, err := template.New("").Parse(proxyTpl)
	if err != nil {
		return "", err
	}

	buf := &bytes.Buffer{}
	if err := tpl.Execute(buf, data); err != nil {
		return "", err
	}

	// 使用 go fmt 对生成的代码进行格式化
	src, err := format.Source(buf.Bytes())
	if err != nil {
		return "", err
	}

	return string(src), nil
}

// getParamsOrResults 获取参数或者是返回值
// 返回带类型的参数，以及不带类型的参数，以逗号间隔
func getParamsOrResults(fields *ast.FieldList) (string, string) {
	var (
		params     []string
		paramNames []string
	)

	for i, param := range fields.List {
		// 循环获取所有的参数名
		var names []string
		for _, name := range param.Names {
			names = append(names, name.Name)
		}

		if len(names) == 0 {
			names = append(names, fmt.Sprintf("r%d", i))
		}

		paramNames = append(paramNames, names...)

		// 参数名加参数类型组成完整的参数
		param := fmt.Sprintf("%s %s",
			strings.Join(names, ","),
			param.Type.(*ast.Ident).Name,
		)
		params = append(params, strings.TrimSpace(param))
	}

	return strings.Join(params, ","), strings.Join(paramNames, ",")
}

func getProxyInterfaceName(groups []*ast.CommentGroup) string {
	for _, commentGroup := range groups {
		for _, comment := range commentGroup.List {
			if strings.Contains(comment.Text, "@proxy") {
				interfaceName := strings.TrimLeft(comment.Text, "// @proxy ")
				return strings.TrimSpace(interfaceName)
			}
		}
	}
	return ""
}

// 生成代理类的文件模板
const proxyTpl = `
package {{.Package}}

type {{ .ProxyStructName }}Proxy struct {
	child *{{ .ProxyStructName }}
}

func New{{ .ProxyStructName }}Proxy(child *{{ .ProxyStructName }}) *{{ .ProxyStructName }}Proxy {
	return &{{ .ProxyStructName }}Proxy{child: child}
}

{{ range .Methods }}
func (p *{{$.ProxyStructName}}Proxy) {{ .Name }} ({{ .Params }}) ({{ .Results }}) {
	// before 这里可能会有一些统计的逻辑
	start := time.Now()

	{{ .ResultNames }} = p.child.{{ .Name }}({{ .ParamNames }})

	// after 这里可能也有一些监控统计的逻辑
	log.Printf("user login cost time: %s", time.Now().Sub(start))

	return {{ .ResultNames }}
}
{{ end }}
`

type proxyData struct {
	// 包名
	Package string
	// 需要代理的类名
	ProxyStructName string
	// 需要代理的方法
	Methods []*proxyMethod
}

// proxyMethod 代理的方法
type proxyMethod struct {
	// 方法名
	Name string
	// 参数，含参数类型
	Params string
	// 参数名
	ParamNames string
	// 返回值
	Results string
	// 返回值名
	ResultNames string
}
```

## 单元测试

```go
package proxy

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test_generate(t *testing.T) {
	want := `package proxy

type UserProxy struct {
	child *User
}

func NewUserProxy(child *User) *UserProxy {
	return &UserProxy{child: child}
}

func (p *UserProxy) Login(username, password string) (r0 error) {
	// before 这里可能会有一些统计的逻辑
	start := time.Now()

	r0 = p.child.Login(username, password)

	// after 这里可能也有一些监控统计的逻辑
	log.Printf("user login cost time: %s", time.Now().Sub(start))

	return r0
}
`
	got, err := generate("./static_proxy.go")
	require.Nil(t, err)
	assert.Equal(t, want, got)
}
```
