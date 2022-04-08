# Windows Bat总结


# Windows Bat总结


最近项目需要再 windows 上做开发，而且一些自动化的处理需要使用 windows 的的脚本。所以做些记录，防止遗忘。

# 基本的语法
首先从基础开始吧，之前都是使用 linux bash 的。可以说 windows bat 脚本和 linux bash 脚本还是有很多区别的。

## 设置变量
变量设置使用的命令为`set`。
```bash
set a="hello world"
echo %a%
```
从上面的脚本中可以知道，使用`set`来设置变量，语法为`set var=<值>`。如果要引用这个变量的话就使用`%var%`。
> 注：bat 脚本不能像 bash 中一样设置临时变量，只用将变量设置为环境变量。

`set`命令的功能还是比较强大的，比如获取从键盘中输入的字符：
```bash
set /p a="Input a number:"

echo %a%
```
支持算术：
```bash
set /a a=1+2
echo %a%
set /a a-=1
echo %a%
set /a a*=3
echo %a%
set /a a/=3
echo %a%
```
这个关键在于`set /a`
还有字符串的修改和截取：
```bash
:::::::::: 字符串的截取 ::::::::::
set a=Hello Windows Bat
:: 截取所有
set a=%a:~0%
:: 截取指定的
set a=%a:~1,-1%
set a=%a:~2,4%


:::::::::: 字符串的替换 ::::::::::
set a=Hello Windows

:: 将Windows替换成Linux
set a=%a:Windows=Linux%
```
## 注释
bat 中能实现注释功能的有两个`::`和`rem`。
它们的不同点是：`rem`是一条命令，在运行的时候相当于把rem本身及其后面的内容置空。既然它是一条命令，就必须处于单独的一行或者有类似 "&" 的连接符号连接。
bat 遇到以冒号 ":" 开头的行时（忽略冒号前的空格），会将其后的语句识别为“标记”而不是命令语句，因此类似 ":label" 这样的在 bat 中仅仅是一个标记。
> 注: 使用 bat 中的注释时需要注意一点，不要再 () 的边上使用注释。

## 条件判断
bat 中的条件判断也是使用`if`。
```bash
set a=1

if %a%==1 (
    echo OK
) else (
    echo ERROR
)
```
如果时判断字符串使用为空时,可以这样处理:
```bash
set a="hello"

if (%a%)==() (
    echo OK
) else (
    echo ERROR
)
```
## 循环语句
bat 中的循环有些不同。关键字也是`for`。还是先来看一个例子：
```bash
for /f "delims=: tokens=1,2,3" %%i in ( "2018:04:11" ) do (
    echo %%i
    echo %%j
)
```
这段脚本中需要注意的点是：`delims=:`表示使用 ":" 来分割字符串，而`tokens=1,2,3`则表示取出分割后的字符串的部分，从1开始。`%%i`是循环中的每个项。输出时`%%i`和`%%j`分别对应的就是截取的字段1和2。如果还需要输出第三个，也是使用`%%k`表示，依次类推。

但 bat 中的`for`会存在延迟赋值的情况，先来看一段脚本:
```bash
for /f "delims=: tokens=2" %%i in ( 'ipconfig /all ^| findstr /i "ipv4" ' ) do (
    echo %%i
    set a=%%i
    echo %a%
)
```
输出结果:
```
IPv4 地址 . . . . . . . . . . . . : 192.168.168.1(首选)
IPv4 地址 . . . . . . . . . . . . : 192.168.2.160(首选
IPv4 地址 . . . . . . . . . . . . : 192.168.157.1(首选)
IPv4 地址 . . . . . . . . . . . . : 192.168.2.160(首选
IPv4 地址 . . . . . . . . . . . . : 192.168.2.160(首选)
IPv4 地址 . . . . . . . . . . . . : 192.168.2.160(首选
```
`%a%`的值一直等于最后一项。
## 函数
bat 中函数是使用`:label`方式定义的，使用`call`来调用:
```bash
call :test Hello World

goto EXIT

:test
    echo %1 %2

:EXIT
```
脚本中的`goto`用来跳转退出，而且函数要放在脚本的尾部，存在多个函数时还需要使用`goto`直接跳转，因为脚本是会按顺序执行下去的。

# 实战操作
```bash
@echo off

set option=%1
set address=%2

if (%option%) == () (
    echo "Usage: connectIscsi.bat <start|stop> <address>"
    goto EXIT
)

if (%address%) == () (
    echo "Usage: connectIscsi.bat <start|stop> <address>"
    goto EXIT
)

if %option% == start (
    call :start %address%
) else if %option% == stop (
    call :stop %address%
) else (
    echo "Usage: connectIscsi.bat <start|stop> <address>"
    goto EXIT
)

::sc config msiscsi start=auto
::net start msiscsi

goto EXIT

:: 连接iscsi服务器
:start
    iscsicli QAddTargetPortal %1
    for /f "delims= tokens=1" %%i in ( 'iscsicli ListTargets t ^| findstr /i "iqn.2018-11" ' ) do (
        iscsicli qlogintarget %%i
    )
    goto EXIT

:: 断开iscsi服务器
:stop
	set a=
    for /f "delims=: tokens=2" %%i in ('iscsicli SessionList ^| findstr /i "fffffa8"') do (
        set a=%%i
		goto return
    )
	:return
	set a=%a: =0x%
	set a=%a:-=-0x%
	iscsicli LogoutTarget %a%
    iscsicli RemoveTargetPortal %1 3260
    goto EXIT

:EXIT
```
这个脚本是用来连接和断开iscsi服务器的。脚本有两个入参，option 和 address。连接和断开iscsi服务器。脚本的思路很简单，开始判断输入参数是否正确。然后根据 option 选择执行对应的函数。特别在`:stop`中，因为延时复制的关系，所以循环体中只放简单的复制，处理部分在外面进行处理。  
# 后记
## 延时赋值问题
bat 的延时赋值有对应的解决方法：
```bash
SETLOCAL ENABLEDELAYEDEXPANSION

set a=hello
set a=!a!
set a=!a:~1!
```


