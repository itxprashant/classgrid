#!/bin/bash

# Exit on error
set -e

echo "Starting deployment setup..."

# Check if run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (sudo ./setup.sh)"
  exit 1
fi

# Update and install dependencies
echo "Installing Nginx and Certbot..."
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

# Setup Nginx Config
echo "Configuring Nginx..."
# Backup default config if it exists
if [ -f /etc/nginx/sites-available/default ]; then
    cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
fi

# Copy our config
cp nginx.conf /etc/nginx/sites-available/default

# Test configuration
nginx -t

# Restart Nginx
systemctl restart nginx

# SSL Setup
echo "Would you like to setup SSL with Certbot now? (y/n)"
read -r setup_ssl

if [ "$setup_ssl" = "y" ]; then
    echo "Enter your domain name (e.g., example.com):"
    read -r domain_name
    
    # Run certbot
    certbot --nginx -d "$domain_name"
else
    echo "Skipping SSL setup. You can run 'sudo certbot --nginx' later."
fi

echo "Setup complete! Make sure your build files are in /var/www/html"
