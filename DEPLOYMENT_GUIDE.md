# 医疗健康AI助手 - 云服务器部署指南

## 📋 部署前检查清单

### 系统要求
- [ ] Linux 操作系统 (Ubuntu 18.04+ / CentOS 7+ 推荐)
- [ ] 至少 2GB 内存
- [ ] 至少 10GB 可用磁盘空间
- [ ] 稳定的网络连接
- [ ] 具有 sudo 权限的用户账号

### 必要文件检查
- [ ] `.env` 文件存在且配置正确
- [ ] `docker-compose.yml` 配置文件
- [ ] `gptserver/composer.json` 和 `composer.lock`
- [ ] `docker/php/Dockerfile`
- [ ] `docker/nginx/nginx.conf`
- [ ] 所有必要的配置文件

### 环境变量配置
- [ ] `OPENAI_API_KEY` - DeepSeek API 密钥
- [ ] `DB_PASSWORD` - 数据库密码
- [ ] `REDIS_PASSWORD` - Redis 密码
- [ ] `APP_URL` - 应用访问地址
- [ ] 其他必要的环境变量

## 🚀 快速部署

### 方法一：一键部署（推荐）

```bash
# 1. 下载项目到服务器
git clone <repository-url>
cd Medical-gpt

# 2. 运行一键部署脚本
./quick-deploy.sh
```

### 方法二：分步部署

#### 步骤 1：部署前检查
```bash
# 运行部署前检查脚本
./pre-deploy-check.sh
```

#### 步骤 2：配置环境
```bash
# 复制环境变量文件
cp .env.example .env

# 编辑环境变量
vim .env
```

#### 步骤 3：执行部署
```bash
# 运行部署脚本
./deploy-cloud.sh
```

## ⚙️ 详细配置说明

### 环境变量配置

#### 必须配置的变量
```bash
# DeepSeek API 配置
OPENAI_API_KEY=sk-your-api-key-here
OPENAI_MODEL=deepseek-chat
OPENAI_HOST=https://api.deepseek.com

# 数据库配置
DB_HOST=mysql
DB_DATABASE=gptlink_edu
DB_USERNAME=gptlink
DB_PASSWORD=your-secure-password

# Redis 配置
REDIS_HOST=redis
REDIS_PASSWORD=your-secure-password

# 应用配置
APP_URL=http://your-domain.com
MEDICAL_MODE=true
```

#### 可选配置的变量
```bash
# 医疗功能限制
MED_MAX_DAILY_REQUESTS=50
MED_CONTENT_FILTER=true
MED_ENABLE_REGISTRATION=true

# 会话配置
SESSION_LIFETIME=120

# 管理员配置
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-admin-password
```

### Docker 服务配置

#### 服务端口映射
- **Web 服务**: 80 (HTTP), 443 (HTTPS)
- **MySQL**: 3306
- **Redis**: 6379
- **PHP**: 9000, 9503

#### 数据卷挂载
- `mysql_data`: MySQL 数据持久化
- `redis_data`: Redis 数据持久化
- `nginx_logs`: Nginx 日志
- `ssl_certs`: SSL 证书存储

## 🔧 部署后配置

### SSL 证书配置（推荐）

```bash
# 安装 certbot
sudo apt-get install certbot

# 申请 SSL 证书
sudo certbot certonly --standalone -d your-domain.com

# 复制证书到项目目录
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl_certs/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl_certs/key.pem
sudo chown $USER:$USER ssl_certs/*.pem

# 更新 APP_URL 为 HTTPS
sed -i 's|http://|https://|g' .env

# 重启服务
docker-compose restart nginx
```

### 防火墙配置

```bash
# Ubuntu/Debian
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

## 📊 服务管理

### 常用命令

```bash
# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f

# 重启所有服务
docker-compose restart

# 重启单个服务
docker-compose restart gptserver

# 停止所有服务
docker-compose down

# 更新并重启服务
docker-compose down
docker-compose pull
docker-compose up -d
```

### 健康检查

```bash
# 检查服务健康状态
curl -f http://localhost/health

# 检查数据库连接
docker-compose exec gptserver php artisan tinker
# 在 tinker 中执行: DB::connection()->getPdo()

# 检查 Redis 连接
docker-compose exec redis redis-cli ping
```

## 🛠️ 故障排除

### 常见问题

#### 1. 服务启动失败
```bash
# 查看详细日志
docker-compose logs gptserver

# 检查配置文件
docker-compose config

# 重新构建镜像
docker-compose build --no-cache
```

#### 2. 数据库连接失败
```bash
# 检查 MySQL 服务状态
docker-compose logs mysql

# 验证环境变量
grep DB_ .env

# 手动连接测试
docker-compose exec mysql mysql -u gptlink -p gptlink_edu
```

#### 3. Redis 连接失败
```bash
# 检查 Redis 服务状态
docker-compose logs redis

# 测试 Redis 连接
docker-compose exec redis redis-cli -a your-password ping
```

#### 4. Nginx 配置错误
```bash
# 测试 Nginx 配置
docker-compose exec nginx nginx -t

# 重新加载配置
docker-compose exec nginx nginx -s reload
```

### 性能优化

#### 1. PHP 优化
```bash
# 调整 PHP 配置
vim docker/php/php.ini

# 重要参数：
# memory_limit = 256M
# max_execution_time = 300
# upload_max_filesize = 20M
```

#### 2. MySQL 优化
```bash
# 调整 MySQL 配置
vim docker/mysql/conf/my.cnf

# 重要参数：
# innodb_buffer_pool_size = 128M
# max_connections = 100
```

#### 3. Redis 优化
```bash
# 调整 Redis 配置
vim docker/redis/redis.conf

# 重要参数：
# maxmemory 128mb
# maxmemory-policy allkeys-lru
```

## 🔒 安全建议

### 1. 密码安全
- 修改所有默认密码
- 使用强密码（至少12位，包含大小写字母、数字、特殊字符）
- 定期更换密码

### 2. 网络安全
- 配置防火墙，只开放必要端口
- 使用 SSL/TLS 加密
- 考虑使用 VPN 或私有网络

### 3. 系统安全
- 定期更新系统和软件包
- 禁用不必要的服务
- 配置日志监控

### 4. 应用安全
- 定期备份数据
- 监控异常访问
- 限制 API 调用频率

## 📈 监控和维护

### 日志管理
```bash
# 查看应用日志
tail -f logs/php/app.log

# 查看 Nginx 访问日志
tail -f logs/nginx/access.log

# 查看错误日志
tail -f logs/nginx/error.log
```

### 数据备份
```bash
# 备份数据库
docker-compose exec mysql mysqldump -u root -p gptlink_edu > backup_$(date +%Y%m%d).sql

# 备份 Redis 数据
docker-compose exec redis redis-cli --rdb /data/backup_$(date +%Y%m%d).rdb

# 备份配置文件
tar -czf config_backup_$(date +%Y%m%d).tar.gz .env docker/
```

### 系统监控
```bash
# 监控系统资源
htop
df -h
free -h

# 监控 Docker 资源使用
docker stats

# 监控服务状态
watch docker-compose ps
```

## 📞 技术支持

如果在部署过程中遇到问题，请：

1. 查看本文档的故障排除部分
2. 检查服务日志获取详细错误信息
3. 确认所有配置文件和环境变量正确
4. 联系技术支持团队

---

**注意**: 本指南适用于生产环境部署，请确保在部署前充分测试所有功能。