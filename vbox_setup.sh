#!/bin/bash

# 1. 使用VirtualBox安装ubuntu-16.04-initial
# 2. 添加Host-only网卡
# 3. 设置共享文件夹（D盘自动挂载），挂载VBoxGuestAdditions.iso镜像。
# 4. NAT网卡设置22端口转发

# 5. 复制ubuntu-16.04-initial，使用终端登录
# 6. 运行该脚本 curl -s https://raw.githubusercontent.com/lovego/machine/master/vbox_setup.sh | bash -s
# 7. 验证Host-only，删除端口转发，使用IP:192.168.56.15登录
# 8. 重启，验证共享目录

set -ex

main() {
  setup_sudo_no_password
  setup_vbox_hostonly_network
  setup_vbox_share_folder
}

setup_sudo_no_password() {
  username=$(id -nu)
  local file="/etc/sudoers.d/$username"
  test -f "$file"  || echo "$username  ALL=NOPASSWD: ALL" | sudo tee --append "$file" > /dev/null
}

setup_vbox_hostonly_network() {
  file=/etc/network/interfaces.d/host-only
  test -f $file && return
  # ls /sys/class/net
  echo '
auto enp0s8
iface enp0s8 inet static
address 192.168.56.15
netmask 255.255.255.0
' | sudo tee --append $file > /dev/null
  sudo ifdown enp0s8
  sudo ifup enp0s8
}

setup_vbox_share_folder() {
  # install guest additions
  sudo apt-get install -y gcc make perl  # prepare to build external kernel modules
  sudo mount -t auto /dev/cdrom /media/cdrom # 挂载iso
  sudo /media/cdrom/VBoxLinuxAdditions.run
  rcvboxadd status  # check if has problems

  # 依赖vbox自动挂载，将当前用户添加到vboxsf用户组
  sudo usermod -a -G vboxsf $(id -nu)

  # 如果需要自定义挂载，追加如下配置到/etc/fstab
  # D_DRIVE /mnt/share vboxsf rw,gid=100,uid=1000,umask=022,auto,_netdev,nofail 0   0
  sudo mount -t vboxsf D_DRIVE /mnt
}

main

