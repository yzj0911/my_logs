---
title: "postgresql 实战一：安装和使用"
date: 2021-12-03T10:17:16+08:00
draft: false
---

# postgresql 实战一：安装和使用



# 安装
这里直接使用 docker 安装 postgresql-13
```bash
docker run --name postgresql13 -e POSTGRES_PASSWORD=123456 -p 54322:5432 -d postgres:13
```
安装成功后会绑定主机端口 54322。直接进入 postgresql13 容器，使用 pgsql。
```bash
[root@localhost ~]# docker exec -it 3e3b03e3 /bin/bash
root@3e3b03e3e442:/# psql -h localhost -p 5432 -U postgres
psql (13.0 (Debian 13.0-1.pgdg100+1))
Type "help" for help.

postgres=#
```
psql 是 pgsql 的客户端命令，使用参数如下：

- -h：指定 pgsql 的地址
- -p：指定 pgsql 的绑定端口
- -U：指定登录的用户名，默认为 postgres。后面可以紧接 "database"，直接进入指定的数据库。

# 数据库的操作
postgresql 支持的数据库操作有 增、删、查、改

## 创建数据库
创建数据库的命令为： `create database <databasename> [encoding 'UTF-8']` 
```sql
postgres=# create database test encoding 'UTF-8';
CREATE DATABASE
```

## 查询数据库
查询数据库的命令有两种：第一种是 `\l` ，只能在 psql 中使用：
```sql
postgres=# \l
                                 List of databases
   Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
-----------+----------+----------+------------+------------+-----------------------
 postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
 test      | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 testdb    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
(5 rows)
```
另一种命令为： `select * from pg_databse` 
```sql
postgres=# select datname from pg_database;
  datname
-----------
 postgres
 template1
 template0
 testdb
 test
(5 rows)
```

## 修改数据库
修改数据库使用关键字 `alter` 
```sql
postgres=# alter database testx rename to test;
ALTER DATABASE
```

## 删除数据库
```sql
postgres=# drop database test;
DROP DATABASE
```

## 选择数据库
选择数据和切换数据的命令是相同的，使用命令 `\c databasename` 
```sql
postgres=# \c test;
You are now connected to database "test" as user "postgres".
test=# \c postgres;
You are now connected to database "postgres" as user "postgres".
```

# 表的操作

## 创建表
创建 postgresql 表的语法为：
```sql
CREATE TABLE table_name(
   column1 datatype,
   column2 datatype,
   column3 datatype,
   .....
   columnN datatype,
   PRIMARY KEY( one or more columns )
);  
```
创建一张名为 COMPANY 的表：
```sql
testdb=# CREATE TABLE COMPANY (
  ID       INT PRIMARY KEY NOT NULL,
  NAME     TEXT            NOT NULL,
  AGE      INT             NOT NULL,
  ADDRESS  CHAR(50),
  SALARY   REAL
);
CREATE TABLE
```

## 查询表
查询表使用 `\d` ：
```sql
testdb=# \d
          List of relations
 Schema |  Name   | Type  |  Owner
--------+---------+-------+----------
 public | company | table | postgres
 public | person  | table | postgres
```
但是这种方式只能在 psql 命令中中使用，还可以使用 `select` 命令：
```sql
testdb=# select * from pg_tables where schemaname='public';
 schemaname | tablename | tableowner | tablespace | hasindexes | hasrules | hastriggers | rowsecurity
------------+-----------+------------+------------+------------+----------+-------------+-------------
 public     | person    | postgres   |            | f          | f        | f           | f
 public     | company   | postgres   |            | t          | f        | f           | f
(2 rows
```

## 查看表结构
查看表结构也是使用 `\d` 命令：
```sql
                  Table "public.company"
 Column  |     Type      | Collation | Nullable | Default
---------+---------------+-----------+----------+---------
 id      | integer       |           | not null |
 name    | text          |           | not null |
 age     | integer       |           | not null |
 address | character(50) |           |          |
 salary  | real          |           |          |
Indexes:
    "company_pkey" PRIMARY KEY, btree (id)
```
也可以使用 sql 实现：
```sql
testdb=# SELECT a.attnum, a.attname AS field, t.typname AS type, a.attlen AS length, a.atttypmod AS lengthvar
    , a.attnotnull AS notnull, b.description AS comment
FROM pg_class c, pg_attribute a
    LEFT JOIN pg_description b
    ON a.attrelid = b.objoid
        AND a.attnum = b.objsubid, pg_type t
WHERE c.relname = 'company'
    AND a.attnum > 0
    AND a.attrelid = c.oid
    AND a.atttypid = t.oid
ORDER BY a.attnum;
 attnum |  field  |  type  | length | lengthvar | notnull | comment
--------+---------+--------+--------+-----------+---------+---------
      1 | id      | int4   |      4 |        -1 | t       |
      2 | name    | text   |     -1 |        -1 | t       |
      3 | age     | int4   |      4 |        -1 | t       |
      4 | address | bpchar |     -1 |        54 | f       |
      5 | salary  | float4 |      4 |        -1 | f       |
(5 rows)
```

