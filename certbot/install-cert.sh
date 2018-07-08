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
  setup_nginx_with_https
}

setup_nginx() {
  echo "
server {
  listen 80;
  server_name $domain;

  access_log /var/log/nginx/$domain/access.log;
  error_log  /var/log/nginx/$domain/access.err;
  $1
"'
  location /.well-known {
    root /var/www/letsencrypt;
  }
}' | sudo tee /etc/nginx/sites-enabled/$domain >/dev/null
  sudo mkdir -p /var/log/nginx/$domain
  sudo systemctl reload nginx
}

setup_nginx_with_https() {
 setup_nginx "
  listen              443 ssl http2;
  ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers         ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS;
  ssl_certificate     /etc/letsencrypt/live/$domain/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
  ssl_session_cache   shared:SSL:10m;
  ssl_session_timeout 10m;
  "
}

main
