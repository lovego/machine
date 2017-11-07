#!/bin/bash

main() {
  which redis-server || apt_install redis-server
  which mysqld || install_mysql_server
  which mongo || install_mongodb_shell
}

apt_install() {
  # 超过3天没更新源
  if test -n "`find /var/lib/apt/periodic/update-success-stamp -mtime +2`"; then
    sudo apt-get update --fix-missing
  fi
  sudo apt-get install -y "$1"
}

install_mysql_server() {
  sudo debconf-set-selections <<< "mysql-server-5.6 mysql-server/root_password password root"
  sudo debconf-set-selections <<< "mysql-server-5.6 mysql-server/root_password_again password root"
  apt_install mysql-server-5.6
}

install_mongodb_shell() {
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
  echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
  sudo apt-get update
  sudo apt-get install -y mongodb-org-shell
}

main
