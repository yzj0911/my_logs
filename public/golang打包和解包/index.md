# 

# golang打包和解包



# golang打包和解包


# 打包

```golang
// 打包
func Compress(destPath, srcDir string) error {
	// 压缩文件路径
	fw, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer fw.Close()

	// gzip writer
	gw := gzip.NewWriter(fw)
	defer gw.Close()

	// tar writer
	tw := tar.NewWriter(gw)
	defer tw.Close()

	// 读取要压缩的目录
	dir, err := os.Open(srcDir)
	if err != nil {
		return err
	}
	defer dir.Close()

	// 读取目录内容
	files, err := dir.Readdir(0)
	if err != nil {
		return err
	}

	for _, file := range files {
		if file.IsDir() {
			continue
		}

		// 路径补全
		filePath := path.Join(dir.Name(), file.Name())

		fread, err := os.Open(filePath)
		if err != nil {
			continue
		}

		// 获取文件头部信息
		h := &tar.Header{}
		h.Name = file.Name()
		h.Size = file.Size()
		h.Mode = int64(file.Mode())
		h.ModTime = file.ModTime()

		err = tw.WriteHeader(h)
		if err == nil {
			// 开始压缩，这里等于忽略错误
			io.Copy(tw, fread)
		}
		// 记得关闭文件
		fread.Close()
	}

	return nil
}
```

# 解包
```golang
// 解压
func DeCompress(srcPath, destDir string) error {
	// 解压包的路径
	fread, err := os.Open(srcPath)
	if err != nil {
		return err
	}
	defer fread.Close()

	// 检测目标路径是否存在
	_, err = os.Stat(destDir)
	if err != nil {
		return err
	}

	// gzip reader
	gr, err := gzip.NewReader(fread)
	if err != nil {
		return err
	}
	defer gr.Close()

	// tr reader
	tr := tar.NewReader(gr)

	for {
		// 获取下一个文件
		h, err := tr.Next()

		// 读取完毕
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		fw, err := os.OpenFile(path.Join(destDir, h.Name), os.O_CREATE|os.O_WRONLY, 0644)
		if err == nil {
			io.Copy(fw, tr)
			fw.Close()
		}
	}
	return nil
}
```


