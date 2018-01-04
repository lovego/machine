### 设置初始虚拟机
1. 使用VirtualBox安装ubuntu-16.04-initial
2. 设置NAT网卡22端口转发
3. 添加Host-only网卡
4. 挂载VBoxGuestAdditions.iso镜像
5. 设置共享文件夹（共享名share，不自动挂载）

### 生成开发机
1. 复制ubuntu-16.04-initial，使用终端登录
2. 运行该脚本: `curl -s https://raw.githubusercontent.com/lovego/machine/master/setup.sh | bash -s`
3. 删除NAT网卡22端口转发，重启
4. 使用Host-only IP（192.168.56.15）登录
5. 验证共享目录: `ll /mnt/share`

