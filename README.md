# Mylog 

首选需要安装hugo,再安装主题。接着就可以写md了

来自地址:https://blog.csdn.net/weixin_40557160/article/details/116041939

总体流程:

1.  安装hugo
2. 下载模板
3. clone你的io库
4. 把模板整个复制粘贴过去。
5. github切换docs文件夹。
6. 新建你的博客。
7. 直接命令行输入 hugo -d docs。
8. 然后git push，也就是提交。
9. 打开giuhub.io网页查看。


//bind外端口

启动命令:hugo server -b "http://ip:8080" -p 8080 --bind "0.0.0.0"  -e production

新建:
hugo new posts/hello.md