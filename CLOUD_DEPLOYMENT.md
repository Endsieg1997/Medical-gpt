# 医疗健康AI助手 - 云服务器部署指南

## 概述

本指南将帮助您在云服务器上部署医疗健康AI助手，使其能够通过互联网对外提供服务。

## 系统要求

### 最低配置
- **CPU**: 2核心
- **内存**: 4GB RAM
- **存储**: 20GB 可用空间
- **操作系统**: Ubuntu 18.04+ / CentOS 7+ / Debian 9+
- **网络**: 公网IP地址

### 推荐配置
- **CPU**: 4核心
- **内存**: 8GB RAM
- **存储**: 50GB SSD
- **带宽**: 5Mbps+

## 快速部署

### 方法一：一键部署脚本

```bash
# 1. 下载项目
git clone https://github.com/your-repo/Medical-gpt.git
cd Medical-gpt

# 2. 运行云服务器部署脚本
chmod +x deploy-cloud.sh
./deploy-cloud.sh
```

### 方法二：手动部署

#### 1. 环境准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以应用docker组权限
logout
```

#### 2. 配置网络安全组

请在云服务器控制台配置安全组，开放以下端口：
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)

#### 3. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑配置文件
nano .env
```

**重要配置项：**

```bash
# 应用URL（替换为您的域名或IP）
APP_URL=http://medicalgpt.asia

# DeepSeek API配置
OPENAI_API_KEY=your-deepseek-api-key
OPENAI_MODEL=deepseek-chat
OPENAI_HOST=https://api.deepseek.com

# 安全配置
MED_ENABLE_IP_LIMIT=false  # 生产环境建议关闭IP限制
MED_CONTENT_FILTER=true    # 启用内容过滤

# 数据库密码（建议修改）
DB_PASSWORD=your-secure-password
REDIS_PASSWORD=your-redis-password
```

#### 4. 配置域名（可选）

如果您有域名，请修改以下文件：

**docker/nginx/conf.d/medical-gpt.conf**
```nginx
server_name medicalgpt.asia *.medicalgpt.asia;
```

#### 5. 启动服务

```bash
# 创建必要目录
mkdir -p logs/{nginx,mysql,php} data/{mysql,redis} ssl_certs

# 启动服务
docker-compose up -d --build

# 查看服务状态
docker-compose ps
```

## SSL证书配置

### 使用Let's Encrypt免费证书

```bash
# 安装certbot
sudo apt install certbot  # Ubuntu/Debian
sudo yum install certbot  # CentOS/RHEL

# 申请证书（确保域名已解析到服务器）
sudo certbot certonly --standalone -d medicalgpt.asia

# 复制证书到项目目录
sudo cp /etc/letsencrypt/live/medicalgpt.asia/fullchain.pem ssl_certs/cert.pem
sudo cp /etc/letsencrypt/live/medicalgpt.asia/privkey.pem ssl_certs/key.pem
sudo chown $USER:$USER ssl_certs/*.pem

# 启用HTTPS配置
# 编辑 docker/nginx/conf.d/medical-gpt.conf，取消HTTPS部分的注释

# 重启服务
docker-compose restart nginx
```

### 证书自动续期

```bash
# 添加定时任务
crontab -e

# 添加以下行（每月1号凌晨2点检查续期）
0 2 1 * * /usr/bin/certbot renew --quiet && docker-compose restart nginx
```

## 域名解析配置

在您的域名服务商处添加以下DNS记录：

```
类型    名称              值
A       @                服务器公网IP
A       www              服务器公网IP
CNAME   medical          medicalgpt.asia
```

## 安全配置

### 1. 修改默认密码

```bash
# 修改.env文件中的密码
ADMIN_PASSWORD=your-secure-admin-password
DB_PASSWORD=your-secure-db-password
REDIS_PASSWORD=your-secure-redis-password

# 重启服务应用配置
docker-compose restart
```

### 2. 配置IP白名单（可选）

```bash
# 在.env文件中配置
MED_ENABLE_IP_LIMIT=true
MED_IP_WHITELIST="192.168.1.0/24,10.0.0.0/8"
```

### 3. 启用内容过滤

```bash
# 在.env文件中配置
MED_CONTENT_FILTER=true
MED_BLOCKED_KEYWORDS='["药物滥用","自杀","暴力","违法","毒品","自残"]'
```

## 监控和维护

### 查看服务状态

```bash
# 查看所有服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f nginx
docker-compose logs -f gptserver
```

### 备份数据

```bash
# 备份MySQL数据
docker-compose exec mysql mysqldump -u root -p666666 gptlink_edu > backup_$(date +%Y%m%d).sql

# 备份Redis数据
docker-compose exec redis redis-cli -a 666666 --rdb /data/backup_$(date +%Y%m%d).rdb
```

### 更新服务

```bash
# 拉取最新镜像
docker-compose pull

# 重新构建并启动
docker-compose up -d --build

# 清理旧镜像
docker image prune -f
```

## 性能优化

### 1. Nginx优化

编辑 `docker/nginx/nginx.conf`：

```nginx
worker_processes auto;
worker_connections 2048;

# 启用gzip压缩
gzip on;
gzip_comp_level 6;
gzip_types text/plain text/css application/json application/javascript;

# 缓存配置
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=10g inactive=60m;
```

### 2. MySQL优化

编辑 `docker/mysql/conf/my.cnf`：

```ini
[mysqld]
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
max_connections = 200
query_cache_size = 64M
```

### 3. Redis优化

编辑 `docker/redis/redis.conf`：

```
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
```

## 故障排查

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查端口占用
   sudo netstat -tlnp | grep :80
   
   # 检查Docker服务
   sudo systemctl status docker
   ```

2. **无法访问网站**
   ```bash
   # 检查端口开放状态
netstat -tlnp | grep -E ':(80|443|22)'
   
   # 检查Nginx配置
   docker-compose exec nginx nginx -t
   ```

3. **数据库连接失败**
   ```bash
   # 检查MySQL服务
   docker-compose logs mysql
   
   # 测试数据库连接
   docker-compose exec mysql mysql -u gptlink -p666666 gptlink_edu
   ```

### 日志位置

- Nginx日志: `logs/nginx/`
- PHP日志: `logs/php/`
- MySQL日志: `docker-compose logs mysql`
- Redis日志: `docker-compose logs redis`

## 扩展配置

### 多域名支持

在Nginx配置中添加多个域名：

```nginx
server_name domain1.com domain2.com domain3.com;
```

### 负载均衡

如需处理大量请求，可配置多个后端实例：

```yaml
# docker-compose.yml
gptserver1:
  # ... 配置
gptserver2:
  # ... 配置

nginx:
  # 在nginx配置中添加upstream
```

## 联系支持

如果在部署过程中遇到问题，请：

1. 查看本文档的故障排查部分
2. 检查项目的GitHub Issues
3. 联系技术支持团队

---

**注意**: 请确保遵守相关法律法规，医疗AI助手仅供参考，不能替代专业医疗诊断。