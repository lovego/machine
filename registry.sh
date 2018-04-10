#!/bin/bash

if [ $# != 1 ]; then
  echo "  usage: $0 <domain-name>
example: $0 registry.abc.com"
  exit 1
fi
set -ex
domain=$1

main() {
  setup_nginx
  docker run --name registry -p 127.0.0.1:5000:5000 -d --restart=always \
    -e REGISTRY_STORAGE_DELETE_ENABLED=true  registry:2
}

setup_nginx() {
  echo '## Set a variable to help us decide if we need to add the
## "Docker-Distribution-Api-Version" header.
## The registry always sets this header.
## In the case of nginx performing auth, the header is unset
## since nginx is auth-ing before proxying.
map $upstream_http_docker_distribution_api_version $docker_distribution_api_version {
  "" "registry/2.0";
}
'"
server {
  listen 80;
  server_name $domain;
  listen              443 ssl http2;
  ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers         ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS;
  ssl_certificate     /etc/letsencrypt/live/$domain/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
  ssl_session_cache   shared:SSL:10m;
  ssl_session_timeout 10m;
  access_log /var/log/nginx/$domain/access.log;
  error_log  /var/log/nginx/$domain/access.err;
"'
  # disable any limits to avoid HTTP 413 for large image uploads
  client_max_body_size 0;
  # required to avoid HTTP 411: see Issue #1486 (https://github.com/moby/moby/issues/1486)
  chunked_transfer_encoding on;

  location /v2/ {
    # Do not allow connections from docker 1.5 and earlier
    # docker pre-1.6.0 did not properly set the user agent on ping, catch "Go *" user agents
    if ($http_user_agent ~ "^(docker\/1\.(3|4|5(?!\.[0-9]-dev))|Go ).*$" ) {
      return 404;
    }

    # To add basic authentication to v2 use auth_basic setting.
    # auth_basic "Registry realm";
    # auth_basic_user_file /etc/nginx/conf.d/nginx.htpasswd;

    ## If $docker_distribution_api_version is empty, the header is not added.
    ## See the map directive above where this variable is defined.
    add_header "Docker-Distribution-Api-Version" $docker_distribution_api_version always;

    proxy_pass                          http://127.0.0.1:5000;
    proxy_set_header  Host              $http_host;   # required for docker client sake
    proxy_set_header  X-Real-IP         $remote_addr; # pass on real client IP
    proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header  X-Forwarded-Proto $scheme;
    proxy_read_timeout                  900;
  }

  location /.well-known {
    root /var/www/letsencrypt;
  }
}' | sudo tee /etc/nginx/sites-enabled/$domain >/dev/null
  sudo mkdir -p /var/log/nginx/$domain
  sudo systemctl reload nginx
}

main

