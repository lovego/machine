#!/bin/bash

# 设置初始虚拟机
# 1. 使用VirtualBox安装ubuntu-16.04-initial
# 2. 设置NAT网卡22端口转发
# 3. 添加Host-only网卡
# 4. 挂载VBoxGuestAdditions.iso镜像。
# 5. 设置共享文件夹（D盘自动挂载）

# 生成新虚拟机
# 1. 复制ubuntu-16.04-initial，使用终端登录
# 2. 运行该脚本: `curl -s https://raw.githubusercontent.com/lovego/machine/master/vbox_setup.sh | bash -s`
# 3. 删除NAT网卡22端口转发，重启
# 4. 使用Host-only IP（192.168.56.15）登录
# 5. 验证共享目录: `ls /media/sf_D_DRIVE`

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
  sudo /media/cdrom/VBoxLinuxAdditions.run || true
  rcvboxadd status  # check if has problems

  # 依赖vbox自动挂载，将当前用户添加到vboxsf用户组
  sudo usermod -aG vboxsf $(id -nu)

  # 如果需要自定义挂载，追加如下配置到/etc/fstab
  # D_DRIVE /mnt/share vboxsf rw,gid=100,uid=1000,umask=022,auto,_netdev,nofail 0   0

  # 验证vboxsf文件系统类型正确，虽然报错，只要不是报vboxsf文件系统类型错误，就OK。
  output=$(sudo mount -t vboxsf D_DRIVE /mnt 2>&1)
  if test "$output" = '/sbin/mount.vboxsf: mounting failed with the error: No such device'; then
    echo 'setup share folder success.'
  else
    echo "setup share folder failed: $output"
  fi
}

main

