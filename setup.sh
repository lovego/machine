#!/bin/bash

set -ex

os=$(uname)

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --production ) local production=true; shift ;;
      *            ) echo unknow option: "$1"; exit 1 ;;
    esac
  done

  # first of all, make life better.
  setup_sudo_no_password
  setup_profile
  setup_screen
  which wget >/dev/null || install_pkg wget

  # deploy components
  if [ "$os" = "Linux" ]; then
    which docker >/dev/null || install_docker
    which nginx  >/dev/null || {
      install_nginx
      [ -z "$production" ] && setup_nginx_server
    }
  fi

  if [ "$production" = true ]; then
    setup_vim_production
  else
    which git >/dev/null || install_pkg git
    install_golang
    install_xiaomei
    setup_vim_development
    setup_virtualbox
  fi
}

setup_sudo_no_password() {
  username=$(id -nu)
  local file="/etc/sudoers.d/$username"
  [ -f "$file" ] || echo "$username  ALL=NOPASSWD: ALL" | sudo tee "$file" > /dev/null
}

setup_profile() {
  if [ -z $EDITOR -o -z $VISUAL ]; then
    echo "export EDITOR=vim VISUAL=vim" >> ~/.profile
    source ~/.profile
  fi

  if [ "$os" = Darwin ]; then
    if [ -z $CLICOLOR -o -z $LSCOLORS ]; then
      echo "export CLICOLOR=1 LSCOLORS=GxFxCxDxBxegedabagaced" >> ~/.profile
      source ~/.profile
    fi
    alias ll >/dev/null || echo 'alias ll="ls -l"' >> ~/.profile
    alias la >/dev/null || echo 'alias la="ls -a"' >> ~/.profile
    alias la >/dev/null || echo 'alias la="ls -a"' >> ~/.profile
    alias grep  >/dev/null || echo 'alias grep="grep --color"'   >> ~/.profile
    alias fgrep >/dev/null || echo 'alias fgrep="fgrep --color"' >> ~/.profile
    alias egrep >/dev/null || echo 'alias egrep="egrep --color"' >> ~/.profile
  fi
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

setup_vim_production() {
  test -f ~/.vimrc ||
    wget -O ~/.vimrc https://raw.githubusercontent.com/lovego/machine/master/vimrc_production
}

install_golang() {
  which go >/dev/null && return
  if [ "$os" = Darwin ]; then
    brew_install go
    echo 'export PATH=$PATH:$HOME/go/bin GOPATH=$HOME/go' >> ~/.profile
  else
    # 原始地址：https://storage.googleapis.com/golang/go1.8.5.linux-amd64.tar.gz
    # 百度网盘：https://pan.baidu.com/s/1eSpidSQ
    url='http://oz5oikrwg.bkt.clouddn.com/go1.8.5.linux-amd64.tar.gz' # 七牛云存储
    wget -T 10 -cO /tmp/go.tar.gz "$url"
    sudo tar -C /usr/local -zxf /tmp/go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin GOPATH=$HOME/go' >> ~/.profile
  fi
  source ~/.profile
}

install_xiaomei() {
  test -e ~/go/bin/xiaomei >/dev/null && return
  go get -d -v github.com/lovego/xiaomei/...
  go install github.com/lovego/xiaomei/xiaomei

  # pull bases images
  if [ $os = "Linux"]; then
    docker pull hub.c.163.com/lovego/xiaomei/appserver
    docker pull hub.c.163.com/lovego/xiaomei/tasks
    docker pull hub.c.163.com/lovego/xiaomei/nginx
    docker pull hub.c.163.com/lovego/xiaomei/logc
    docker pull hub.c.163.com/lovego/xiaomei/godoc

    ~/go/bin/xiaomei workspace-godoc
    ~/go/bin/xiaomei workspace-godoc access -s
  # else
    # godoc
  fi

  ~/go/bin/xiaomei auto-complete
}

setup_vim_development() {
  test -f ~/.vimrc && return
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  wget -O ~/.vimrc https://raw.githubusercontent.com/lovego/machine/master/vimrc

  # for :GoInstallBinaries
  git clone https://github.com/golang/tools ~/go/src/golang.org/x/tools
  go install golang.org/x/tools/cmd/guru golang.org/x/tools/cmd/goimports
  vim +PluginInstall +GoInstallBinaries +qall
}

setup_virtualbox() {
  # 通过检测vboxsf内核模块，判断是否是VirtualBox虚拟机
  if [ "$os" = Linux ] && modinfo vboxsf >/dev/null 2>&1; then
    setup_vbox_hostonly_network
    setup_vbox_share_folder
  fi
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
    sudo mkdir /mnt/share && sudo chown $(id -nu) /mnt/share
    echo 'share /mnt/share vboxsf rw,gid=1000,uid=1000,dmode=755,fmode=644,auto,_netdev 0 0' |
      sudo tee --append /etc/fstab > /dev/null
  fi
}

install_docker() {
  if [ $os = Darwin ]; then
    brew_cask_install docker
    # launchctl submit -l docker -- /Applications/Docker.app/Contents/MacOS/Docker
    # wget https://download.docker.com/mac/stable/Docker.dmg
    # sudo hdiutil attach Docker.dmg
    # sudo installer -package /Volumes/Docker/Docker.pkg -target /
    # sudo hdiutil detach /Volumes/Docker
  else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo apt-key fingerprint 0EBFCD88 # Verify fingerprint
    sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    sudo apt-get update
    sudo apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual docker-ce
    sudo usermod -aG docker $(id -nu)
  fi
}

install_nginx() {
  if [ $os = Darwin ]; then
    brew_install nginx
    sudo brew services start nginx
  else
    apt_install nginx-core
  fi
}

setup_nginx_server() {
  conf="server {
  listen 80 default_server;
  root $HOME;
  autoindex on;
}"
  if [ $os = Darwin ]; then
    echo "$conf" | sudo tee /usr/local/etc/nginx/servers/default > /dev/null
    sudo launchctl stop  homebrew.mxcl.nginx
    sudo launchctl start homebrew.mxcl.nginx
  else
    echo "$conf" | sudo tee /etc/nginx/sites-available/default > /dev/null
    sudo service nginx reload
  fi
}

