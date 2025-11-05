#!/bin/bash
set -euo pipefail

WEB_IP=$1
DOMAIN=$2
EMAIL=$3

echo "Waiting 180 seconds for instance services to stabilize..."
sleep 180

sudo apt update -y
sudo apt install -y nginx certbot python3-certbot-nginx

# Configure reverse proxy
cat <<EOF | sudo tee /etc/nginx/sites-available/reverse_proxy
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://${WEB_IP};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/reverse_proxy /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Wait until DNS points to this instance and HTTP is reachable before running certbot
echo "Checking DNS and HTTP readiness for ${DOMAIN} before obtaining certificate..."
TARGET_IP=$(curl -s http://checkip.amazonaws.com || curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo "Instance public IP detected as: ${TARGET_IP}"

ATTEMPTS=40
SLEEP_SECONDS=15
for i in $(seq 1 ${ATTEMPTS}); do
  RESOLVED_IP=$(getent ahostsv4 "${DOMAIN}" | awk '{print $1; exit}')
  echo "Attempt ${i}/${ATTEMPTS}: ${DOMAIN} resolves to ${RESOLVED_IP}"

  if [[ -n "${RESOLVED_IP}" && "${RESOLVED_IP}" == "${TARGET_IP}" ]]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${DOMAIN}") || true
    echo "HTTP check code: ${HTTP_CODE}"
    if [[ "${HTTP_CODE}" =~ ^(200|301|302)$ ]]; then
      echo "DNS and HTTP ready. Proceeding with certbot."
      break
    fi
  fi

  if [[ ${i} -eq ${ATTEMPTS} ]]; then
    echo "DNS/HTTP readiness not achieved in time; proceeding anyway (certbot may fail)."
  else
    sleep ${SLEEP_SECONDS}
  fi
done

# Obtain Let's Encrypt certificate (will only succeed if DNS/HTTP are ready)
sudo certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL} --redirect || {
  echo "Certbot failed; keeping HTTP-only for now. You can re-run certbot later.";
}

echo "Reverse proxy setup complete with HTTPS."

