# SSL Certificates Directory

This directory contains SSL certificates for the GoPhish deployment:

- `admin.crt` - Admin panel SSL certificate
- `admin.key` - Admin panel private key
- `phish.crt` - Phishing server SSL certificate  
- `phish.key` - Phishing server private key

## Note

The actual certificate files are generated automatically during deployment and are not included in the repository for security reasons.

## Manual Certificate Installation

If you need to install certificates manually:

1. Place your certificate files in this directory
2. Ensure proper permissions: `chmod 600 *.key && chmod 644 *.crt`
3. Restart the container: `docker-compose restart`
