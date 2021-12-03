

---
title: "Golang使用json格式实现增删查改"
date: 2021-12-03T10:17:16+08:00
draft: false
---

# Golang使用json格式实现增删查改


# 需求和思路
在一般的小项目或者一个小软件,例如客户端之类的小程序中,可能会需要数据的持久化.但是使用一般的数据库(Mysql)之类的不合适.使用sqlite3这种嵌入式的是个较好的方法,但是Go语言中sqlite3的库是C语言的,Cgo不支持跨平台编译.正是由于这种需求,才想到使用json格式将数据直接保存在文件中.
具体的思路是怎么样呢? 在Go语言中如果要将数据转化成json格式的话,有两种格式 struct 和 map. 如果同时需要增删查改功能的话,将map作为中间格式是比较合适的.接下来我们就来实现它.

# 查询操作
这种操作的实现比较简单,直接将文件中的数据读取出来,使用json库反序列化就可以了. 代码如下 :
```go
type Product struct {
	Name string `json:"name"`
	Num  int    `json:"num"`
}

func findAll() {
	ps := make([]Product, 0)

	data, err := ioutil.ReadFile("./index.json")
	if err != nil {
		log.Fatal(err)
	}

	// 这里参数要指定为变量的地址
	err = json.Unmarshal(data, &ps)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println(ps)
}
```

# 添加操作
添加的实现实在查询的基础上的,我们需要先查询文件中的数据库,并转化为map格式,再将struct也转化为map格式(这里要使用反射),合并map,json序列化,最后保存在文件中.代码如下:
```go
func create() {
	fields := make([]map[string]interface{}, 0)
	
	p1 := &Product{
		Name: "Blog",
		Num:  2,
	}
	
	_, _ = json.Marshal(p1)
	// 读取文件中的数据,保存为map格式
	data, _ := ioutil.ReadFile("./index.json")
	err := json.Unmarshal(data, &fields)
	if err != nil {
		log.Fatal(err)
	}
	
	// 使用反射将struct转化为map
	tp := reflect.TypeOf(p1).Elem()
	vp := reflect.ValueOf(p1).Elem()
	field := make(map[string]interface{}, 0)
	for i := 0; i < tp.NumField(); i++ {
		field1 := tp.Field(i)
		field2 := vp.Field(i)
		key := field1.Tag.Get("json")
		field[key] = field2.Interface()
	}
	// 合并map
	fields = append(fields, field)
	
	// 写入文件
	out, _ := json.Marshal(fields)
	_ = ioutil.WriteFile("./index.json", out, 0755)
}
```

# 条件查询
思路:  将struct转化为map,根据输入的条件查询.查询的结果转化为struct.代码如下:
```go
func FindOne() {
	product := &Product{}

	p1 := &Product{
		Name: "John",
		Num:  23,
	}

	// 使用反射将struct转化为map
	tp := reflect.TypeOf(p1).Elem()
	vp := reflect.ValueOf(p1).Elem()
	field := make(map[string]interface{}, 0)
	for i := 0; i < tp.NumField(); i++ {
		field1 := tp.Field(i)
		field2 := vp.Field(i)
		key := field1.Tag.Get("json")
		switch field2.Kind() {
		case reflect.Int:
			field[key] = float64(field2.Interface().(int))
		case reflect.Int8:
			field[key] = float64(field2.Interface().(int8))
		case reflect.Int16:
			field[key] = float64(field2.Interface().(int16))
		case reflect.Int32:
			field[key] = float64(field2.Interface().(int32))
		case reflect.Int64:
			field[key] = float64(field2.Interface().(int64))
		case reflect.Uint:
			field[key] = float64(field2.Interface().(uint))
		case reflect.Uint8:
			field[key] = float64(field2.Interface().(uint8))
		case reflect.Uint16:
			field[key] = float64(field2.Interface().(uint16))
		case reflect.Uint32:
			field[key] = float64(field2.Interface().(uint32))
		case reflect.Uint64:
			field[key] = float64(field2.Interface().(uint64))
		case reflect.Float32:
			field[key] = float64(field2.Interface().(float32))
		case reflect.Float64:
			field[key] = field2.Interface()
		default:
			field[key] = field2.Interface()
		}
	}

	_, _ = json.Marshal(p1)
	// 读取文件中的数据,保存为map格式
	// 数据转化为map时,数值类型的统一变成float64
	data, _ := ioutil.ReadFile("./index.json")
	fields := make([]map[string]interface{}, 0)
	err := json.Unmarshal(data, &fields)
	if err != nil {
		log.Fatal(err)
	}

	// 查询的条件
	columns := []string{"name", "num"}
	length := len(columns)
	for _, item := range fields {
		for i := 0; i < length; i++ {
			// 这里的比较需要改进
			if item[columns[i]] != field[columns[i]] {
				break
			}
			if i == length-1 {
				field = item
				goto OVER
			}
		}
	}
OVER:
	fmt.Println(field)

	out, _ := json.Marshal(field)
	_ = json.Unmarshal(out, &product)

	fmt.Println(product)
}
```