install_haproxy() {
  sudo apt-get install software-properties-common
  sudo add-apt-repository ppa:vbernat/haproxy-1.8

  sudo apt-get update
  sudo apt-get install haproxy
}

install_haproxy_from_source() {
  sudo apt-get install -y libc6-dev-i386 libpcre3-dev # libssl-dev
  cwd=$(pwd)

  cd /tmp
  wget -c https://www.openssl.org/source/openssl-1.0.2n.tar.gz
  tar -zxf openssl.tar.gz
  cd openssl-1.0.2n && ./config && make && make test && sudo make install

  cd /tmp
  wget -c http://www.haproxy.org/download/1.8/src/haproxy-1.8.1.tar.gz
  tar -zxf haproxy-1.8.1.tar.gz
  cd haproxy-1.8.1
  make TARGET=linux2628 USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1 SSL_INC=/usr/local/ssl/include SSL_LIB=/usr/local/ssl/lib
  sudo make install

  cd $(cwd)
}

install_pkg() {
  if [ "$os" = Darwin ]; then
    brew_install "$@"
  else
    apt_install "$@"
  fi
}

apt_install() {
  # 超过10天没更新源
  if test -n "`find /var/lib/apt/periodic/update-success-stamp -mtime +9`"; then
    sudo apt-get update --fix-missing
  fi
  sudo apt-get install -y "$@"
}

brew_install() {
  which brew > /dev/null ||
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  HOMEBREW_NO_AUTO_UPDATE=1 brew install "$@"
}

brew_cask_install() {
  which brew > /dev/null ||
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  HOMEBREW_NO_AUTO_UPDATE=1 brew cask install "$@"
}


main

