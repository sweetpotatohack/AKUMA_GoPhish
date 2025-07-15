# 🎯 Sneaky GoPhish - Automated Deployment & SSL Management

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg)](https://www.docker.com/)
[![SSL](https://img.shields.io/badge/SSL-Let's%20Encrypt-green.svg)](https://letsencrypt.org/)

> **⚠️ DISCLAIMER**: This tool is for authorized penetration testing and security research only. Use responsibly and only on systems you own or have explicit permission to test.

## 🚀 Features

- **Fully Automated Deployment**: One-command installation with Docker
- **SSL Certificate Management**: Automatic Let's Encrypt SSL certificate generation and renewal
- **Stealth Modifications**: Removes GoPhish fingerprints for better evasion
- **Easy Management**: Simple scripts for start, stop, restart, and monitoring
- **Production Ready**: Docker-based deployment with persistence
- **Monitoring**: Built-in status monitoring and health checks

## 📋 What's Included

### Core Components
- **Sneaky GoPhish**: Modified version with removed fingerprints
- **SSL Automation**: Let's Encrypt certificate management
- **Docker Setup**: Containerized deployment
- **Management Scripts**: Easy-to-use administration tools

### Modified Features
- ✅ Removed `X-Gophish-*` headers
- ✅ Changed default server name
- ✅ Modified recipient parameter (`rid` → `id`)
- ✅ Custom 404 error pages
- ✅ Enhanced evasion capabilities

## 🛠️ Prerequisites

- **OS**: Ubuntu 20.04+ / Debian 10+
- **Access**: Root privileges required
- **Network**: Ports 80, 443, 3333 available
- **DNS**: Valid domain names pointing to your server
- **Dependencies**: Docker, Docker Compose, Certbot

## 🚀 Quick Start

### Option 1: Automated Installation
```bash
# Download and run the deployment script
wget https://raw.githubusercontent.com/sweetpotatohack/sneaky-gophish-automation/main/deploy_gophish.sh
chmod +x deploy_gophish.sh
./deploy_gophish.sh
```

### Option 2: Manual Installation
```bash
# Clone the repository
git clone https://github.com/sweetpotatohack/sneaky-gophish-automation.git
cd sneaky-gophish-automation

# Make scripts executable
chmod +x *.sh

# Run deployment
./deploy_gophish.sh
```

## 📁 Project Structure

```
sneaky-gophish-automation/
├── deploy_gophish.sh      # Main deployment script
├── manage_gophish.sh      # System management script
├── get_password.sh        # Password retrieval script
├── status.sh             # System status script
├── renew_ssl.sh          # SSL certificate renewal (auto-generated)
├── docker-compose.yml    # Docker configuration
├── Dockerfile           # Custom GoPhish image
├── config.json          # GoPhish configuration
├── ssl/                 # SSL certificates directory
│   ├── admin.crt        # Admin panel certificate
│   ├── admin.key        # Admin panel private key
│   ├── phish.crt        # Phishing server certificate
│   └── phish.key        # Phishing server private key
└── files/               # Additional resources
```

## 🔧 Configuration

### Domain Setup
Before running the deployment script, ensure you have:

1. **Two domains** pointing to your server:
   - Admin domain (e.g., `admin.example.com`)
   - Phishing domain (e.g., `phish.example.com`)

2. **DNS A Records** configured:
   ```
   admin.example.com    → Your-Server-IP
   phish.example.com    → Your-Server-IP
   ```

### Environment Variables
The deployment script will prompt for:
- Admin domain name
- Phishing domain name  
- Email for Let's Encrypt registration

## 🎮 Management Commands

### System Management
```bash
# Show system status
./manage_gophish.sh status

# Get admin password
./manage_gophish.sh password

# Restart services
./manage_gophish.sh restart

# Stop services
./manage_gophish.sh stop

# Start services
./manage_gophish.sh start

# View logs
./manage_gophish.sh logs

# Follow logs in real-time
./manage_gophish.sh logs -f
```

### SSL Certificate Management
```bash
# Renew SSL certificates
./manage_gophish.sh renew-ssl

# Check certificate status
./manage_gophish.sh ssl-status

# View certificate expiry
./manage_gophish.sh ssl-check
```

### Backup and Restore
```bash
# Create backup
./manage_gophish.sh backup

# Restore from backup
./manage_gophish.sh restore /path/to/backup

# List available backups
./manage_gophish.sh list-backups
```

## 🔍 System Status

### Quick Status Check
```bash
./status.sh
```

**Sample Output:**
```
🔥 Sneaky GoPhish Status 🔥
============================

✅ Docker Status: Running
✅ Container Status: sneaky_gophish_ssl (Up 2 hours)
✅ SSL Certificate: Valid (expires: 2024-10-15)
✅ Admin Panel: https://admin.example.com:3333
✅ Phish Server: https://phish.example.com

🔑 Admin Credentials:
   Username: admin
   Password: [Use ./get_password.sh to retrieve]

📊 Resource Usage:
   CPU: 5.2%
   Memory: 234MB
   Disk: 1.2GB
```

## 🌐 Access URLs

After successful deployment:

- **Admin Panel**: `https://your-admin-domain:3333`
- **Phishing Server**: `https://your-phish-domain`
- **Default Username**: `admin`
- **Password**: Retrieved via `./get_password.sh`

## 🐳 Docker Management

### Docker Commands
```bash
# View running containers
docker-compose ps

# View logs
docker-compose logs -f sneaky_gophish

# Restart container
docker-compose restart

# Stop all services
docker-compose down

# Start all services
docker-compose up -d

# Rebuild image
docker-compose build --no-cache
```

### Container Access
```bash
# Access container shell
docker exec -it sneaky_gophish_ssl /bin/bash

# View GoPhish logs from container
docker exec sneaky_gophish_ssl tail -f /opt/gophish/gophish.log
```

## 🔐 Security Considerations

### SSL/TLS Configuration
- **Certificates**: Automatically generated via Let's Encrypt
- **Renewal**: Automated via cron job (runs daily)
- **Protocols**: TLS 1.2+ only
- **Cipher Suites**: Modern, secure configurations

### Firewall Configuration
```bash
# Allow required ports
ufw allow 80/tcp
ufw allow 443/tcp  
ufw allow 3333/tcp

# Enable firewall
ufw enable
```

### Security Best Practices
- Change default passwords immediately
- Use strong, unique passwords
- Enable fail2ban for SSH protection
- Regularly update the system
- Monitor logs for suspicious activity
- Use VPN for admin access when possible

## 🛠️ Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check what's using ports
netstat -tlnp | grep -E ":80|:443|:3333"

# Stop conflicting services
systemctl stop apache2 nginx

# Restart GoPhish
./manage_gophish.sh restart
```

#### SSL Certificate Issues
```bash
# Check certificate status
certbot certificates

# Manual certificate renewal
certbot renew --dry-run

# Force certificate regeneration
certbot delete --cert-name your-domain.com
./manage_gophish.sh renew-ssl
```

#### Container Issues
```bash
# Check container logs
docker logs sneaky_gophish_ssl

# Restart container
docker-compose restart

# Rebuild container
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

#### Database Issues
```bash
# Access container and check database
docker exec -it sneaky_gophish_ssl /bin/bash
ls -la /opt/gophish/gophish.db

# Reset database (⚠️ This will delete all data!)
docker-compose down
docker volume rm sneaky_gophish_gophish_data
docker-compose up -d
```

## 🔄 Automated Maintenance

### Cron Jobs
The deployment script automatically sets up:

```bash
# SSL certificate renewal (daily at 2 AM)
0 2 * * * /root/sneaky_gophish/renew_ssl.sh

# System backup (weekly on Sunday at 3 AM)
0 3 * * 0 /root/sneaky_gophish/manage_gophish.sh backup

# Log rotation (daily at 1 AM)
0 1 * * * /usr/sbin/logrotate /etc/logrotate.d/gophish
```

### Monitoring
```bash
# Set up monitoring (optional)
./manage_gophish.sh setup-monitoring

# Check system health
./manage_gophish.sh health-check
```

## 📊 Performance Tuning

### Resource Optimization
```bash
# Optimize Docker resources
docker system prune -a

# Monitor resource usage
docker stats sneaky_gophish_ssl

# Adjust container limits in docker-compose.yml
resources:
  limits:
    cpus: '1.0'
    memory: 512M
```

### Database Optimization
```bash
# Vacuum SQLite database
docker exec sneaky_gophish_ssl sqlite3 /opt/gophish/gophish.db "VACUUM;"

# Backup and optimize database
./manage_gophish.sh optimize-db
```

## 🔧 Advanced Configuration

### Custom Configuration
Edit `config.json` to customize:
- Database settings
- Logging levels
- Server binding addresses
- TLS configuration

### Environment Variables
```bash
# Set custom environment variables
export GOPHISH_ADMIN_URL="https://admin.example.com:3333"
export GOPHISH_PHISH_URL="https://phish.example.com"
export GOPHISH_DB_PATH="/opt/gophish/gophish.db"
```

## 📝 Logging

### Log Locations
- **GoPhish Logs**: `/opt/gophish/gophish.log` (inside container)
- **Docker Logs**: `docker-compose logs`
- **System Logs**: `/var/log/syslog`
- **SSL Logs**: `/var/log/letsencrypt/letsencrypt.log`

### Log Management
```bash
# View recent logs
./manage_gophish.sh logs --tail 100

# Search logs
./manage_gophish.sh logs | grep "error"

# Export logs
./manage_gophish.sh export-logs /path/to/export/
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Legal Notice

This tool is intended for authorized security testing and educational purposes only. Users are responsible for ensuring compliance with applicable laws and regulations. The authors assume no liability for misuse of this software.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/sweetpotatohack/sneaky-gophish-automation/issues)
- **Wiki**: [Project Wiki](https://github.com/sweetpotatohack/sneaky-gophish-automation/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/sweetpotatohack/sneaky-gophish-automation/discussions)

## 📈 Changelog

### v1.0.0
- Initial release
- Automated deployment script
- SSL certificate management
- Docker containerization
- Management scripts
- Comprehensive documentation

---

**Made with ❤️ for ethical security testing**

*"The best defense is a good offense - but only with permission!"*
