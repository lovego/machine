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
  setup_renew
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
    yum_install certbot
  fi
}

setup_renew() {
  test -x /bin/nginx-reload && return
  echo "#!/bin/sh
if test -f /lib/systemd/system/nginx.service; then
  sudo systemctl reload nginx
elif test -x /etc/init.d/nginx; then
  sudo service nginx reload
else
  sudo reload-nginx
fi
" | sudo tee /bin/nginx-reload >/dev/null
  sudo chmod +x /bin/nginx-reload
  echo '6  6  *  *  *  root  certbot renew --deploy-hook nginx-reload' |
    sudo tee /etc/cron.d/letsencrypt-renew >/dev/null
}

main

