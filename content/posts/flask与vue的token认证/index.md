---
title: "Flask与Vue的token认证"
date: 2021-12-03T10:17:16+08:00
draft: false
---


# Flask与Vue的token认证


> 后端使用flask设计基于token认证方式的restful接口，前端使用vue.js全家桶，利用axios通讯。

感谢两篇文章的作者：
- http://www.cnblogs.com/vovlie/p/4182814.html
- https://segmentfault.com/a/1190000008383094?_ea=1639495

源码链接：https://github.com/xingyys/flaskvue

# 后端Flask
Flask采用token认证方式，主要思路是通过`/api/login`登录获取`token`，然后使用`token`调用各个接口。
所用到框架的库：
- flask
- flask-cors：flask跨域
- flask-sqlachemy: flask数据库orm
- flask-httpauth：flask的auth认证
- passlib: python密码解析库
- itsdangerous
## 后端结构图
```python
flask/
├── app    # 主目录
│   ├── __init__.py
│   ├── __init__.pyc
│   ├── models.py    # 数据库
│   ├── models.pyc
│   ├── views.py    # 视图
│   └── views.pyc
├── config.py    # 配置信息
├── config.pyc
├── db_create.py    # 创建数据库
├── db_migrate.py   # 更新数据库
├── db_repository
│   ├── __init__.py
│   ├── __init__.pyc
│   ├── manage.py
│   ├── migrate.cfg
│   ├── README
│   └── versions
│       ├── 008_migration.py
│       ├── 008_migration.pyc
│       ├── 009_migration.py
│       ├── 009_migration.pyc
│       ├── __init__.py
│       └── __init__.pyc
├── index.html
└── run.py    # app的运行文件

```
## 具体实现
### 系统初始化`app/__init__.py`
```python
# -*- coding:utf-8 -*-

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_httpauth import HTTPBasicAuth
from flask_cors import CORS

app = Flask(__name__)
# flask的跨域解决
CORS(app)
app.config.from_object('config')
db = SQLAlchemy(app)
auth = HTTPBasicAuth()

from . import models, views
```
### 配置文件`config.py`
```
import os
basedir = os.path.abspath(os.path.dirname(__file__))

SQLALCHEMY_DATABASE_URI = "mysql://root:123456@127.0.0.1/rest"
SQLALCHEMY_MIGRATE_REPO = os.path.join(basedir, 'db_repository')
SQLALCHEMY_TRACK_MODIFICATIONS = True
BASEDIR = basedir
# 安全配置
CSRF_ENABLED = True
SECRET_KEY = 'jklklsadhfjkhwbii9/sdf\sdf'
```
环境中使用`mysql`数据库，版本为`mariadb 10.1.22`。创建`rest`表
```
$ mysql -uroot -p xxxxxx
$ create database rest default charset utf8;
```
### 创建数据库表`app/models.py`
```python
# -*- coding:utf-8 -*-

from app import db, app
from passlib.apps import custom_app_context
from itsdangerous import TimedJSONWebSignatureSerializer as Serializer, SignatureExpired, BadSignature

class User(db.Model):
    __tablename__ =  'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(32), index=True)
    password = db.Column(db.String(128))

    # 密码加密
    def hash_password(self, password):
        self.password = custom_app_context.encrypt(password)
    
    # 密码解析
    def verify_password(self, password):
        return custom_app_context.verify(password, self.password)

    # 获取token，有效时间10min
    def generate_auth_token(self, expiration = 600):
        s = Serializer(app.config['SECRET_KEY'], expires_in = expiration)
        return s.dumps({ 'id': self.id })

    # 解析token，确认登录的用户身份
    @staticmethod
    def verify_auth_token(token):
        s = Serializer(app.config['SECRET_KEY'])
        try:
            data = s.loads(token)
        except SignatureExpired:
            return None # valid token, but expired
        except BadSignature:
            return None # invalid token
        user = User.query.get(data['id'])
        return user
```
创建数据库`users`表：
```
$ python db_create.py
$ python db_migrate.py
```

### 视图`app/views.py`
```python
from app import app, db, auth
from flask import render_template, json, jsonify, request, abort, g
from app.models import *

@app.route("/")
@auth.login_required
def index():    
    return jsonify('Hello, %s' % g.user.username)


@app.route('/api/users', methods = ['POST'])
def new_user():
    username = request.json.get('username')
    password = request.json.get('password')
    if username is None or password is None:
        abort(400) # missing arguments
    if User.query.filter_by(username = username).first() is not None:
        abort(400) # existing user
    user = User(username = username)
    user.hash_password(password)
    db.session.add(user)
    db.session.commit()
    return jsonify({ 'username': user.username })

@auth.verify_password
def verify_password(username_or_token, password):
    if request.path == "/api/login":
        user = User.query.filter_by(username=username_or_token).first()
        if not user or not user.verify_password(password):
            return False
    else:
        user = User.verify_auth_token(username_or_token)
        if not user:
            return False    
    g.user = user   
    return True


@app.route('/api/login')
@auth.login_required
def get_auth_token():
    token = g.user.generate_auth_token()
    return jsonify(token)
```

用户注册后密码加密存储，确认用户身份时密码解密。需要认证的`api`上添加`@auth.login_required`，它会在调用接口之前调用`@auth.verify_password`下的方法(此方法唯一)如`verify_password`。根据请求的路径选择不同的认证方式。
### 测试
> 使用curl命令测试接口

