# 医疗健康AI助手 - 安全配置与监控指南

## 版本信息
- **版本**: 2.0
- **更新日期**: 2024-01-15
- **适用环境**: 阿里云ECS服务器
- **维护团队**: Medical AI Team

---

## 📋 目录

1. [安全配置](#安全配置)
2. [监控配置](#监控配置)
3. [日志管理](#日志管理)
4. [备份策略](#备份策略)
5. [性能优化](#性能优化)
6. [故障排除](#故障排除)
7. [最佳实践](#最佳实践)

---

## 🔒 安全配置

### 1. 系统安全

#### 1.1 防火墙配置

```bash
# Ubuntu/Debian (UFW)
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

#### 1.2 SSH安全配置

编辑 `/etc/ssh/sshd_config`：

```bash
# 禁用root登录
PermitRootLogin no

# 修改默认端口
Port 2222

# 禁用密码认证，使用密钥认证
PasswordAuthentication no
PubkeyAuthentication yes

# 限制登录尝试
MaxAuthTries 3
MaxStartups 3

# 设置空闲超时
ClientAliveInterval 300
ClientAliveCountMax 2
```

重启SSH服务：
```bash
sudo systemctl restart sshd
```

#### 1.3 系统更新和安全补丁

```bash
# 设置自动安全更新
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# 手动更新系统
sudo apt update && sudo apt upgrade -y
```

### 2. 应用安全

#### 2.1 环境变量安全

- **强密码策略**：所有密码至少12位，包含大小写字母、数字和特殊字符
- **定期轮换**：每90天更换一次数据库密码和API密钥
- **权限最小化**：为每个服务创建专用用户和数据库

```bash
# 生成强密码示例
openssl rand -base64 32

# 生成JWT密钥
openssl rand -hex 64
```

#### 2.2 数据库安全

**MySQL安全配置**：

```sql
-- 创建专用用户
CREATE USER 'medical_user'@'%' IDENTIFIED BY 'Strong@Password123!';
GRANT SELECT, INSERT, UPDATE, DELETE ON medical_gpt.* TO 'medical_user'@'%';
FLUSH PRIVILEGES;

-- 删除默认用户和数据库
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'%';
DROP DATABASE IF EXISTS test;
```

**Redis安全配置**：

```bash
# 在redis.conf中设置
requirepass Strong@Redis123!
bind 127.0.0.1
port 6379
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
```

#### 2.3 SSL/TLS配置

**获取SSL证书**：

```bash
# 使用Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo crontab -e
# 添加：0 12 * * * /usr/bin/certbot renew --quiet
```

**Nginx SSL配置**：

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

### 3. 容器安全

#### 3.1 Docker安全配置

```bash
# 创建非root用户运行容器
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

# 使用多阶段构建减少攻击面
FROM php:8.1-fpm-alpine AS builder
# 构建阶段
FROM php:8.1-fpm-alpine AS runtime
# 运行阶段，只复制必要文件
```

#### 3.2 容器资源限制

```yaml
# docker-compose.yml中添加资源限制
services:
  gptserver:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

---

## 📊 监控配置

### 1. 系统监控

#### 1.1 Prometheus配置

已创建的配置文件：`monitoring/prometheus.yml`

**启动监控服务**：

```bash
# 使用监控配置启动
docker-compose -f docker-compose.aliyun.yml --profile monitoring up -d
```

#### 1.2 Grafana仪表板

已创建的仪表板：`monitoring/grafana/dashboards/medical-gpt-dashboard.json`

**访问Grafana**：
- URL: http://your-server-ip:3000
- 默认用户名: admin
- 默认密码: admin（首次登录后修改）

#### 1.3 告警规则

创建 `monitoring/rules/alerts.yml`：

```yaml
groups:
  - name: medical-gpt-alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU使用率过高"
          description: "CPU使用率已超过80%，持续5分钟"
      
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "内存使用率过高"
          description: "内存使用率已超过85%，持续5分钟"
      
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "服务不可用"
          description: "{{ $labels.job }} 服务已停止响应"
      
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(nginx_http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "响应时间过长"
          description: "95%的请求响应时间超过2秒"
```

### 2. 应用监控

#### 2.1 健康检查

**创建健康检查脚本** `scripts/health-check.sh`：

```bash
#!/bin/bash

# 健康检查脚本
HEALTH_CHECK_URL="http://localhost/health"
API_CHECK_URL="http://localhost/api/health"
LOG_FILE="/var/log/medical-gpt-health.log"

check_service() {
    local url=$1
    local service_name=$2
    
    if curl -f -s "$url" > /dev/null; then
        echo "$(date): $service_name - OK" >> $LOG_FILE
        return 0
    else
        echo "$(date): $service_name - FAILED" >> $LOG_FILE
        return 1
    fi
}

# 检查Web服务
if ! check_service $HEALTH_CHECK_URL "Web Service"; then
    # 发送告警
    echo "Web服务异常" | mail -s "Medical GPT Alert" admin@example.com
fi

# 检查API服务
if ! check_service $API_CHECK_URL "API Service"; then
    # 发送告警
    echo "API服务异常" | mail -s "Medical GPT Alert" admin@example.com
fi
```

#### 2.2 性能监控

**创建性能监控脚本** `scripts/performance-monitor.sh`：

```bash
#!/bin/bash

# 性能监控脚本
LOG_FILE="/var/log/medical-gpt-performance.log"
THRESHOLD_CPU=80
THRESHOLD_MEMORY=85
THRESHOLD_DISK=90

# 获取系统指标
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

# 记录指标
echo "$(date): CPU=${CPU_USAGE}%, Memory=${MEMORY_USAGE}%, Disk=${DISK_USAGE}%" >> $LOG_FILE

# 检查阈值
if (( $(echo "$CPU_USAGE > $THRESHOLD_CPU" | bc -l) )); then
    echo "CPU使用率告警: ${CPU_USAGE}%" | mail -s "CPU Alert" admin@example.com
fi

if (( $(echo "$MEMORY_USAGE > $THRESHOLD_MEMORY" | bc -l) )); then
    echo "内存使用率告警: ${MEMORY_USAGE}%" | mail -s "Memory Alert" admin@example.com
fi

if [ "$DISK_USAGE" -gt "$THRESHOLD_DISK" ]; then
    echo "磁盘使用率告警: ${DISK_USAGE}%" | mail -s "Disk Alert" admin@example.com
fi
```

---

## 📝 日志管理

### 1. 日志配置

#### 1.1 集中化日志收集

**使用ELK Stack**：

```yaml
# docker-compose.aliyun.yml中添加
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.15.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
  
  logstash:
    image: docker.elastic.co/logstash/logstash:7.15.0
    volumes:
      - ./monitoring/logstash/pipeline:/usr/share/logstash/pipeline
      - ./logs:/var/log/medical-gpt
    depends_on:
      - elasticsearch
  
  kibana:
    image: docker.elastic.co/kibana/kibana:7.15.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
```

#### 1.2 日志轮转配置

**创建logrotate配置** `/etc/logrotate.d/medical-gpt`：

```bash
/opt/medical-gpt/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml restart nginx
    endscript
}
```

### 2. 日志分析

#### 2.1 错误日志监控

```bash
# 监控错误日志脚本
#!/bin/bash
ERROR_LOG="/opt/medical-gpt/logs/nginx/error.log"
PHP_ERROR_LOG="/opt/medical-gpt/logs/php/error.log"

# 检查最近5分钟的错误
if [ -f "$ERROR_LOG" ]; then
    RECENT_ERRORS=$(find "$ERROR_LOG" -mmin -5 -exec grep -c "error" {} \;)
    if [ "$RECENT_ERRORS" -gt 10 ]; then
        echo "检测到大量错误: $RECENT_ERRORS" | mail -s "Error Alert" admin@example.com
    fi
fi
```

#### 2.2 访问日志分析

```bash
# 分析访问模式
#!/bin/bash
ACCESS_LOG="/opt/medical-gpt/logs/nginx/access.log"

# 统计最近1小时的请求
echo "=== 最近1小时访问统计 ==="
awk -v date="$(date -d '1 hour ago' '+%d/%b/%Y:%H')" '$4 > "["date {print}' $ACCESS_LOG | wc -l

# 统计状态码
echo "=== 状态码统计 ==="
awk '{print $9}' $ACCESS_LOG | sort | uniq -c | sort -nr

# 统计访问IP
echo "=== 访问IP统计 ==="
awk '{print $1}' $ACCESS_LOG | sort | uniq -c | sort -nr | head -10
```

---

## 💾 备份策略

### 1. 数据备份

#### 1.1 数据库备份

**自动备份脚本** `scripts/backup-database.sh`：

```bash
#!/bin/bash

BACKUP_DIR="/opt/backups/medical-gpt"
DATE=$(date +%Y%m%d_%H%M%S)
MYSQL_CONTAINER="medical-gpt-mysql"
REDIS_CONTAINER="medical-gpt-redis"
RETENTION_DAYS=7

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份MySQL
echo "开始备份MySQL数据库..."
docker exec $MYSQL_CONTAINER mysqldump -u root -p$MYSQL_ROOT_PASSWORD --all-databases --single-transaction --routines --triggers > $BACKUP_DIR/mysql_$DATE.sql

# 备份Redis
echo "开始备份Redis数据..."
docker exec $REDIS_CONTAINER redis-cli --rdb /data/dump_$DATE.rdb
docker cp $REDIS_CONTAINER:/data/dump_$DATE.rdb $BACKUP_DIR/

# 压缩备份文件
echo "压缩备份文件..."
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz -C $BACKUP_DIR mysql_$DATE.sql dump_$DATE.rdb
rm $BACKUP_DIR/mysql_$DATE.sql $BACKUP_DIR/dump_$DATE.rdb

# 清理旧备份
echo "清理旧备份文件..."
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "备份完成: $BACKUP_DIR/backup_$DATE.tar.gz"
```

#### 1.2 文件备份

```bash
#!/bin/bash
# 备份应用文件和配置

BACKUP_DIR="/opt/backups/medical-gpt"
APP_DIR="/opt/medical-gpt"
DATE=$(date +%Y%m%d_%H%M%S)

# 备份配置文件
tar -czf $BACKUP_DIR/config_$DATE.tar.gz -C $APP_DIR \
    gptserver/.env \
    docker/ \
    ssl_certs/ \
    monitoring/

# 备份上传文件
if [ -d "$APP_DIR/gptserver/storage/uploads" ]; then
    tar -czf $BACKUP_DIR/uploads_$DATE.tar.gz -C $APP_DIR gptserver/storage/uploads/
fi

echo "文件备份完成"
```

### 2. 灾难恢复

#### 2.1 数据恢复脚本

```bash
#!/bin/bash
# 数据恢复脚本

BACKUP_FILE=$1
if [ -z "$BACKUP_FILE" ]; then
    echo "用法: $0 <backup_file.tar.gz>"
    exit 1
fi

# 解压备份文件
tar -xzf $BACKUP_FILE -C /tmp/

# 恢复MySQL
if [ -f "/tmp/mysql_*.sql" ]; then
    echo "恢复MySQL数据库..."
    docker exec -i medical-gpt-mysql mysql -u root -p$MYSQL_ROOT_PASSWORD < /tmp/mysql_*.sql
fi

# 恢复Redis
if [ -f "/tmp/dump_*.rdb" ]; then
    echo "恢复Redis数据..."
    docker cp /tmp/dump_*.rdb medical-gpt-redis:/data/dump.rdb
    docker restart medical-gpt-redis
fi

echo "数据恢复完成"
```

---

## ⚡ 性能优化

### 1. 系统优化

#### 1.1 内核参数优化

编辑 `/etc/sysctl.conf`：

```bash
# 网络优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr

# 文件描述符限制
fs.file-max = 65536

# 虚拟内存优化
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# 应用生效
sudo sysctl -p
```

#### 1.2 文件描述符限制

编辑 `/etc/security/limits.conf`：

```bash
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
```

### 2. 应用优化

#### 2.1 PHP优化

**php.ini配置**：

```ini
; 内存限制
memory_limit = 512M

; 执行时间
max_execution_time = 300
max_input_time = 300

; 文件上传
upload_max_filesize = 50M
post_max_size = 50M
max_file_uploads = 20

; OPcache优化
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 10000
opcache.validate_timestamps = 0
opcache.save_comments = 0
opcache.fast_shutdown = 1
```

#### 2.2 MySQL优化

**my.cnf配置**：

```ini
[mysqld]
# InnoDB优化
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# 查询缓存
query_cache_type = 1
query_cache_size = 64M
query_cache_limit = 2M

# 连接优化
max_connections = 200
max_connect_errors = 1000
connect_timeout = 10
wait_timeout = 600

# 慢查询日志
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
```

#### 2.3 Redis优化

**redis.conf配置**：

```bash
# 内存优化
maxmemory 512mb
maxmemory-policy allkeys-lru

# 持久化优化
save 900 1
save 300 10
save 60 10000

# 网络优化
tcp-keepalive 300
timeout 300

# 日志级别
loglevel notice
```

---

## 🔧 故障排除

### 1. 常见问题诊断

#### 1.1 服务无法启动

```bash
# 检查容器状态
docker-compose -f docker-compose.aliyun.yml ps

# 查看容器日志
docker-compose -f docker-compose.aliyun.yml logs [service_name]

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :3306

# 检查磁盘空间
df -h

# 检查内存使用
free -h
```

#### 1.2 数据库连接问题

```bash
# 测试MySQL连接
docker exec -it medical-gpt-mysql mysql -u root -p

# 检查MySQL进程
docker exec medical-gpt-mysql mysqladmin -u root -p processlist

# 测试Redis连接
docker exec -it medical-gpt-redis redis-cli ping

# 检查Redis信息
docker exec medical-gpt-redis redis-cli info
```

#### 1.3 性能问题诊断

```bash
# 系统负载
uptime
top
htop

# 磁盘I/O
iotop

# 网络流量
nethogs

# 检查慢查询
docker exec medical-gpt-mysql mysql -u root -p -e "SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;"
```

### 2. 应急处理

#### 2.1 服务重启脚本

```bash
#!/bin/bash
# 应急重启脚本

echo "开始应急重启..."

# 停止服务
docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml down

# 清理资源
docker system prune -f

# 启动服务
docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml up -d

# 等待服务就绪
sleep 30

# 健康检查
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "服务重启成功"
else
    echo "服务重启失败，请检查日志"
    docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml logs
fi
```

---

## 📚 最佳实践

### 1. 安全最佳实践

1. **定期更新**：保持系统和应用程序的最新版本
2. **最小权限原则**：为每个服务分配最小必要权限
3. **网络隔离**：使用防火墙和网络分段
4. **加密传输**：所有敏感数据传输使用HTTPS
5. **审计日志**：记录所有重要操作和访问

### 2. 监控最佳实践

1. **多层监控**：系统、应用、业务三个层面
2. **主动告警**：设置合理的告警阈值
3. **趋势分析**：关注长期趋势，预防问题
4. **自动化响应**：对常见问题实现自动修复
5. **定期演练**：定期进行故障演练

### 3. 运维最佳实践

1. **文档化**：所有配置和流程都要有文档
2. **版本控制**：配置文件使用Git管理
3. **自动化部署**：使用CI/CD流水线
4. **定期备份**：制定并执行备份计划
5. **容量规划**：根据业务增长规划资源

### 4. 性能最佳实践

1. **缓存策略**：合理使用Redis缓存
2. **数据库优化**：定期优化查询和索引
3. **CDN加速**：静态资源使用CDN
4. **负载均衡**：高并发时使用负载均衡
5. **资源监控**：持续监控资源使用情况

---

## 📞 技术支持

### 联系方式
- **技术支持邮箱**: support@medical-ai.com
- **紧急联系电话**: +86-xxx-xxxx-xxxx
- **在线文档**: https://docs.medical-ai.com
- **GitHub仓库**: https://github.com/medical-ai/medical-gpt

### 支持时间
- **工作日**: 9:00 - 18:00 (UTC+8)
- **紧急支持**: 24/7 (仅限生产环境严重故障)

---

**版权声明**: 本文档版权归Medical AI Team所有，仅供内部使用。

**最后更新**: 2024-01-15
**文档版本**: v2.0