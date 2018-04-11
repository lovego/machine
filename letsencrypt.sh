#!/bin/sh

if [ $# != 1 ]; then
  echo "  usage: $0 <email-address>
example: $0 admin@abc.com"
  exit 1
fi
set -ex
email=$1

main() {
  install_certbot
  echo '6  6  *  *  *  root  certbot renew -q --deploy-hook systemctl reload nginx' |
    sudo tee /etc/cron.d/letsencrypt-renew >/dev/null
  sudo certbot register --agree-tos --email $email --no-eff-email
}

install_certbot() {
  which certbot >/dev/null 2>&1 && return
  if which apt-get >/dev/null 2>&1; then
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:certbot/certbot
    sudo apt-get update
    sudo apt-get install -y --allow-unauthenticated certbot
  else
    sudo yum install -y certbot
  fi
}

main

