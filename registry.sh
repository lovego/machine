#!/bin/bash

if [ $# != 1 ]; then
  echo "  usage: $0 <domain-name>
example: $0 registry.abc.com"
  exit 1
fi
set -ex
domain=$1

main() {
  check_certificate
  setup_nginx
  docker run -d -p 5000:5000 --restart=always --name registry registry:2
}

check_certificate() {
  sudo test -e /etc/letsencrypt/live/$domain && return
  setup_nginx checkCertificate
  sudo mkdir -p /var/www/letsencrypt
  sudo certbot certonly --webroot -w /var/www/letsencrypt -d $domain
}

setup_nginx() {
  if [ "$1" = checkCertificate ]; then
    local ssl=''
  else
    local ssl="
  listen              443 ssl http2;
  ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers         AES128-SHA:AES256-SHA:RC4-SHA:DES-CBC3-SHA:RC4-MD5;
  ssl_certificate     /etc/letsencrypt/live/$domain/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
  ssl_session_cache   shared:SSL:10m;
  ssl_session_timeout 10m;
"
  fi

  echo \
"server {
  listen 80;
  server_name $domain;
$ssl
  location / {
    proxy_pass http://127.0.0.1:5000;
  }

  proxy_http_version 1.1;
  proxy_set_header Connection \"\";
  proxy_set_header Host \$http_host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_connect_timeout 3s;

  access_log /var/log/nginx/$domain/access.log;
  error_log  /var/log/nginx/$domain/access.err;

  location /.well-known {
    root /var/www/letsencrypt;
  }
}" | sudo tee /etc/nginx/sites-enabled/$domain >/dev/null
  sudo mkdir -p /var/log/nginx/$domain
  reload_nginx
}

reload_nginx() {
  if test -f /lib/systemd/system/nginx.service; then
    sudo systemctl reload nginx
  elif test -x /etc/init.d/nginx; then
    sudo service nginx reload
  else
    sudo reload-nginx
  fi
}

main

