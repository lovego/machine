#!/bin/bash

set -ex

main() {
  local production=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --production ) local production=true; shift ;;
      *            ) echo unknow option: "$1"; exit 1 ;;
    esac
  done

  get_profile

  os=$(uname)
  [ "$os" = "Darwin" ] && install_brew_pkgs

  # first of all, make life better.
  setup_sudo_no_password
  setup_profile
  setup_screen
  which wget >/dev/null || install_pkg wget

  # deploy components
  if [ "$os" = "Linux" ]; then
    install_docker
    which nginx >/dev/null || sudo lsof -i:80 >/dev/null || { # lsof -nP -i4tcp:9200 -stcp:listen
      install_nginx
      $production || setup_nginx_server
    }
  fi

  # developing environment
  if $production; then
    setup_vim_production
  else
    install_git
    install_golang
    install_xiaomei
    setup_vim_development
    [ "$os" = Linux ] && setup_virtualbox
  fi
}

get_profile() {
  if test -e ~/.bash_profile; then
    profile=~/.bash_profile
  elif test -e  ~/.bash_login; then
    profile=~/.bash_login
  else
    profile=~/.profile
  fi
}

install_brew_pkgs() {
  which brew > /dev/null || /usr/bin/ruby -e \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  if ! which gls > /dev/null; then
    brew install coreutils
    echo 'PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"' >> $profile
    echo 'MANPATH="/usr/local/opt/coreutils/libexec/gnuman:$MANPATH"' >> $profile
  fi
  if ! which gsed > /dev/null; then
    brew install gnu-sed
    echo 'PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"' >> $profile
    echo 'MANPATH="/usr/local/opt/gnu-sed/libexec/gnuman:$MANPATH"' >> $profile
  fi
  if ! test -f /usr/local/etc/bash_completion; then
    brew install bash-completion
    echo '[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion' >> $profile
  fi
}

setup_sudo_no_password() {
  username=$(id -nu)
  local file="/etc/sudoers.d/$username"
  [ -f "$file" ] || echo "$username  ALL=NOPASSWD: ALL" | sudo tee "$file" > /dev/null
}

setup_profile() {
  if [ "$os" = Darwin ]; then
    test -e $profile || echo -e "shopt -s extglob\nexport PS1='\h:\w\$ '" >> $profile

    if [ -z $CLICOLOR -o -z $LSCOLORS ]; then
      echo "export CLICOLOR=1 LSCOLORS=GxFxCxDxBxegedabagaced" >> $profile
    fi
  fi

  test -f ~/.bashrc && source ~/.bashrc # make alias work
  if ! alias ll la >/dev/null; then
    echo 'alias ll="ls -l" la="ls -a"' >> ~/.bashrc
  fi
  if ! alias grep fgrep egrep >/dev/null; then
    echo 'alias grep="grep --color" fgrep="fgrep --color" egrep="egrep --color"' >> ~/.bashrc
  fi

  if [ -z $EDITOR -o -z $VISUAL ]; then
    echo "export EDITOR=vim VISUAL=vim" >> $profile
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

install_git() {
  if [ "$os" = Darwin ]; then
    # git installed by brew has bash completion, so install it by brew.
    brew ls --versions git >/dev/null && return
  else
    which git >/dev/null && return
  fi
  install_pkg git
  sudo git config --system color.ui true # for git < 1.8.4
}

install_golang() {
  which go >/dev/null && return
  if [ "$os" = Darwin ]; then
    brew_install go@1.10
    echo 'export PATH=$PATH:$HOME/go/bin GOPATH=$HOME/go' >> $profile
  else
    wget -T 10 -cO /tmp/go.tar.gz https://dl.google.com/go/go1.9.3.linux-amd64.tar.gz
    sudo tar -C /usr/local -zxf /tmp/go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin GOPATH=$HOME/go' >> $profile
  fi
  source $profile
}

install_xiaomei() {
  test -e ~/go/bin/xiaomei >/dev/null && return
  go get -d -v github.com/lovego/xiaomei/...
  go install github.com/lovego/xiaomei

  if [ "$os" = "Linux" ]; then
    # pull bases images
    docker pull hub.c.163.com/lovego/xiaomei/appserver
    docker pull hub.c.163.com/lovego/xiaomei/nginx
    docker pull hub.c.163.com/lovego/xiaomei/logc
    docker pull hub.c.163.com/lovego/xiaomei/godoc

    ~/go/bin/xiaomei godoc deploy
    ~/go/bin/xiaomei godoc access setup
  else
    ~/go/bin/xiaomei godoc run
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
  if modinfo vboxsf >/dev/null 2>&1; then
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
    echo 'share /mnt/share vboxsf rw,gid=1000,uid=1000,auto,_netdev 0 0 # dmode=755,fmode=644,' |
      sudo tee --append /etc/fstab > /dev/null
  fi
}

install_docker() {
  which docker >/dev/null && return
  if [ $os = Darwin ]; then
    brew_cask_install docker
  elif which apt-get >/dev/null 2>&1; then
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo apt-key fingerprint 0EBFCD88 # Verify fingerprint
    sudo add-apt-repository -y \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    sudo apt-get update
    sudo apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual docker-ce=17.09.1
    sudo systemctl enable --now docker
    sudo usermod -aG docker $(id -nu)
  else
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce-17.09.1.ce
    sudo systemctl enable --now docker
    sudo usermod -aG docker $(id -nu)
  fi
}

install_nginx() {
  if [ $os = Darwin ]; then
    brew_install nginx
    sudo brew services start nginx
  elif which apt-get >/dev/null 2>&1; then
    apt_install nginx-core
    sudo systemctl enable --now nginx
  else
    yum_install epel-release
    yum_install nginx
    sudo systemctl enable --now nginx
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
    sudo brew services restart nginx
  else
    echo "$conf" | sudo tee /etc/nginx/sites-available/default > /dev/null
    sudo systemctl reload nginx
  fi
}

install_haproxy() {
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository -y ppa:vbernat/haproxy-1.8

  sudo apt-get update
  sudo apt-get install -y haproxy
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
  elif which apt-get >/dev/null 2>&1; then
    apt_install "$@"
  else
    yum_install "$@"
  fi
}

apt_install() {
  # 超过10天没更新源
  if test -n "`find /var/lib/apt/periodic/update-success-stamp -mtime +9`"; then
    sudo apt-get update --fix-missing
  fi
  sudo apt-get install -y "$@"
}

yum_install() {
  sudo yum install -y "$@"
}

brew_install() {
  HOMEBREW_NO_AUTO_UPDATE=1 brew install "$@"
}

brew_cask_install() {
  HOMEBREW_NO_AUTO_UPDATE=1 brew cask install "$@"
}

main "$@"

