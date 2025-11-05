#!/bin/bash
set -euo pipefail

echo "Waiting 180 seconds for EC2 to stabilize..."
sleep 180

sudo apt update -y
sudo apt install -y nginx git

# Deploy static website
sudo rm -rf /var/www/html/*
sudo git clone https://github.com/Christianchika/mediplus.git /tmp/website
sudo cp -r /tmp/website/* /var/www/html/

sudo systemctl enable nginx
sudo systemctl restart nginx

echo "Web server setup complete."