注册用户:
```
$ curl -i -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"123456"}' http://127.0.0.1:5000/api/register
HTTP/1.0 200 OK
Content-Type: application/json
Access-Control-Allow-Origin: *
Content-Length: 26
Server: Werkzeug/0.12.2 Python/2.7.13
Date: Wed, 20 Sep 2017 06:33:46 GMT

{
  "username": "admin"
}
```
查看数据库：
```
MariaDB [rest]> select * from users\G;
*************************** 1. row ***************************
      id: 1
username: admin
password: $6$rounds=656000$etV4F3xLL0dwflX8$mLFX9l5dumBnQFtajGmey346viGuQ4bxR7YhQdKtB/nQH9ij2e3HHMEBPj.ef/o//4o9P2Wd3Y7dxQfjwR2hY/
1 row in set (0.00 sec)
```
获取token：
```
 curl -i -u admin:123456  -X GET -H "Content-Type: application/json"  http://127.0.0.1:5000/api/login
HTTP/1.0 200 OK
Content-Type: application/json
Access-Control-Allow-Origin: *
Content-Length: 125
Server: Werkzeug/0.12.2 Python/2.7.13
Date: Wed, 20 Sep 2017 06:37:01 GMT

"eyJhbGciOiJIUzI1NiIsImV4cCI6MTUwNTg5MDAyMSwiaWF0IjoxNTA1ODg5NDIxfQ.eyJpZCI6MX0.nUIKq-ZhFOiLPwZyUmfgWPfHYNy8o6eoR6lmzdsY0oQ"
```
使用token调用api：
```
$ curl -i -u eyJhbGciOiJIUzI1NiIsImV4cCI6MTUwNTg5MDAyMSwiaWF0IjoxNTA1ODg5NDIxfQ.eyJpZCI6MX0.nUIKq-ZhFOiLPwZyUmfgWPfHYNy8o6eoR6lmzdsY0oQ:unused   -X GET -H "Content-Type: application/json"  http://127.0.0.1:5000/
HTTP/1.0 200 OK
Content-Type: application/json
Access-Control-Allow-Origin: *
Content-Length: 15
Server: Werkzeug/0.12.2 Python/2.7.13
Date: Wed, 20 Sep 2017 06:38:22 GMT

"Hello, admin"
```
基于`token`的`Flask api`成功！！！！

# 前端Vue.js
前端使用`vue`的全家桶，axios前后端通讯，axios拦截器，localStorage保存token
所使用的框架和库：
- vue2.0
- iview2.X
- axios
- vuex
- vue-router

## 具体实现
### `main.js`
```js

// 初始化axios
axios.defaults.baseURL = 'http://127.0.0.1:5000'
axios.defaults.auth = {
    username: '',
    password: '',
}

// axios.interceptors.request.use((config) => {
//     console.log(config)
//     return config;
// }, (error) => {
//     return Promise.reject(error)
// })

// axios拦截器，401状态时跳转登录页并清除token
axios.interceptors.response.use((response) => {
    return response;
}, (error) => {
    if (error.response) {
        switch (error.response.status) {
            case 401:
                store.commit('del_token')
                router.push('/login')
        }
    }
    return Promise.reject(error.response.data)
})

// 路由跳转
router.beforeEach((to, from, next) => {
    if (to.meta.required) {
        // 检查localStorage
        if (localStorage.token) {
            store.commit('set_token', localStorage.token)
            // 添加axios头部Authorized
            axios.defaults.auth = {
                username: store.state.token,
                password: store.state.token,
            }
            // iview的页面加载条
            iView.LoadingBar.start();
            next()
        } else {
            next({
                path: '/login',
            })
        }
    } else {
        iView.LoadingBar.start();
        next()
    }
})

router.afterEach((to, from, next) => {
    iView.LoadingBar.finish();
})
```

### 路由
```
export default new Router({
    routes: [{
        path: '/',
        name: 'index',
        component: Index,
        meta: {
            required: true,
        }
    }, {
        path: '/login',
        name: 'login',
        component: Login,
    }]
})
```
路由添加`meta`字段，作为需要认证路由的标志
### vuex
```
export default new Vuex.Store({
    state: {
        token: ''
    },
    mutations: {
        set_token(state, token) {
            state.token = token
            localStorage.token = token
        },
        del_token(state) {
            state.token = ''
            localStorage.removeItem('token')
        }
    }
})
```
`vuex`中保存`token`，同时修改删除`token`和`localStorage.token`

### 登录和登出
登录：
```js
handleSubmit(name, form) {
    this.$refs[name].validate((valid) => {
        if (valid) {
            // 用户名密码简单验证后添加到axios的auth中
            this.$axios.defaults.auth = {
                username: form.username,
                password: form.password,
            }
            this.$axios.get('/api/login').then(response => {
                this.$Message.success("提交成功")
                let data = response.data
                // 保存token
                this.$store.commit('set_token', data)
                this.$router.push('/')
            }).catch(error => {
                this.$Message.error(error.status)
            })
        } else {
            this.$Message.error('表单验证失败!');
        }
    })
}
```
登出：
```
logout() {
    this.$store.commit('del_token')
    this.$router.push('/login')
}
```
删除`token`并跳转到登录页

> `flask`和`vue`的`token`认证就完成了！！！！


