# 备忘录模式

# 备忘录模式
![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/备忘录模式.jpeg)

## 代码实现
Code
```go
// Package memento 备忘录模式
// 下面这个例子采用原课程的例子，一个输入程序
// 如果输入 :list 则显示当前保存的内容
// 如果输入 :undo 则删除上一次的输入
// 如果输入其他的内容则追加保存
package memento

// InputText 用于保存数据
type InputText struct {
	content string
}

// Append 追加数据
func (in *InputText) Append(content string) {
	in.content += content
}

// GetText 获取数据
func (in *InputText) GetText() string {
	return in.content
}

// Snapshot 创建快照
func (in *InputText) Snapshot() *Snapshot {
	return &Snapshot{content: in.content}
}

// Restore 从快照中恢复
func (in *InputText) Restore(s *Snapshot) {
	in.content = s.GetText()
}

// Snapshot 快照，用于存储数据快照
// 对于快照来说，只能不能被外部（不同包）修改，只能获取数据，满足封装的特性
type Snapshot struct {
	content string
}

// GetText GetText
func (s *Snapshot) GetText() string {
	return s.content
}
```
## 单元测试
```go
package memento

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestDemo(t *testing.T) {
	in := &InputText{}
	snapshots := []*Snapshot{}

	tests := []struct {
		input string
		want  string
	}{
		{
			input: ":list",
			want:  "",
		},
		{
			input: "hello",
			want:  "",
		},
		{
			input: ":list",
			want:  "hello",
		},
		{
			input: "world",
			want:  "",
		},
		{
			input: ":list",
			want:  "helloworld",
		},
		{
			input: ":undo",
			want:  "",
		},
		{
			input: ":list",
			want:  "hello",
		},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			switch tt.input {
			case ":list":
				assert.Equal(t, tt.want, in.GetText())
			case ":undo":
				in.Restore(snapshots[len(snapshots)-1])
				snapshots = snapshots[:len(snapshots)-1]
			default:
				snapshots = append(snapshots, in.Snapshot())
				in.Append(tt.input)
			}
		})
	}
}
```
