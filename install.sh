#!/bin/bash

# curl -s https://raw.githubusercontent.com/lovego/machine/master/install.sh | bash -s

set -ex

main() {
  setup_sudo_no_password
  which go     || install_golang
  which docker || install_docker
  which nginx  || apt_install nginx-core
  which git    || apt_install git
}

setup_sudo_no_password() {
  username=$(id -nu)
  local file="/etc/sudoers.d/$username"
  test -f "$file"  || echo "$username  ALL=NOPASSWD: ALL" | sudo tee --append "$file" > /dev/null
}

install_golang() {
  wget -O /tmp/go.tar.gz https://storage.googleapis.com/golang/go1.8.5.linux-amd64.tar.gz
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

apt_install() {
  # 超过3天没更新源
  if test -n "`find /var/lib/apt/periodic/update-success-stamp -mtime +2`"; then
    sudo apt-get update --fix-missing
  fi
  sudo apt-get install -y "$1"
}

main
