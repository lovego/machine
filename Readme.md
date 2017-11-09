# <a href="http://github.com/lovego/xiaomei">xiaomei</a>开发机（VirtualBox虚拟机）

从百度网盘下载虚拟机镜像
<a target="_blank" href="https://pan.baidu.com/s/1bUXuEi">develop-machine.ova</a>，
然后使用VirtualBox导入。

### SSH登录
推荐使用无界面方式启动虚拟机，然后使用自己喜欢的终端登录，如Putty、SecureCRT、XShell等。
```
  IP：    192.168.56.15
  用户名：ubuntu
  密码：  go
```
重要的事情说三遍：不要使用虚拟机自带的窗口界面来操作，这个界面分辨率太低，字体太难看，无法显示非英文字符，无法支持拷贝粘贴。使用你喜欢的终端连接虚拟机操作，生活会更美好。

### 共享文件夹

默认共享了D盘，映射到虚拟机的/media/sf_D_DRIVE目录。<br/>
如果没有D盘（如Mac用户），将会共享失败，请自行设置共享文件夹。

### 已安装的软件环境
1. Ubuntu Server 16.04.3
2. Golang 1.8.5 （GOPATH: /home/ubuntu/go）
3. Docker CE 17.09
4. Nginx 1.10.3
5. Git 2.7.4
6. Redis Cli 3.0.6
7. Mysql Client 5.7
8. Mongo Shell 3.4


### 其他常用设置

#### 1. 设置Doker的非https的镜像仓库（Registry）、镜像加速
例如，需要把 "192.168.202.12:5000" 设置为http镜像仓库，并且使用 "http://hub-mirror.c.163.com/" 进行镜像加速，执行如下命令：
```
echo '{
  "insecure-registries": [ "192.168.202.12:5000" ],
  "registry-mirrors": [ "http://hub-mirror.c.163.com/" ]
}' | sudo tee /etc/docker/daemon.json > /dev/null
sudo service docker restart
```

#### 2. 重启网卡
Host待机后或者更换网络环境（比如从办公室回到家里），虚拟机的网络就无法正确连接了。
```
sudo ifdown enp0s3; sudo ifup enp0s3;
```
执行这两条命令重启一下网卡就可以了。

