# gin 常用中间件



# 日志

```
// 日志记录到文件
func (d *Handler) LoggerToFile() gin.HandlerFunc {

	return func(c *gin.Context) {
		// 开始时间
		startTime := time.Now()

		// 处理请求
		c.Next()

		// 结束时间
		endTime := time.Now()

		// 执行时间
		latencyTime := endTime.Sub(startTime)

		// 请求方式
		reqMethod := c.Request.Method

		// 请求路由
		reqUri := c.Request.RequestURI

		// 状态码
		statusCode := c.Writer.Status()

		// 请求IP
		clientIP := c.ClientIP()

		//// 日志格式
		//fmt.Printf("%s [INFO] %s %s %3d %13v %15s \r\n",
		//	startTime.Format("2006-01-02 15:04:05"),
		//	reqMethod,
		//	reqUri,
		//	statusCode,
		//	latencyTime,
		//	clientIP,
		//)

		log.Infof("%s %s %3d %13v %15s",
			reqMethod,
			reqUri,
			statusCode,
			latencyTime,
			clientIP)

		if c.Request.Method != "GET" && c.Request.Method != "OPTIONS" && conf.Conf.LoggerConfig.EnabledDB {
			d.SetDBOperLog(c, clientIP, statusCode, reqUri, reqMethod, latencyTime)
		}
	}
}

```

# 自定义异常处理
```
func (d *Handler) CustomError(c *gin.Context) {
	defer func() {
		if err := recover(); err != nil {

			if c.IsAborted() {
				c.Status(200)
			}
			switch errStr := err.(type) {
			case string:
				p := strings.Split(errStr, "#")
				if len(p) == 3 && p[0] == "CustomError" {
					statusCode, e := strconv.Atoi(p[1])
					if e != nil {
						break
					}
					c.Status(statusCode)
					fmt.Println(
						time.Now().Format("2006-01-02 15:04:05"),
						"[ERROR]",
						c.Request.Method,
						c.Request.URL,
						statusCode,
						c.Request.RequestURI,
						c.ClientIP(),
						p[2],
					)
					c.JSON(http.StatusOK, gin.H{
						"code": statusCode,
						"msg":  p[2],
					})
				}
			default:
				panic(err)
			}
		}
	}()
	c.Next()
}

```

# 请求id
```
func (d *Handler) RequestId() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Check for incoming header, use it if exists
		requestId := c.Request.Header.Get("X-Request-Id")

		// Create request id with UUID4
		if requestId == "" {
			u4 := uuid.NewV4()
			requestId = u4.String()
		}

		// Expose it for use in the application
		c.Set("X-Request-Id", requestId)

		// Set X-Request-Id header
		c.Writer.Header().Set("X-Request-Id", requestId)
		c.Next()
	}
}
```

# nocache
```
// NoCache is a middleware function that appends headers
// to prevent the client from caching the HTTP response.
func (d *Handler) NoCache(c *gin.Context) {
	c.Header("Cache-Control", "no-cache, no-store, max-age=0, must-revalidate, value")
	c.Header("Expires", "Thu, 01 Jan 1970 00:00:00 GMT")
	c.Header("Last-Modified", time.Now().UTC().Format(http.TimeFormat))
	c.Next()
}
```

# 跨域
```
//Options is a middleware function that appends headers
// for options requests and aborts then exits the middleware
// chain and ends the request.
func (d *Handler) Options(c *gin.Context) {
	if c.Request.Method != "OPTIONS" {
		c.Next()
	} else {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "lang,X-DEVICE-ID,X-APP-VERSION,X-CHANNEL,authorization, origin, content-type, accept,X-TENANT-CODE,sign,time")
		c.Header("Allow", "HEAD,GET,POST,PUT,PATCH,DELETE,OPTIONS")
		c.Header("Content-Type", "application/json")
		c.AbortWithStatus(200)
	}
}
```

