#!/bin/bash

set -ex

main() {
  while test $# -gt 0; do
    case "$1" in
      --redis-server)
        local redis_server=true
        shift ;;
      --mysql-server)
        local mysql_server=true
        shift ;;
      --mongo-server)
        local mongo_server=true
        shift ;;
      *)
        echo unknow option: "$1"
        exit 1 ;;
    esac
  done

  # first of all, make life better.
  setup_sudo_no_password
  setup_vim
  setup_screen

  # 通过检测vboxsf内核模块，判断是否是VirtualBox虚拟机
  if modinfo vboxsf >/dev/null 2>&1; then
    setup_vbox_hostonly_network
    setup_vbox_share_folder
  fi

  # required core components
  test -e /usr/local/go    || install_golang
  which docker >/dev/null  || install_docker
  which nginx  >/dev/null  || apt_install nginx-core
  which git    >/dev/null  || apt_install git
  test -e ~/go/bin/xiaomei || install_xiaomei

  # database clients
  which redis-cli >/dev/null || apt_install redis-tools
  which mysql     >/dev/null || apt_install mysql-client
  which mongo     >/dev/null || { add_mongo3_source; apt_install mongodb-org-shell; }

  # database servers
  test -z "$redis_server" || which redis-server >/dev/null || apt_install redis-server
  test -z "$mysql_server" || which mysqld       >/dev/null || install_mysql_server
  test -z "$mongo_server" || which mongod       >/dev/null || {
    add_mongo3_source
    apt_install mongodb-org-server
  }
}

setup_sudo_no_password() {
  username=$(id -nu)
  local file="/etc/sudoers.d/$username"
  test -f "$file" || echo "$username  ALL=NOPASSWD: ALL" | sudo tee "$file" > /dev/null
}

setup_vim() {
  test -z $EDITOR && { echo -e "\nexport EDITOR=vim" >> ~/.profile; }
  test -f ~/.vimrc && return
  which git >/dev/null || apt_install git
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  wget -O ~/.vimrc https://raw.githubusercontent.com/lovego/machine/master/vimrc
  vim +PluginInstall +qall
}

setup_screen() {
  test -f ~/.screenrc && return
  echo '
startup_message off
bell off
vbell off
caption always "%w"
' > ~/.screenrc
}

setup_vbox_hostonly_network() {
  test -e /sys/class/net/enp0s8 || return
  file=/etc/network/interfaces.d/host-only
  test -f $file && return
  echo '
auto enp0s8
iface enp0s8 inet static
address 192.168.56.15
netmask 255.255.255.0
' | sudo tee $file > /dev/null
  sudo ifdown enp0s8
  sudo ifup enp0s8
}

setup_vbox_share_folder() {
  which mount.vboxsf >/dev/null && return

  # install guest additions
  apt_install gcc make # prepare to build external kernel modules
  sudo mount -t auto /dev/cdrom /media/cdrom # 挂载iso
  sudo /media/cdrom/VBoxLinuxAdditions.run || true

  # 验证vboxsf文件系统。
  which mount.vboxsf >/dev/null || { echo "setup share folder failed."; exit 1; }

  # 支持自动挂载，将当前用户添加到vboxsf用户组
  sudo usermod -aG vboxsf $(id -nu)

  # 自定义挂载
  if ! fgrep /mnt/share /etc/fstab > /dev/null; then
    sudo mkdir /mnt/share && sudo chown ubuntu /mnt/share
    echo 'D_DRIVE /mnt/share vboxsf rw,gid=1000,uid=1000,dmode=755,fmode=644,auto,_netdev 0 0' |
    sudo tee --append /etc/fstab > /dev/null
  fi
}

install_golang() {
  # 原始地址： https://storage.googleapis.com/golang/go1.8.5.linux-amd64.tar.gz
  # 百度网盘：https://pan.baidu.com/s/1eSpidSQ
  url='http://oz5oikrwg.bkt.clouddn.com/go1.8.5.linux-amd64.tar.gz' # 七牛云存储
  wget -T 10 -cO /tmp/go.tar.gz "$url"
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  echo '
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
export GOPATH=$HOME/go
' >> ~/.profile
}

install_docker() {
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo apt-key fingerprint 0EBFCD88 # Verify fingerprint
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

  sudo apt-get update
  sudo apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual docker-ce
  sudo usermod -aG docker $(id -nu)
}

install_xiaomei() {
  /usr/local/go/bin/go get -d -v github.com/lovego/xiaomei/...
  /usr/local/go/bin/go install github.com/lovego/xiaomei/xiaomei

  # pull bases images
  docker pull hub.c.163.com/lovego/xiaomei/appserver
  docker pull hub.c.163.com/lovego/xiaomei/tasks
  docker pull hub.c.163.com/lovego/xiaomei/nginx
  docker pull hub.c.163.com/lovego/xiaomei/logc
  docker pull hub.c.163.com/lovego/xiaomei/godoc

  ~/go/bin/xiaomei auto-complete
  ~/go/bin/xiaomei workspace-godoc
  ~/go/bin/xiaomei workspace-godoc access -s
}

apt_install() {
  # 超过10天没更新源
  if test -n "`find /var/lib/apt/periodic/update-success-stamp -mtime +9`"; then
    sudo apt-get update --fix-missing
  fi
  sudo apt-get install -y "$@"
}

install_mysql_server() {
  sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password root"
  sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password root"
  apt_install mysql-server
}

add_mongo3_source() {
  file=/etc/apt/sources.list.d/mongodb-org-3.4.list
  test -e $file && return
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv \
    0C49F3730359A14518585931BC711F9BA15703C6
  echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" |
  sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  sudo apt-get update
}

main

