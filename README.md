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

hugo  -D 生产public 文件，以便于发布


//bind外端口

启动命令 : hugo server -b "http://ip:8080" -p 8080 --bind "0.0.0.0"  -e production

注意 : 当端口占用，随机生成

主题下载

LoveIt:  https://github.com/dillonzq/LoveIt

hugo-theme-crisp:   https://github.com/Zenithar/hugo-theme-crisp

hugo-PaperMod:  https://github.com/adityatelange/hugo-PaperMod


生成文件:
```hugo -d docs```

新建:
hugo new posts/hello.md


标签添加:
``` https://orianna-zzo.github.io/sci-tech/2018-01/blog%E5%85%BB%E6%88%90%E8%AE%B04-hugo%E4%B8%AD%E5%A2%9E%E5%8A%A0tags%E7%AD%89%E5%88%86%E7%B1%BB/```



![](https://raw.githubusercontent.com/yzj0911/my_logs/main/content/images/备忘录模式.jpeg)

tags: ["面试"]
series: [""]
categories: ["面试"]