# Secure
```
// Secure is a middleware function that appends security
// and resource access headers.
func (d *Handler) Secure(c *gin.Context) {
	c.Header("Access-Control-Allow-Origin", "*")
	//c.Header("X-Frame-Options", "DENY")
	c.Header("X-Content-Type-Options", "nosniff")
	c.Header("X-XSS-Protection", "1; mode=block")
	if c.Request.TLS != nil {
		c.Header("Strict-Transport-Security", "max-age=31536000")
	}

	// Also consider adding Content-Security-Policy headers
	// c.Header("Content-Security-Policy", "script-src 'self' https://cdnjs.cloudflare.com")
}
```

# 限流
```
func (d *Handler) Limiter(ctx *gin.Context) {
	now := time.Now().UnixNano()
	key := "REDIS_LIMITER"
	userCntKey := fmt.Sprint(constant.ImApiRedisPrefix, ctx.ClientIP(), ":", key)

	//五秒限流
	var limit int64 = 10
	dura := time.Second * 60
	//删除有序集合中的五秒之前的数据
	d.Dao.Redis.ZRemRangeByScore(ctx, userCntKey,
		"0",
		fmt.Sprint(now-(dura.Nanoseconds()))).Result()

	reqs, _ := d.Dao.Redis.ZCard(ctx, userCntKey).Result()

	if reqs >= limit {
		ctx.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
			"status":  http.StatusTooManyRequests,
			"message": "too many request",
		})
		return
	}

	ctx.Next()
	d.Dao.Redis.ZAddNX(ctx, userCntKey, &redis.Z{Score: float64(now), Member: float64(now)})
	d.Dao.Redis.Expire(ctx, userCntKey, dura)
}
```

