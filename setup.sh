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
  which go     >/dev/null || install_golang
  which docker >/dev/null || install_docker
  which nginx  >/dev/null || apt_install nginx-core
  which git    >/dev/null || apt_install git

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
  test -z $EDITOR && { echo 'export EDITOR=vim' >> ~/.profile; }
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
  # https://storage.googleapis.com/golang/go1.8.5.linux-amd64.tar.gz
  # 百度网盘下载页面：https://pan.baidu.com/s/1eSpidSQ
  url='https://nj01ct01.baidupcs.com/file/0849be2c27d56de985f8fe48505519ad?bkt=p3-000087d03a64c9599a697ec386fb256ea5bb&fid=1645080762-250528-264707197517289&time=1510233980&sign=FDTAXGERLQBHSK-DCb740ccc5511e5e8fedcff06b081203-IGYTGKCAL2cnPWCFperNIiXzv7Q%3D&to=63&size=99077377&sta_dx=99077377&sta_cs=0&sta_ft=gz&sta_ct=0&sta_mt=0&fm2=MH,Yangquan,Anywhere,,sichuan,ct&newver=1&newfm=1&secfm=1&flow_ver=3&pkey=000087d03a64c9599a697ec386fb256ea5bb&sl=79364174&expires=8h&rt=sh&r=290903054&mlogid=7256878829166723571&vuk=1645080762&vbdid=1754556945&fin=go1.8.5.linux-amd64.tar.gz&fn=go1.8.5.linux-amd64.tar.gz&rtype=1&iv=0&dp-logid=7256878829166723571&dp-callid=0.1.1&hps=1&tsl=100&csl=100&csign=JLGvAFRj74g4Zpggs4fgn8%2FipQw%3D&so=0&ut=6&uter=4&serv=0&uc=62957963&ic=1575768269&ti=691b2597eaee71363546f79341fb9351646bbbc9c6fda23b&by=themis'
  wget -T 10 -cO /tmp/go.tar.gz "$url"
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  echo '
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
export GOPATH=$HOME/go
' >> ~/.profile
  go get -v github.com/lovego/xiaomei/...
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

