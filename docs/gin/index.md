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

