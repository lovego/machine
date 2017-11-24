# <a href="http://github.com/lovego/xiaomei">xiaomei</a>开发、生产环境安装
machine提供了一个基于Ubuntu的VirtualBox开发机，导入该虚拟机，就可以立即上手开发。
同时提供了一个基于Ubuntu的开发、生产环境一键安装脚本。

VirtualBox虚拟机和安装脚本内容：
1. 首先，为了让生活更美好，对sudo、vim、screen进行了配置。
2. 其次，安装Docker、Nginx这两个必需组件。
3. 如果是开发环境，则安装git、go、xiaomei。
4. 安装redis、mysql、mongo客户端。
5. 可选的安装redis、mysql、mongo服务器（默认都不安装）。

## VirtualBox开发机
基于Ubuntu Server 16.04.3，使用一键安装脚本，生成了一个现成的开发环境虚拟机。
从百度网盘下载虚拟机镜像 <a target="_blank" href="https://pan.baidu.com/s/1nv9mEFZ">develop-machine.ova</a>， 然后使用VirtualBox导入。

#### SSH登录
推荐使用无界面方式启动虚拟机，然后使用自己喜欢的终端登录，如Putty、SecureCRT、XShell等。
```
  IP：    192.168.56.15
  用户名：ubuntu
  密码：  go
```
重要的事情说三遍：不要使用虚拟机自带的窗口界面来操作，这个界面分辨率太低，字体太难看，无法显示非英文字符，无法支持拷贝粘贴。使用你喜欢的终端连接虚拟机操作，生活会更美好。

#### 共享文件夹

默认共享了D盘，挂载到虚拟机的/mnt/share目录。如果没有D盘（如Mac用户），将会共享失败，请自行设置共享文件夹。设置步骤如下：
1. 在虚拟机设置界面，设置好共享文件夹，并记住名称。
2. 在虚拟机内将/etc/fstab的最后一行中D_DRIVE替换为共享文件夹的名字。
3. 在虚拟机内执行sudo mount /mnt/share或重启虚拟机来挂载设置的共享文件夹。

#### 重启网络
Host更换网络环境后（比如从办公室回到家里），虚拟机如果是在更换网络环境之前启动的，需要执行以下命令重启一下网络。
```
sudo service networking restart
```


## 一键安装脚本
如果你不想使用上面现成的虚拟机，可以直接使用一键安装脚本，来安装环境。 目前该脚本仅针对Ubuntu Server 16.04进行了测试。使用方式：

```
curl -s https://raw.githubusercontent.com/lovego/machine/master/setup.sh | bash -s [-- options...]
```
选项列表：
1. --production，表示安装的是生产环境，此时不会安装只有开发环境才需要的组件。
2. --redis-server，表示需要安装redis服务器
3. --mysql-server，表示需要安装mysql服务器
4. --mongo-server，表示需要安装mongo服务器


## 自定义设置

#### 1. 设置Doker的非https的镜像仓库（Registry）、镜像加速
例如，需要把 "192.168.202.12:5000" 设置为http镜像仓库，并且使用 "http://hub-mirror.c.163.com/" 进行镜像加速，执行如下命令：
```
echo '{
  "insecure-registries": [ "192.168.202.12:5000" ],
  "registry-mirrors": [ "http://hub-mirror.c.163.com/" ]
}' | sudo tee /etc/docker/daemon.json > /dev/null
sudo service docker restart
```

