#!/bin/bash

if [ $# -eq 0 ]; then
  echo "  usage: $0 <main-domain> [-d <domain>] ...
example: $0 abc.com -d *.abc.com -d *.qa.abc.com

environment variables:
  email:      email                for LetsEncrypt account registering.
  Ali_Key:    aliyun access key    for domain authentication.
  Ali_Secret: aliyun access secret for domain authentication.
"
  exit 1
fi

set -ex

test -f ~/.acme.sh/acme.sh || curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --updateaccount --accountemail "$email"
~/.acme.sh/acme.sh --issue --dns ali_dns -d "$@"
mkdir -p /etc/nginx/certs
~/.acme.sh/acme.sh --install-cert -d "$1" \
  --fullchain-file /etc/nginx/certs/$1.fullchain --key-file /etc/nginx/certs/$1.key

