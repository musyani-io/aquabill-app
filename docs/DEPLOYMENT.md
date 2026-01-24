# Production Deployment Guide

## Server Requirements

- Linux server (Ubuntu 20.04 or later)
- PostgreSQL 13+
- Redis 6+
- Docker & Docker Compose
- SSL certificate

## Pre-Deployment Checklist

- [ ] Database backups configured
- [ ] SSL certificates obtained
- [ ] Environment variables configured
- [ ] All tests passing
- [ ] Documentation updated

## Deployment Steps

### 1. Prepare Server

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. Clone and Setup

```bash
sudo mkdir -p /opt/aquabill
sudo chown -R $USER:$USER /opt/aquabill
cd /opt/aquabill
git clone <repository-url> .
```

### 3. Configure Environment

```bash
cp .env.example .env.production
# Edit .env.production with production values
```

### 4. Setup SSL Certificates

```bash
sudo mkdir -p /opt/aquabill/deployment/ssl
# Copy your SSL cert and key:
sudo cp /path/to/cert.pem /opt/aquabill/deployment/ssl/
sudo cp /path/to/key.pem /opt/aquabill/deployment/ssl/
sudo chmod 600 /opt/aquabill/deployment/ssl/*
```

### 5. Start Services

```bash
cd /opt/aquabill
docker-compose -f docker-compose.prod.yml up -d
```

### 6. Run Migrations

```bash
docker-compose -f docker-compose.prod.yml exec backend alembic upgrade head
```

### 7. Setup Monitoring

```bash
# Configure Prometheus
sudo cp monitoring/prometheus.yml /etc/prometheus/
sudo systemctl restart prometheus

# Setup Grafana dashboards
# Import dashboards from monitoring/grafana-dashboards/
```

### 8. Setup Backup

```bash
sudo cp deployment/scripts/backup.sh /usr/local/bin/aquabill-backup
sudo chmod +x /usr/local/bin/aquabill-backup

# Add to crontab for daily backup
0 2 * * * /usr/local/bin/aquabill-backup
```

## Post-Deployment

### Monitor Health

```bash
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f
```

### Verify Services

- API: <https://api.aquabill.app/health>
- Docs: <https://api.aquabill.app/docs>

### Test Backup

```bash
/usr/local/bin/aquabill-backup
ls -lh /backups/aquabill/
```

## Scaling Considerations

### Celery Worker Scaling

```bash
docker-compose -f docker-compose.prod.yml up -d --scale celery-worker=3
```

### Database Connection Pool

Adjust in `.env.production`:

```
DATABASE_POOL_SIZE=20
DATABASE_MAX_OVERFLOW=40
```

### Redis Persistence

Enable AOF in Redis config for durability.

## Security Hardening

- [ ] Setup firewall rules
- [ ] Enable SSH key authentication only
- [ ] Configure rate limiting
- [ ] Enable CORS properly
- [ ] Rotate JWT secrets monthly
- [ ] Enable database encryption at rest

## Rollback Procedure

```bash
# If deployment fails, rollback to previous version
cd /opt/aquabill
git revert HEAD
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d
docker-compose -f docker-compose.prod.yml exec backend alembic downgrade -1
```

## Support & Monitoring

- Monitor API response times
- Track SMS delivery rates
- Review anomaly alerts
- Check sync queue depth
