#!/bin/bash

if [ $# != 1 ]; then
  echo "  usage: $0 <domain-name>
example: $0 example.abc.com"
  exit 1
fi
set -ex
domain=$1

main() {
  sudo test -e /etc/letsencrypt/live/$domain && return
  setup_nginx
  sudo mkdir -p /var/www/letsencrypt
  sudo certbot certonly --webroot -w /var/www/letsencrypt -d $domain
}

setup_nginx() {
  echo "
server {
  listen 80;
  server_name $domain;

  access_log /var/log/nginx/$domain/access.log;
  error_log  /var/log/nginx/$domain/access.err;
"'

  location / {
    proxy_pass                          http://127.0.0.1:5000;
    proxy_set_header  Host              $http_host;   # required for docker client sake
    proxy_set_header  X-Real-IP         $remote_addr; # pass on real client IP
    proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header  X-Forwarded-Proto $scheme;
  }

  location /.well-known {
    root /var/www/letsencrypt;
  }
' | sudo tee /etc/nginx/sites-enabled/$domain >/dev/null
}

main
