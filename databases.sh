#!/bin/bash

set -ex

os=$(uname)

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --redis-server) local redis_server=true; shift ;;
      --mysql-server) local mysql_server=true; shift ;;
      --mongo-server) local mongo_server=true; shift ;;
      *             ) echo unknow option: "$1"; exit 1 ;;
    esac
  done

  # database clients
  which redis-cli >/dev/null || install_pkg redis-tools
  which mysql     >/dev/null || install_pkg mysql-client
  which mongo     >/dev/null || { add_mongo3_source; install_pkg mongodb-org-shell; }

  # database servers
  [ -z "$redis_server" ] || which redis-server >/dev/null || install_pkg redis-server
  [ -z "$mysql_server" ] || which mysqld       >/dev/null || install_mysql_server
  [ -z "$mongo_server" ] || which mongod       >/dev/null || {
    add_mongo3_source
    install_pkg mongodb-org-server
  }
}

install_mysql_server() {
  sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password root"
  sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password root"
  install_pkg mysql-server
}

add_mongo3_source() {
  file=/etc/apt/sources.list.d/mongodb-org-3.4.list
  test -e $file && return
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv \
    0C49F3730359A14518585931BC711F9BA15703C6
  echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/3.4 multiverse" |
    sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
  sudo apt-get update
}


install_pkg() {
  if [ "$os" = Darwin ]; then
    brew install "$@"
  fi

  # 超过10天没更新源
  if test -n "`find /var/lib/apt/periodic/update-success-stamp -mtime +9`"; then
    sudo apt-get update --fix-missing
  fi
  sudo apt-get install -y "$@"
}


main
