---
title: "组合模式"
date: 2022-06-07T10:25:33+08:00
draft: true
tags: ["设计模式"]
series: [""]
categories: ["设计模式"]
---


![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/组合模式.jpeg)

# 组合模式
公司的人员组织就是一个典型的树状的结构，现在假设我们现在有部分，和员工，两种角色，一个部门下面可以存在子部门和员工，员工下面不能再包含其他节点。
我们现在要实现一个统计一个部门下员工数量的功能

## Code
```go
package composite

// IOrganization 组织接口，都实现统计人数的功能
type IOrganization interface {
	Count() int
}

// Employee 员工
type Employee struct {
	Name string
}

// Count 人数统计
func (Employee) Count() int {
	return 1
}

// Department 部门
type Department struct {
	Name string

	SubOrganizations []IOrganization
}

// Count 人数统计
func (d Department) Count() int {
	c := 0
	for _, org := range d.SubOrganizations {
		c += org.Count()
	}
	return c
}

// AddSub 添加子节点
func (d *Department) AddSub(org IOrganization) {
	d.SubOrganizations = append(d.SubOrganizations, org)
}

// NewOrganization 构建组织架构 demo
func NewOrganization() IOrganization {
	root := &Department{Name: "root"}
	for i := 0; i < 10; i++ {
		root.AddSub(&Employee{})
		root.AddSub(&Department{Name: "sub", SubOrganizations: []IOrganization{&Employee{}}})
	}
	return root
}
```

## Test

```go 
package composite

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewOrganization(t *testing.T) {
	got := NewOrganization().Count()
	assert.Equal(t, 20, got)
}
```