# gin 框架
1. 使用Http 服务
```go
func main() {  
	  router := gin.Default()    //路由   
	  router.GET("/", func(c *gin.Context) {        c.JSON(200, gin.H{            "message": "hello gin",        })    })    router.Run(":8080")}文件上传router.POST("/upload", upload)func upload(c *gin.Context) {    file, _ := c.FormFile("file") //表单的文件name="file"    //文件上传路径和文件名    c.SaveUploadedFile(file, "./upload/"+file.Filename)    c.String(http.StatusOK, fmt.Sprintf("'%s' uploaded!", file.Filename))}多文件上传router.POST("/multiupload", multiupload)func multiupload(c *gin.Context) {    // 文件上传大小限制 8 MB,在路由注册时设定    //router.MaxMultipartMemory = 8 << 20    formdata := c.Request.MultipartForm    files := formdata.File["file"] //表单的文件name="file"    for i, _ := range files {        file, err := files[i].Open()        defer file.Close()        if err != nil {            c.String(http.StatusBadRequest, fmt.Sprintf("get file err: %s", err.Error()))            return        }        //文件上传路径和文件名        out, err := os.Create("./upload/" + files[i].Filename)        defer out.Close()        if err != nil {            c.String(http.StatusBadRequest, fmt.Sprintf("upload err: %s", err.Error()))            return        }        _, err = io.Copy(out, file)        if err != nil {            c.String(http.StatusBadRequest, fmt.Sprintf("save file err: %s", err.Error()))            return        }        c.String(http.StatusOK, "upload successful")    }}重定向r.GET("/redirect", func(c *gin.Context) {    //支持内部和外部的重定向    c.Redirect(http.StatusMovedPermanently, "http://www.baidu.com/")    })中间件router := gin.Default()router.Use(middleware.IPLimit()) //使用自定义中间件：IP验证实现：package middlewareimport (    "core"    "github.com/gin-gonic/gin"    "net/http"    "strings")//访问ip限制func IPLimit() gin.HandlerFunc {    return func(c *gin.Context) {        ip := c.ClientIP()        ipList := strings.Split(core.Config["allow_ip"], "|")        flag := false        for i := 0; i < len(ipList); i++ {            if ip == ipList[i] {                flag = true                break            }        }        if !flag {            c.Abort()            c.JSON(http.StatusUnauthorized, gin.H{                "code": 0,                "msg":  "IP " + ip + " 没有访问权限",                "data": nil})            return             // return也是可以省略的，执行了abort操作，会内置在中间件defer前，return，写出来也只是解答为什么Abort()之后，还能执行返回JSON数据        }    }}日志gin.DisableConsoleColor()   //关掉控制台颜色,可省略f, _ := os.Create("gin.log")    //日志文件//gin.DefaultWriter = io.MultiWriter(f) //将日志写入文件gin.DefaultWriter = io.MultiWriter(f, os.Stdout) //将日志写入文件同时在控制台输出下载：go get github.com/sirupsen/logruspackage mainimport (    log "github.com/Sirupsen/logrus")func main() {    log.Trace("Something very low level.")    log.Debug("Useful debugging information.")    log.Info("Something noteworthy happened!")    log.Warn("You should probably take a look at this.")    log.Error("Something failed but I'm not quitting.")    // Calls os.Exit(1) after logging    log.Fatal("Bye.")    // Calls panic() after logging    log.Panic("I'm bailing.")}2.validator(参数校验)使用：只需要在定义结构体时使用binding或validate tag标识相关校验规则，就可以进行参数校验了，很方便例：package mainimport ("fmt""net/http""github.com/gin-gonic/gin")type RegisterRequest struct {    Username string `json:"username" binding:"required"`    Nickname string `json:"nickname" binding:"required"`    Email    string `json:"email" binding:"required,email"`    Password string `json:"password" binding:"required"`    Age      uint8  `json:"age" binding:"gte=1,lte=120"`}func main() {router := gin.Default()router.POST("register", Register)router.Run(":9999")}func Register(c *gin.Context) {    var r RegisterRequest    err := c.ShouldBindJSON(&r)    if err != nil {      fmt.Println("register failed")      c.JSON(http.StatusOK, gin.H{"msg": err.Error()})      return    }//验证 存储操作省略.....    fmt.Println("register success")    c.JSON(http.StatusOK, "successful")}校验类型：
	* required ：必填 //非0值
	* email：验证字符串是email格式；例：“email”
	* url：这将验证字符串值包含有效的网址;例：“url”
	* max：字符串最大长度；例：“max=20”
	* min:字符串最小长度；例：“min=6”
	* excludesall:不能包含特殊字符；例：“excludesall=0x2C”//注意这里用十六进制表示。
	* len：字符长度必须等于n，或者数组、切片、map的len值为n，即包含的项目数；例：“len=6”
	* eq：数字等于n，或者或者数组、切片、map的len值为n，即包含的项目数；例：“eq=6”
	* ne：数字不等于n，或者或者数组、切片、map的len值不等于为n，即包含的项目数不为n，其和eq相反；例：“ne=6”
	* gt：数字大于n，或者或者数组、切片、map的len值大于n，即包含的项目数大于n；例：“gt=6”
	* gte：数字大于或等于n，或者或者数组、切片、map的len值大于或等于n，即包含的项目数大于或等于n；例：“gte=6”
	* lt：数字小于n，或者或者数组、切片、map的len值小于n，即包含的项目数小于n；例：“lt=6”
	* lte：数字小于或等于n，或者或者数组、切片、map的len值小于或等于n，即包含的项目数小于或等于n；例：“lte=6”
	* field : 等于某个字段 （结构体的参数名称）// `json:aa rield:B(上面有个参数为B)`

 自定义校验例：package mainimport (    "fmt"    "net/http"    "time"    "github.com/gin-gonic/gin"    "github.com/gin-gonic/gin/binding"    "github.com/go-playground/validator/v10")type Info struct {    CreateTime time.Time `form:"create_time" binding:"required,timing" time_format:"2006-01-02"`    UpdateTime time.Time `form:"update_time" binding:"required,timing" time_format:"2006-01-02"`}// 自定义验证规则断言func timing(fl validator.FieldLevel) bool {    if date, ok := fl.Field().Interface().(time.Time); ok {      today := time.Now()      if today.After(date) {       return false      }    }    return true}func main() {    route := gin.Default()    // 注册验证    if v, ok := binding.Validator.Engine().(*validator.Validate); ok {      err := v.RegisterValidation("timing", timing)      if err != nil {       fmt.Println("success")      }    }    route.GET("/time", getTime)    route.Run(":8080")}func getTime(c *gin.Context) {    var b Info    // 数据模型绑定查询字符串验证    if err := c.ShouldBindWith(&b, binding.Query); err == nil {      c.JSON(http.StatusOK, gin.H{"message": "time are valid!"})    } else {      c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})    }}


1.路由（engine）
gin.default()    默认生成一个engine对象，包含 logger（日志）和Recovery（错误响应）
2.路由树
如何获得请求路由方法，通过路由树。树中的节点按照url中的/来进行层级划分

//Engine 对象包含一个 addRoute 方法用于添加 URL 请求处理器，它会将对应的路径和处理器挂接到相应的请求树中
func (e *Engine) addRoute(method, path string, handlers HandlersChain)

Gin 不支持 HTTPS，官方建议是使用 Nginx 来转发 HTTPS 请求到 Gin。

自定义中间件
我们已经知道，Gin的中间件其实就是一个HandlerFunc,那么只要我们自己实现一个HandlerFunc，就可以自定义一个自己的中间件。现在我们以统计每次请求的执行时间为例，来演示如何自定义一个中间件。


func costTime() gin.HandlerFunc {
    return func(c *gin.Context) {
        //请求前获取当前时间
        nowTime := time.Now()
        //请求处理
        c.Next()
        //处理后获取消耗时间
        costTime := time.Since(nowTime)
        url := c.Request.URL.String()
        fmt.Printf("the request URL %s cost %v\n", url, costTime)
    }
}


func main() {
    r := gin.New()
    r.Use(costTime())

    r.GET("/", func(c *gin.Context) {
        c.JSON(200, "首页")
    })

    r.Run(":8080")
}
gin 中间件剥洋葱形式，将会先执行cont1的方法，并运行到next()方法结束。在执行cont2()方法，在到next。当中间件不存在Use情况，则从cont2继续执行，在执行cont1

r := gin.New()
r.Use(cont1())
r.Use(cont2())
func cont1(func(c *context)){
return func(c *context){
        fmt.Println(“----1----”)
        c.next()
        fmt.println(“-----end1----”)
    }
}
func cont2(func(c *context)){
return func(c *context){
        fmt.Println(“----2----”)
        c.next()
        fmt.println(“-----end2----”)
    }
}
结果应为：1,   2，end2，end1
c.abort() 将不会执行后续的中间件 c.AbortWithStatusJson(400,gin.H{"error":err})//将会退出gin。





责任链模式
顾名思义，责任链模式就是为请求创建一个对象链，对象链上的每个对象都可以依次对请求进行处理，并把处理过的请求传递给下一个对象。

type Context struct {
    // ...


    // handlers 是一个包含执行函数的数组
    // type HandlersChain []HandlerFunc
       handlers HandlersChain
    // index 表示当前执行到哪个位置了
    index    int8


    // ...
}


// Next 会按照顺序将一个个中间件执行完毕
// 并且 Next 也可以在中间件中进行调用，达到请求前以及请求后的处理
// Next should be used only inside middleware.
// It executes the pending handlers in the chain inside the calling handler.
// See example in GitHub.
func (c *Context) Next() {
       c.index++
   for c.index < int8(len(c.handlers)) {
           c.handlers[c.index](c)
              c.index++
   }
}

首先，在 gin.Engine 中，使用对象池 sync.Pool 来存放 gin.Context 这样做的目的是为 Go GC 减少压力。
然后，在 Gin 内部，当路由匹配成功后，将调用 context.Next() 方法，开始进入 Gin 中间件和处理函数的执行操作，并且，需要注意的是，在日常开发中，该方法，只能在中间件中被调用。
最后，以使用 gin.Default() 方法创建 gin.Engine 时携带的两个默认中间件 Logger() 和 Recovery()，和我们自己编写的一个模拟身份校验的中间件 Auth()，结合注册的 path 为 /action 的路由，对 Gin 中间件和处理函数的工作流程进行了讲解。
链接：https://juejin.cn/post/6844904087318691847

Gin Context

// ServeHTTP conforms to the http.Handler interface.
// 符合 http.Handler 接口的约定
func (engine *Engine) ServeHTTP(w http.ResponseWriter, req *http.Request) {
    // 从对象池中获取已存在的上下文对象
    c := engine.pool.Get().(*Context)
    // 重置该上下文对象的 ResponseWriter 属性
    c.writermem.reset(w)
    // 设置该上下文对象的 Request 属性
    c.Request = req
    // 重置上下文中的其他属性信息
    c.reset()


    // 对请求进行处理
    engine.handleHTTPRequest(c)


    // 将该上下文对象重新放回对象池中
    engine.pool.Put(c)
}


// Context is the most important part of gin. It allows us to pass variables between middleware,
// manage the flow, validate the JSON of a request and render a JSON response for example.
// 上下文是 Gin 最重要的部分.
// 它允许我们在中间件之间传递变量, 管理流程, 例如验证请求的 JSON 并呈现 JSON 响应.
type Context struct {
    // 对 net/http 库中的 ResponseWriter 进行了封装
    writermem responseWriter
    // 请求对象
    Request   *http.Request
    // 非 net/http 库中的 ResponseWriter
    // 而是 Gin 用来构建 HTTP 响应的一个接口
    Writer    ResponseWriter


    // 存放请求中的 URI 参数
    Params   Params
    // 存放该请求的处理函数切片, 包括中间件加最终处理函数
    handlers HandlersChain
    // 用于标记当前执行的处理函数
    index    int8
    // 请求的完整路径
    fullPath string


    // Gin 引擎对象
    engine *Engine


    // Keys is a key/value pair exclusively for the context of each request.
    // 用于上下文之间的变量传递
    Keys map[string]interface{}


    // Errors is a list of errors attached to all the handlers/middlewares who used this context.
    // 与处理函数/中间件对应的错误列表
    Errors errorMsgs


    // Accepted defines a list of manually accepted formats for content negotiation.
    // 接受格式列表
    Accepted []string


    // queryCache use url.ParseQuery cached the param query result from c.Request.URL.Query()
    // 用于缓存请求的 URL 参数
    queryCache url.Values


    // formCache use url.ParseQuery cached PostForm contains the parsed form data from POST, PATCH,
    // or PUT body parameters.
    // 用于缓存请求体中的参数
    formCache url.Values
}

用户模块
gin 采用中间件的形式可以做到用户权限模块，在调用接口前，做Gin.HandlerFunc的方法校验

PrivateGroup.Use(middleware.JWTAuth()).Use(middleware.CasbinHandler())

// 拦截器
func CasbinHandler() gin.HandlerFunc {
   return func(c *gin.Context) {
      claims, _ := c.Get("claims")
      waitUse := claims.(*request.CustomClaims)
      // 获取请求的URI
      obj := c.Request.URL.RequestURI()
      // 获取请求方法
      act := c.Request.Method
      // 获取用户的角色
      sub := waitUse.AuthorityId
      e := service.Casbin()
      // 判断策略中是否存在
      success, _ := e.Enforce(sub, obj, act)
      if comm.Config.System.Env == "develop" || success {
         c.Next()
      } else {
         response.FailWithDetailed(gin.H{}, "权限不足", c)
         c.Abort()
         return
      }
   }
}



