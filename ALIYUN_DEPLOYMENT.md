# 医疗健康AI助手 - 阿里云服务器部署方案

## 项目架构概述

本项目是基于GPTLink改造的医疗健康AI助手，采用微服务架构，包含以下核心组件：

### 服务组件
- **Frontend (gptweb)**: Vue.js前端应用，提供用户交互界面
- **Admin (gptadmin)**: 管理后台，用于系统管理和配置
- **Backend (gptserver)**: PHP Hyperf框架后端API服务
- **Database**: MySQL 8.0数据库
- **Cache**: Redis 7缓存服务
- **Proxy**: Nginx反向代理和负载均衡

### 技术栈
- **后端**: PHP 8.0+ + Hyperf框架
- **前端**: Vue.js + Element UI
- **数据库**: MySQL 8.0
- **缓存**: Redis 7
- **容器**: Docker + Docker Compose
- **代理**: Nginx
- **AI服务**: OpenAI API / DeepSeek API

## 阿里云服务器部署方案

### 1. 服务器配置要求

#### 推荐配置
- **CPU**: 4核心及以上
- **内存**: 8GB及以上
- **存储**: 100GB SSD云盘
- **带宽**: 5Mbps及以上
- **操作系统**: Ubuntu 20.04 LTS / CentOS 8

#### 最低配置
- **CPU**: 2核心
- **内存**: 4GB
- **存储**: 50GB SSD云盘
- **带宽**: 3Mbps

### 2. 环境准备

#### 2.1 安装Docker和Docker Compose

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 添加用户到docker组
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

#### 2.2 配置阿里云Docker镜像加速

```bash
# 创建Docker配置目录
sudo mkdir -p /etc/docker

# 配置镜像加速器
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://reg-mirror.qiniu.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

# 重启Docker服务
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 3. 项目部署

#### 3.1 下载项目代码

```bash
# 创建项目目录
sudo mkdir -p /opt/medical-gpt
cd /opt/medical-gpt

# 克隆项目（或上传项目文件）
# git clone <your-repository-url> .
# 或者直接上传项目文件到服务器

# 设置目录权限
sudo chown -R $USER:$USER /opt/medical-gpt
chmod -R 755 /opt/medical-gpt
```

#### 3.2 配置环境变量

```bash
# 复制环境配置文件
cp gptserver/.env.example gptserver/.env

# 编辑环境配置
vim gptserver/.env
```

**关键配置项说明：**

```env
# 应用配置
APP_NAME=medical-gpt
APP_ENV=production

# 数据库配置（与docker-compose.yml保持一致）
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=gptlink_edu
DB_USERNAME=gptlink
DB_PASSWORD=your_secure_password_here

# Redis配置
REDIS_HOST=redis
REDIS_AUTH=your_redis_password_here
REDIS_PORT=6379

# 管理员账号
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your_admin_password_here
ADMIN_TTL=7200

# OpenAI API配置
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-3.5-turbo
OPENAI_HOST=https://api.openai.com
# 或使用DeepSeek API
# OPENAI_HOST=https://api.deepseek.com
# OPENAI_MODEL=deepseek-chat

# 医疗模式配置
MEDICAL_MODE=true
MEDICAL_TITLE=医疗健康AI助手
MEDICAL_SAFETY_CHECK=true
DAILY_REQUEST_LIMIT=50
SESSION_TIMEOUT=1800
```

#### 3.3 创建阿里云优化的Docker Compose配置

创建 `docker-compose.aliyun.yml`：

```yaml
version: '3.8'