# 修改操作
修改操作在查询操作的基础上实现, 修改操作需要有一个id值,能确定元素的唯一性.代码如下:
```go
func Update() {
	p1 := &Product{
		Id:   "2bbec87025968879c3c9682abe3bf730",
		Name: "John_e",
		Num:  100,
	}

	// 使用反射将struct转化为map
	tp := reflect.TypeOf(p1).Elem()
	vp := reflect.ValueOf(p1).Elem()
	field := make(map[string]interface{}, 0)
	for i := 0; i < tp.NumField(); i++ {
		field1 := tp.Field(i)
		field2 := vp.Field(i)
		key := field1.Tag.Get("json")
		switch field2.Kind() {
		case reflect.Int:
			field[key] = float64(field2.Interface().(int))
		case reflect.Int8:
			field[key] = float64(field2.Interface().(int8))
		case reflect.Int16:
			field[key] = float64(field2.Interface().(int16))
		case reflect.Int32:
			field[key] = float64(field2.Interface().(int32))
		case reflect.Int64:
			field[key] = float64(field2.Interface().(int64))
		case reflect.Uint:
			field[key] = float64(field2.Interface().(uint))
		case reflect.Uint8:
			field[key] = float64(field2.Interface().(uint8))
		case reflect.Uint16:
			field[key] = float64(field2.Interface().(uint16))
		case reflect.Uint32:
			field[key] = float64(field2.Interface().(uint32))
		case reflect.Uint64:
			field[key] = float64(field2.Interface().(uint64))
		case reflect.Float32:
			field[key] = float64(field2.Interface().(float32))
		case reflect.Float64:
			field[key] = field2.Interface()
		default:
			field[key] = field2.Interface()
		}
	}

	_, _ = json.Marshal(p1)
	// 读取文件中的数据,保存为map格式
	// 数据转化为map时,数值类型的统一变成float64
	data, _ := ioutil.ReadFile("./index.json")
	fields := make([]map[string]interface{}, 0)
	err := json.Unmarshal(data, &fields)
	if err != nil {
		log.Fatal(err)
	}

	// 修改的条件
	columns := []string{"name", "num"}
	for _, v := range fields {
		if v["_id"] == field["_id"] {
			for _, col := range columns {
				v[col] = field[col]
			}
			field = v
		}
	}

	out, _ := json.MarshalIndent(fields, "", "  ")
	_ = ioutil.WriteFile("./index.json", out, 0755)
}
```
# 删除操作
最后就是删除操作了,这个比较思路简单,输入唯一的id值,删除对应的字段,再保存到文件就可以了.代码如下:
```go
func Delete() {
	p1 := &Product{
		Id:   "db43fa2d4f69cddce7494941cb36032b",
		Name: "John_e",
		Num:  100,
	}

	_, _ = json.Marshal(p1)
	// 读取文件中的数据,保存为map格式
	// 数据转化为map时,数值类型的统一变成float64
	data, _ := ioutil.ReadFile("./index.json")
	fields := make([]map[string]interface{}, 0)
	err := json.Unmarshal(data, &fields)
	if err != nil {
		log.Fatal(err)
	}

	length := len(fields)
	for index, field := range fields {
		if field["_id"] == p1.Id {
			if index == length - 1 {
				fields = fields[0:index]
			} else {
				fields = append(fields[0:index], fields[index+1:]...)
			}
		}
	}

	out, _ := json.MarshalIndent(fields, "", "  ")
	_ = ioutil.WriteFile("./index.json", out, 0755)
}
```
# 完整版
最后在附上完整版代码：
```golang
package store

import (
	"bytes"
	"crypto/md5"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"time"
)

type Store struct {
	Dir string
}

func NewStore(dir string) (*Store, error) {

	// .开头的为相对路径,补全为全路径
	if strings.HasPrefix(dir, ".") {
		pwd, _ := os.Getwd()
		dir = filepath.Join(pwd, dir)
	}
	store := &Store{Dir: dir}

	st, err := os.Stat(dir)
	if err != nil {
		err = os.Mkdir(dir, 0755)
		if err != nil {
			return nil, err
		}
	} else if st != nil && !st.IsDir() {
		return nil, errors.New("file already exists")
	}

	return store, nil
}

// 创建与结构体对应的json文件
func (s *Store) Sync(values ...interface{}) error {
	for _, v := range values {
		tb := parseTn(v)
		if tb == "" {
			return errors.New("does not find store")
		}
		_path := filepath.Join(s.Dir, tb)
		_, err := os.Stat(_path)
		if err != nil {
			_ = ioutil.WriteFile(_path, []byte("[]"), 0755)
		}
	}
	return nil
}

// 删除所有
func (s *Store) Destroy() error {
	return os.RemoveAll(s.Dir)
}

func (s *Store) FindAll(v interface{}) error {

	_path, err := s.before(v)
	if err != nil {
		return err
	}

	out, err := s.readAll(_path)
	if err != nil {
		return err
	}
	err = json.Unmarshal(out, &v)
	return err
}

func (s *Store) FindOne(v interface{}, columns ...string) (interface{}, error) {

	_path, err := s.before(v)
	if err != nil {
		return nil, err
	}

	data, err := s.readAll(_path)
	if err != nil {
		return nil, err
	}

	fields := make([]map[string]interface{}, 0)
	err = json.Unmarshal(data, &fields)
	if err != nil {
		return nil, err
	}

	m := structToMap(v)
	length := len(columns)
	for _, item := range fields {
		for i := 0; i < length; i++ {
			// TODO 这里的比较需要改进
			if item[columns[i]] != m[columns[i]] {
				break
			}
			if i == length-1 {
				m = item
				goto OVER
			}
		}
	}
OVER:

	err = mapToStruct(m, &v)
	if err != nil {
		return nil, err
	}

	return v, nil
}

func (s *Store) Create(v interface{}) error {

	_path, err := s.before(v)
	if err != nil {
		return err
	}

	data, err := s.readAll(_path)
	if err != nil {
		return err
	}

	fields := make([]map[string]interface{}, 0)
	err = json.Unmarshal(data, &fields)
	if err != nil {
		return err
	}

	m := structToMap(v)
	m["_id"] = randId()

	fields = append(fields, m)

	err = s.writeAll(_path, fields)
	if err != nil {
		return err
	}

	err = mapToStruct(m, v)
	if err != nil {
		return err
	}

	return nil
}

func (s *Store) Update(v interface{}, columns ...string) error {

	_path, err := s.before(v)
	if err != nil {
		return err
	}

	data, err := s.readAll(_path)
	if err != nil {
		return err
	}

	fields := make([]map[string]interface{}, 0)
	err = json.Unmarshal(data, &fields)
	if err != nil {
		return err
	}

	m := structToMap(v)
	for _, v := range fields {
		if v["_id"] == m["_id"] {
			for _, col := range columns {
				v[col] = m[col]
			}
			m = v
		}
	}

	err = s.writeAll(_path, fields)
	if err != nil {
		return err
	}

	return nil
}

func (s *Store) Delete(v interface{}) error {

	_path, err := s.before(v)
	if err != nil {
		return err
	}

	data, err := s.readAll(_path)
	if err != nil {
		return err
	}

	fields := make([]map[string]interface{}, 0)
	err = json.Unmarshal(data, &fields)
	if err != nil {
		return err
	}

	m := structToMap(v)
	length := len(fields)
	for index, field := range fields {
		if field["_id"] == m["_id"] {
			if index == length-1 {
				fields = fields[0:index]
			} else {
				fields = append(fields[0:index], fields[index+1:]...)
			}
		}
	}

	err = s.writeAll(_path, fields)
	if err != nil {
		return err
	}

	return nil
}

func (s *Store) Clean(v interface{}) error {
	_path, err := s.before(v)
	if err != nil {
		return err
	}

	return os.Remove(_path)
}

func (s *Store) readAll(file string) ([]byte, error) {
	out, err := ioutil.ReadFile(file)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *Store) writeAll(file string, v interface{}) error {
	out, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}

	err = ioutil.WriteFile(file, out, 0755)
	if err != nil {
		return err
	}

	return nil
}

func (s *Store) before(v interface{}) (string, error) {
	tb := parseTn(v)
	if tb == "" {
		return "", errors.New("invalid table name")
	}

	_path := filepath.Join(s.Dir, tb)
	_, err := os.Stat(_path)
	if err != nil {
		return "", err
	}

	return _path, nil
}

func structToMap(v interface{}) map[string]interface{} {
	tp := reflect.TypeOf(v).Elem()
	vp := reflect.ValueOf(v).Elem()
	field := make(map[string]interface{}, 0)
	for i := 0; i < tp.NumField(); i++ {
		field1 := tp.Field(i)
		field2 := vp.Field(i)
		key := field1.Tag.Get("json")
		field[key] = field2.Interface()
		switch field2.Kind() {
		case reflect.Int:
			field[key] = float64(field2.Interface().(int))
		case reflect.Int8:
			field[key] = float64(field2.Interface().(int8))
		case reflect.Int16:
			field[key] = float64(field2.Interface().(int16))
		case reflect.Int32:
			field[key] = float64(field2.Interface().(int32))
		case reflect.Int64:
			field[key] = float64(field2.Interface().(int64))
		case reflect.Uint:
			field[key] = float64(field2.Interface().(uint))
		case reflect.Uint8:
			field[key] = float64(field2.Interface().(uint8))
		case reflect.Uint16:
			field[key] = float64(field2.Interface().(uint16))
		case reflect.Uint32:
			field[key] = float64(field2.Interface().(uint32))
		case reflect.Uint64:
			field[key] = float64(field2.Interface().(uint64))
		case reflect.Float32:
			field[key] = float64(field2.Interface().(float32))
		case reflect.Float64:
			field[key] = field2.Interface()
		default:
			field[key] = field2.Interface()
		}
	}

	return field
}

func mapToStruct(m map[string]interface{}, v interface{}) error {
	out, err := json.Marshal(m)
	if err != nil {
		return err
	}
	return json.Unmarshal(out, &v)
}

func toSnake(s string) string {
	out := bytes.Buffer{}

	bName := []byte(s)

	point := 0
	for index, b := range bName {
		// 非大写,不需要转化
		if b < 65 || b > 90 || index-point < 2 {
			out.WriteByte(b)
			continue
		}
		// 首字符大写,直接转化为小写
		if index == 0 {
			out.WriteByte(b + 32)
			point = index
		}
		// 连续三个大写,触发转化
		if index-point >= 2 {
			out.WriteByte(95)
			out.WriteByte(b + 32)
			point = index
		}
	}

	return out.String()
}

func parseTn(v interface{}) string {
	var name string

	tp := reflect.TypeOf(v).Elem()
	switch tp.Kind() {
	case reflect.Ptr:
		sp := strings.Split(tp.String(), ".")
		name = sp[len(sp)-1]
	case reflect.Slice:
		sp := strings.Split(tp.String(), ".")
		name = sp[len(sp)-1]
	case reflect.Struct:
		name = tp.Name()
	}
	name = toSnake(name)
	return name + ".json"
}

func randId() string {
	return fmt.Sprintf("%x", md5.Sum([]byte(time.Now().String())))
}
```

