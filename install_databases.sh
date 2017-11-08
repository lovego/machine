#!/bin/bash

set -ex

main() {
  which redis-server || apt_install redis-server
  which mysql || apt_install mysql-client-5.7
  which mongo || install_mongodb_shell
  # which mysqld || install_mysql_server
}

apt_install() {
  # 超过3天没更新源
  if test -n "`find /var/lib/apt/periodic/update-success-stamp -mtime +2`"; then
    sudo apt-get update --fix-missing
  fi
  sudo apt-get install -y "$1"
}

install_mongodb_shell() {
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv \
    0C49F3730359A14518585931BC711F9BA15703C6
  echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" |
    sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  sudo apt-get update
  sudo apt-get install -y mongodb-org-shell
}

install_mysql_server() {
  sudo debconf-set-selections <<< "mysql-server-5.6 mysql-server/root_password password root"
  sudo debconf-set-selections <<< "mysql-server-5.6 mysql-server/root_password_again password root"
  apt_install mysql-server-5.6
}

main