services:
  # MySQL数据库
  mysql:
    image: mysql:8.0
    container_name: medical-gpt-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-your_secure_password}
      MYSQL_DATABASE: gptlink_edu
      MYSQL_USER: gptlink
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-your_secure_password}
      MYSQL_CHARSET: utf8mb4
      MYSQL_COLLATION: utf8mb4_unicode_ci
    volumes:
      - mysql_data:/var/lib/mysql
      - ./docker/mysql/init:/docker-entrypoint-initdb.d
      - ./docker/mysql/conf:/etc/mysql/conf.d
      - ./logs/mysql:/var/log/mysql
    ports:
      - "127.0.0.1:3306:3306"  # 仅本地访问
    networks:
      - medical-gpt
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --sql_mode=STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO
      --max_connections=1000
      --innodb_buffer_pool_size=512M
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  # Redis缓存
  redis:
    image: redis:7-alpine
    container_name: medical-gpt-redis
    restart: unless-stopped
    command: >
      redis-server
      --appendonly yes
      --requirepass ${REDIS_PASSWORD:-your_redis_password}
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
      - ./docker/redis/redis.conf:/usr/local/etc/redis/redis.conf
      - ./logs/redis:/var/log/redis
    ports:
      - "127.0.0.1:6379:6379"  # 仅本地访问
    networks:
      - medical-gpt
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-your_redis_password}", "ping"]
      timeout: 3s
      retries: 5

  # PHP后端服务
  gptserver:
    build:
      context: ./docker/php
      dockerfile: Dockerfile
    container_name: medical-gpt-server
    restart: unless-stopped
    working_dir: /var/www/html
    environment:
      - MEDICAL_MODE=true
      - DB_HOST=mysql
      - DB_DATABASE=gptlink_edu
      - DB_USERNAME=gptlink
      - DB_PASSWORD=${MYSQL_PASSWORD:-your_secure_password}
      - REDIS_HOST=redis
      - REDIS_PASSWORD=${REDIS_PASSWORD:-your_redis_password}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - OPENAI_MODEL=${OPENAI_MODEL:-gpt-3.5-turbo}
      - OPENAI_HOST=${OPENAI_HOST:-https://api.openai.com}
      - OPENAI_MAX_TOKENS=2000
      - OPENAI_TEMPERATURE=0.7
      - MEDICAL_SAFETY_CHECK=true
      - DAILY_REQUEST_LIMIT=50
      - SESSION_TIMEOUT=1800
    volumes:
      - ./gptserver:/var/www/html
      - ./logs/php:/var/log/php
    ports:
      - "127.0.0.1:9000:80"     # 仅本地访问
      - "127.0.0.1:9503:9503"   # 仅本地访问
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - medical-gpt
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      timeout: 10s
      retries: 3
      start_period: 30s

  # Nginx Web服务器
  nginx:
    image: nginx:alpine
    container_name: medical-gpt-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./docker/nginx/conf.d:/etc/nginx/conf.d:ro
      - ./gptweb:/usr/share/nginx/html/web:ro
      - ./gptadmin:/usr/share/nginx/html/admin:ro
      - ./logs/nginx:/var/log/nginx
      - ./ssl_certs:/etc/nginx/ssl:ro
    depends_on:
      - gptserver
    networks:
      - medical-gpt
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      timeout: 3s
      retries: 3

volumes:
  mysql_data:
    driver: local
  redis_data:
    driver: local

networks:
  medical-gpt:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### 4. 安全配置

#### 4.1 防火墙配置

```bash
# 安装UFW防火墙
sudo apt install ufw -y

# 配置防火墙规则
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 启用防火墙
sudo ufw --force enable

# 查看防火墙状态
sudo ufw status
```

#### 4.2 SSL证书配置

```bash
# 安装Certbot
sudo apt install certbot -y

# 申请SSL证书（替换www.medicalgpt.asia为实际域名）
sudo certbot certonly --standalone -d www.medicalgpt.asia

# 复制证书文件
sudo cp /etc/letsencrypt/live/www.medicalgpt.asia/fullchain.pem ./ssl_certs/
sudo cp /etc/letsencrypt/live/www.medicalgpt.asia/privkey.pem ./ssl_certs/
sudo chown $USER:$USER ./ssl_certs/*
```

### 5. 部署执行

#### 5.1 创建部署脚本

创建 `deploy-aliyun.sh`：

```bash
#!/bin/bash

# 阿里云服务器部署脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查环境
check_environment() {
    log_info "检查部署环境..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装"
        exit 1
    fi
    
    # 检查环境变量文件
    if [ ! -f "gptserver/.env" ]; then
        log_error "环境配置文件不存在，请先配置 gptserver/.env"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 创建必要目录
create_directories() {
    log_info "创建必要目录..."
    
    mkdir -p logs/{nginx,mysql,php,redis}
    mkdir -p data/{mysql,redis}
    mkdir -p ssl_certs
    
    # 设置权限
    chmod -R 755 logs/
    chmod -R 755 data/
    
    log_success "目录创建完成"
}

# 部署服务
deploy_services() {
    log_info "部署服务..."
    
    # 停止现有服务
    docker-compose -f docker-compose.aliyun.yml down --remove-orphans
    
    # 拉取最新镜像
    docker-compose -f docker-compose.aliyun.yml pull
    
    # 构建并启动服务
    docker-compose -f docker-compose.aliyun.yml up -d --build
    
    log_success "服务部署完成"
}

# 等待服务启动
wait_for_services() {
    log_info "等待服务启动..."
    
    # 等待MySQL
    log_info "等待MySQL服务..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker-compose -f docker-compose.aliyun.yml exec -T mysql mysqladmin ping -h localhost --silent; then
            break
        fi
        sleep 2
        timeout=$((timeout-2))
    done
    
    if [ $timeout -le 0 ]; then
        log_error "MySQL服务启动超时"
        exit 1
    fi
    
    # 等待Redis
    log_info "等待Redis服务..."
    timeout=30
    while [ $timeout -gt 0 ]; do
        if docker-compose -f docker-compose.aliyun.yml exec -T redis redis-cli -a "${REDIS_PASSWORD:-your_redis_password}" ping > /dev/null 2>&1; then
            break
        fi
        sleep 2
        timeout=$((timeout-2))
    done
    
    if [ $timeout -le 0 ]; then
        log_error "Redis服务启动超时"
        exit 1
    fi
    
    # 等待应用服务
    log_info "等待应用服务..."
    sleep 15
    
    log_success "所有服务已启动"
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 检查服务状态
    if ! docker-compose -f docker-compose.aliyun.yml ps | grep -q "Up"; then
        log_error "部分服务未正常启动"
        docker-compose -f docker-compose.aliyun.yml ps
        exit 1
    fi
    
    # 检查Web访问
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_success "Web服务正常"
    else
        log_warning "Web服务可能未完全就绪，请稍后检查"
    fi
    
    log_success "健康检查完成"
}

# 显示部署信息
show_deployment_info() {
    log_success "医疗健康AI助手部署完成！"
    echo ""
    echo "=== 服务访问信息 ==="
    echo "前端地址: http://$(curl -s ifconfig.me)"
    echo "管理后台: http://$(curl -s ifconfig.me)/admin"
    echo "API接口: http://$(curl -s ifconfig.me)/api"
    echo "健康检查: http://$(curl -s ifconfig.me)/health"
    echo ""
    echo "=== 服务管理命令 ==="
    echo "查看服务状态: docker-compose -f docker-compose.aliyun.yml ps"
    echo "查看日志: docker-compose -f docker-compose.aliyun.yml logs -f"
    echo "停止服务: docker-compose -f docker-compose.aliyun.yml down"
    echo "重启服务: docker-compose -f docker-compose.aliyun.yml restart"
    echo ""
    echo "=== 监控命令 ==="
    echo "系统资源: htop"
    echo "磁盘使用: df -h"
    echo "Docker状态: docker stats"
    echo ""
}

# 主函数
main() {
    echo "=== 医疗健康AI助手 - 阿里云部署脚本 ==="
    echo "开始时间: $(date)"
    echo ""
    
    check_environment
    create_directories
    deploy_services
    wait_for_services
    health_check
    show_deployment_info
    
    log_success "部署完成！"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"
```

#### 5.2 执行部署

```bash
# 设置执行权限
chmod +x deploy-aliyun.sh

# 设置环境变量（可选，也可以在.env文件中配置）
export MYSQL_PASSWORD="your_secure_mysql_password"
export REDIS_PASSWORD="your_secure_redis_password"
export OPENAI_API_KEY="your_openai_api_key"

# 执行部署
./deploy-aliyun.sh
```

### 6. 监控和维护

#### 6.1 日志管理

```bash
# 查看所有服务日志
docker-compose -f docker-compose.aliyun.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.aliyun.yml logs -f nginx
docker-compose -f docker-compose.aliyun.yml logs -f gptserver
docker-compose -f docker-compose.aliyun.yml logs -f mysql
docker-compose -f docker-compose.aliyun.yml logs -f redis

# 查看系统日志
tail -f logs/nginx/access.log
tail -f logs/nginx/error.log
tail -f logs/php/error.log
```

#### 6.2 性能监控

```bash
# 安装监控工具
sudo apt install htop iotop nethogs -y

# 监控系统资源
htop                    # CPU和内存使用情况
iotop                   # 磁盘I/O监控
nethogs                 # 网络使用监控
docker stats            # Docker容器资源使用
```

#### 6.3 备份策略

```bash
# 创建备份脚本
cat > backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/backups/medical-gpt"
DATE=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份数据库
docker-compose -f docker-compose.aliyun.yml exec -T mysql mysqldump -u root -p$MYSQL_PASSWORD --all-databases > $BACKUP_DIR/mysql_$DATE.sql

# 备份Redis数据
docker-compose -f docker-compose.aliyun.yml exec -T redis redis-cli -a $REDIS_PASSWORD --rdb /data/dump_$DATE.rdb
docker cp medical-gpt-redis:/data/dump_$DATE.rdb $BACKUP_DIR/

# 备份配置文件
tar -czf $BACKUP_DIR/config_$DATE.tar.gz gptserver/.env docker/

# 清理7天前的备份
find $BACKUP_DIR -name "*" -mtime +7 -delete

echo "备份完成: $DATE"
EOF

chmod +x backup.sh

# 设置定时备份（每天凌晨2点）
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/medical-gpt/backup.sh") | crontab -
```

### 7. 故障排除

#### 7.1 常见问题

**问题1: 服务无法启动**
```bash
# 检查服务状态
docker-compose -f docker-compose.aliyun.yml ps

# 查看错误日志
docker-compose -f docker-compose.aliyun.yml logs

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

**问题2: 数据库连接失败**
```bash
# 检查MySQL服务
docker-compose -f docker-compose.aliyun.yml exec mysql mysql -u root -p

# 检查网络连接
docker-compose -f docker-compose.aliyun.yml exec gptserver ping mysql
```

**问题3: 内存不足**
```bash
# 检查内存使用
free -h
docker stats

# 清理Docker缓存
docker system prune -f
docker volume prune -f
```

#### 7.2 性能优化

**MySQL优化**
```sql
-- 在MySQL中执行
SET GLOBAL innodb_buffer_pool_size = 512*1024*1024;
SET GLOBAL max_connections = 1000;
SET GLOBAL query_cache_size = 64*1024*1024;
```

**Redis优化**
```bash
# 在redis.conf中添加
maxmemory 256mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

### 8. 安全加固

#### 8.1 系统安全

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装安全更新
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades

# 配置SSH安全
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# 安装fail2ban
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

#### 8.2 应用安全

```bash
# 设置强密码策略
# 在.env文件中使用复杂密码
# 定期更换API密钥
# 启用HTTPS
# 配置防火墙规则
# 定期备份数据
```

### 9. 扩展和升级

#### 9.1 水平扩展

```yaml
# 在docker-compose.aliyun.yml中添加多个后端实例
gptserver-1:
  # ... 配置同gptserver
gptserver-2:
  # ... 配置同gptserver

# 在nginx配置中添加负载均衡
upstream php-backend {
    server gptserver-1:9503;
    server gptserver-2:9503;
}
```

#### 9.2 版本升级

```bash
# 备份当前版本
./backup.sh

# 拉取新版本代码
git pull origin main

# 重新构建和部署
docker-compose -f docker-compose.aliyun.yml down
docker-compose -f docker-compose.aliyun.yml up -d --build

# 执行数据库迁移（如果需要）
docker-compose -f docker-compose.aliyun.yml exec gptserver php artisan migrate
```

## 总结

本部署方案提供了在阿里云服务器上部署医疗健康AI助手的完整解决方案，包括：

1. **完整的环境配置**：从系统准备到Docker安装
2. **优化的容器配置**：针对阿里云环境优化的Docker Compose配置
3. **安全配置**：防火墙、SSL证书、访问控制等
4. **自动化部署**：一键部署脚本
5. **监控和维护**：日志管理、性能监控、备份策略
6. **故障排除**：常见问题解决方案
7. **扩展方案**：水平扩展和版本升级指南

按照本方案执行，可以在阿里云服务器上快速、安全地部署医疗健康AI助手系统。