## 修改表结构
`ALTER TABLE` 语句用于添加、修改、删除表中的列：在现有表中添加列：
```sql
ALTER TABLE table_name ADD column_name datatype;
```
在现有表中删除列：
```sql
ALTER TABLE table_name DROP COLUMN colume_name;
```
在现有表中修改字段类型：
```sql
ALTER TABLE table_name ALTER COLUMN colume_name TYPE datatype;
```
向表中的列添加 `NOT NULL` 约束：
```sql
ALTER TABLE table_name MODIFY colume_name datatype NOT NULL;
```
添加约束，支持的约束有 `UNIQUE` 、 `PRIMARY KEY` 、 `CHECK` 
```sql
ALTER TABLE table_name
ADD CONSTRAINT MyUniqueConstraint UNIQUE(colume_name1, colume_name2...);
```
删除约束，支持的约束有 `UNIQUE` 、 `PRIMARY KEY` 、 `CHECK`
```sql
ALTER TABLE table_name
DROP CONSTRAINT MyUniqueConstraint UNIQUE;
```

## 删除表
`DROP` 用于删除表：
```sql
testdb=# drop table company;
DROP TABLE
```

# JSON 类型的支持
PostgreSQL 支持存储 JSON 类型的数据，提供了两种类型： `json`  和 `jsonb` 。

- `json`数据类型存储输入文本的精准拷贝，处理函数必须在每 次执行时必须重新解析该数据。
- `jsonb`数据被存储在一种分解好的 二进制格式中，它在输入时要稍慢一些，因为需要做附加的转换。但是 `jsonb`在处理时要快很多，因为不需要解析。`jsonb`也支持索引，`jsonb`不保留空格、不 保留对象键的顺序并且不保留重复的对象键。

关于 `JSONB` 的详细信息可以参考 [JSON 类型](http://www.postgres.cn/docs/12/datatype-json.html#JSON-KEYS-ELEMENTS)，这里只介绍 `JSONB` 类型数据的使用。
创建 JSONB 类型的表
```sql
CREATE TABLE posts(
  ID    INT PRIMARY KEY NOT NULL,
  spec  JSONB
);
```
插入数据，使用的关键字为 `INSERT INTO` 。
```sql
-- 插入第一条数据
insert into posts values(1, '{"name": "first posts", "content": "This is a simple post", "author": "a", "time": "2020/10/15"}');
-- 插入第二条数据
insert into posts values(2, '{"name": "jsonb", "content": "jsonb is PostgreSQL inner type", "author": "bb", "time": "2020/10/12", "tag": ["database", "PgSQL"]}');
```
添加 `key/value` 索引：
```sql
-- 给所有 key/values 添加索引
CREATE INDEX idx_posts_spec ON posts USING gin (spec);
-- 给指定的 key/values 添加索引
CREATE INDEX idx_posts_spec_author ON posts USING gin ((spec->'author'));
```
数据查询 `SELECT` ，全表查询：
```sql
testdb=# select * from posts;
 id |                                                                spec
----+------------------------------------------------------------------------------------------------------------------------------------
  1 | {"name": "first posts", "time": "2020/10/15", "author": "a", "content": "This is a simple post"}
  2 | {"tag": ["database", "PgSQL"], "name": "jsonb", "time": "2020/10/12", "author": "bb", "content": "jsonb is PostgreSQL inner type"}
(2 rows)
```
查询 `JSONB` 内的数据：
```sql
-- spec->'name' 输出的数据格式为原生格式
testdb=# select id, spec->'name' from posts;
 id |   ?column?
----+---------------
  1 | "first posts"
  2 | "jsonb"
(2 rows)

-- spec->>'name' 输出格式为 TEXT
testdb=# select id, spec->>'name' from posts;
 id |  ?column?
----+-------------
  1 | first posts
  2 | jsonb
(2 rows)

testdb=# insert into posts values(3, '{"name": "other", "content": "other data", "author": "bb", "other": {"name": "other"}}');
INSERT 0 1

-- 使用 -> 操作符查询多级 json 格式的数据
testdb=# select id, spec->'name' as spec_name, spec->'other'->'name' as spec_other_name from posts;
 id |   spec_name   | spec_other_name
----+---------------+-----------------
  1 | "first posts" |
  2 | "jsonb"       |
  3 | "other"       | "other"
  
-- 使用 ? 查询 key 是否存在
testdb=# select id, spec from posts where spec ? 'tag';
 id |                                                                spec
----+------------------------------------------------------------------------------------------------------------------------------------
  2 | {"tag": ["database", "PgSQL"], "name": "jsonb", "time": "2020/10/12", "author": "bb", "content": "jsonb is PostgreSQL inner type"}
(1 row)

-- 使用 ? 查询 values
testdb=# select id, spec from posts where spec->'author' ? 'bb';
 id |                                                                spec
----+------------------------------------------------------------------------------------------------------------------------------------
  2 | {"tag": ["database", "PgSQL"], "name": "jsonb", "time": "2020/10/12", "author": "bb", "content": "jsonb is PostgreSQL inner type"}
  3 | {"name": "other", "other": {"name": "other"}, "author": "bb", "content": "other data"}
(2 rows)

-- 使用 @> 来精确查询
testdb=# select id, spec from posts where spec @> '{"other": {"name": "other"}}'::jsonb;
 id |                                          spec
----+----------------------------------------------------------------------------------------
  3 | {"name": "other", "other": {"name": "other"}, "author": "bb", "content": "other data"}
(1 row)
```
`JSONB` 支持的其他函数和操作符可以参考 [这里](http://www.postgres.cn/docs/12/functions-json.html#FUNCTIONS-JSONB-OP-TABLE)。

