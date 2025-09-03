# 医疗健康AI助手 - 云服务器部署指南

## 概述

本指南将帮助您在云服务器上部署医疗健康AI助手，使用域名 `medicalgpt.asia` 提供服务。

## 部署架构

```
┌─────────────────────────────────────────────────────────────┐
│                    云服务器部署架构                          │
├─────────────────────────────────────────────────────────────┤
│  Internet → Nginx (80/443) → PHP Backend → MySQL/Redis    │
│                     │                                       │
│                     └── Static Files (Web UI)              │
└─────────────────────────────────────────────────────────────┘
```

## 系统要求

### 硬件要求
- **CPU**: 2核心以上
- **内存**: 4GB以上
- **存储**: 20GB以上可用空间
- **网络**: 公网IP，带宽建议5Mbps以上

### 软件要求
- **操作系统**: Ubuntu 20.04+ / CentOS 7+ / Debian 10+
- **Docker**: 20.10+
- **Docker Compose**: 1.29+
- **域名**: medicalgpt.asia（需要解析到服务器IP）

## 快速部署

### 1. 准备工作

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y  # Ubuntu/Debian
# 或
sudo yum update -y  # CentOS

# 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以应用 Docker 组权限
exit
```

### 2. 下载项目

```bash
# 克隆项目（如果使用 Git）
git clone <repository-url> medical-gpt
cd medical-gpt

# 或者上传项目文件到服务器
# 使用 scp、rsync 或其他方式
```

### 3. 配置环境

```bash
# 复制环境配置文件
cp .env.cloud .env.production

# 编辑配置文件
nano .env.production
```

**重要配置项**：
```bash
# 数据库密码（必须修改）
MYSQL_ROOT_PASSWORD=your_secure_mysql_root_password
MYSQL_PASSWORD=your_secure_mysql_password

# Redis 密码（必须修改）
REDIS_PASSWORD=your_secure_redis_password

# OpenAI API 配置（必须配置）
OPENAI_API_KEY=your_openai_api_key

# 管理员账户（必须修改）
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your_secure_admin_password

# JWT 和加密密钥（必须修改）
JWT_SECRET=your_jwt_secret_key
ENCRYPTION_KEY=your_encryption_key
```

### 4. 配置 SSL 证书

#### 方式一：使用 Let's Encrypt（推荐）

```bash
# 安装 Certbot
sudo apt install certbot  # Ubuntu/Debian
# 或
sudo yum install certbot  # CentOS

# 获取证书
sudo certbot certonly --standalone -d medicalgpt.asia

# 复制证书到项目目录
sudo cp /etc/letsencrypt/live/medicalgpt.asia/fullchain.pem ssl_certs/medicalgpt.asia.crt
sudo cp /etc/letsencrypt/live/medicalgpt.asia/privkey.pem ssl_certs/medicalgpt.asia.key
sudo chown $USER:$USER ssl_certs/*
```

#### 方式二：使用自有证书

```bash
# 将证书文件放置到指定位置
cp your-certificate.crt ssl_certs/medicalgpt.asia.crt
cp your-private-key.key ssl_certs/medicalgpt.asia.key
chmod 644 ssl_certs/medicalgpt.asia.crt
chmod 600 ssl_certs/medicalgpt.asia.key
```

### 5. 一键部署

```bash
# 给部署脚本执行权限
chmod +x deploy-cloud.sh

# 运行部署脚本
./deploy-cloud.sh
```

### 6. 手动部署（可选）

如果不使用自动部署脚本，可以手动执行：

```bash
# 创建必要目录
mkdir -p data/{mysql,redis} logs/{nginx,php,mysql,redis} ssl_certs

# 构建和启动服务
docker-compose --env-file .env.production -f docker-compose.cloud.yml build
docker-compose --env-file .env.production -f docker-compose.cloud.yml up -d

# 查看服务状态
docker-compose -f docker-compose.cloud.yml ps
```

## 域名配置

### DNS 解析设置

在您的域名管理面板中添加以下记录：

```
类型    名称              值
A       medicalgpt.asia   您的服务器IP
A       www               您的服务器IP（可选）
```

### 验证域名解析

```bash
# 检查域名解析
nslookup medicalgpt.asia
ping medicalgpt.asia
```

## 防火墙配置

### Ubuntu/Debian (UFW)

```bash
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

### CentOS/RHEL (Firewalld)

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 阿里云安全组

在阿里云控制台配置安全组规则：

| 方向 | 协议 | 端口范围 | 授权对象 | 描述 |
|------|------|----------|----------|------|
| 入方向 | TCP | 22 | 0.0.0.0/0 | SSH |
| 入方向 | TCP | 80 | 0.0.0.0/0 | HTTP |
| 入方向 | TCP | 443 | 0.0.0.0/0 | HTTPS |

## 服务管理

### 常用命令

```bash
# 查看服务状态
docker-compose -f docker-compose.cloud.yml ps

# 查看日志
docker-compose -f docker-compose.cloud.yml logs -f

# 重启服务
docker-compose -f docker-compose.cloud.yml restart

# 停止服务
docker-compose -f docker-compose.cloud.yml down

# 更新服务
docker-compose -f docker-compose.cloud.yml pull
docker-compose -f docker-compose.cloud.yml up -d
```

### 健康检查

```bash
# 检查服务健康状态
curl -f https://medicalgpt.asia/health

# 检查各个服务
docker-compose -f docker-compose.cloud.yml exec nginx nginx -t
docker-compose -f docker-compose.cloud.yml exec gptserver php -v
```

## 监控和维护

### 日志管理

```bash
# 查看 Nginx 访问日志
tail -f logs/nginx/access.log

# 查看 Nginx 错误日志
tail -f logs/nginx/error.log

# 查看 PHP 错误日志
tail -f logs/php/error.log

# 清理日志（定期执行）
find logs/ -name "*.log" -mtime +30 -delete
```

### 数据备份

```bash
# 备份数据库
docker-compose -f docker-compose.cloud.yml exec mysql mysqldump -u root -p gptlink_edu > backup_$(date +%Y%m%d).sql

# 备份整个数据目录
tar -czf backup_data_$(date +%Y%m%d).tar.gz data/
```

### SSL 证书续期

```bash
# Let's Encrypt 证书续期
sudo certbot renew --dry-run

# 设置自动续期
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

## 性能优化

### 系统优化

```bash
# 调整系统参数
echo 'net.core.somaxconn = 65535' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog = 65535' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Docker 优化

```bash
# 清理无用的 Docker 资源
docker system prune -f

# 设置 Docker 日志轮转
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker
```

## 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查端口占用
   sudo netstat -tulpn | grep :80
   sudo netstat -tulpn | grep :443
   
   # 检查 Docker 服务
   sudo systemctl status docker
   ```

2. **SSL 证书问题**
   ```bash
   # 检查证书文件
   openssl x509 -in ssl_certs/medicalgpt.asia.crt -text -noout
   
   # 验证证书和私钥匹配
   openssl x509 -noout -modulus -in ssl_certs/medicalgpt.asia.crt | openssl md5
   openssl rsa -noout -modulus -in ssl_certs/medicalgpt.asia.key | openssl md5
   ```

3. **数据库连接问题**
   ```bash
   # 检查数据库服务
   docker-compose -f docker-compose.cloud.yml exec mysql mysql -u root -p -e "SHOW DATABASES;"
   ```

4. **域名解析问题**
   ```bash
   # 检查 DNS 解析
   dig medicalgpt.asia
   nslookup medicalgpt.asia
   ```

### 日志分析

```bash
# 分析访问日志
awk '{print $1}' logs/nginx/access.log | sort | uniq -c | sort -nr | head -10

# 分析错误日志
grep -i error logs/nginx/error.log | tail -20
```

## 安全建议

1. **定期更新系统和软件**
2. **使用强密码和密钥**
3. **启用防火墙**
4. **定期备份数据**
5. **监控系统日志**
6. **限制 SSH 访问**
7. **使用 HTTPS**
8. **定期更新 SSL 证书**

## 联系支持

如果在部署过程中遇到问题，请：

1. 检查本文档的故障排除部分
2. 查看系统日志和应用日志
3. 确认配置文件的正确性
4. 验证网络和防火墙设置

---

**部署完成后，您可以通过以下地址访问服务：**

- 🌐 **主站**: https://medicalgpt.asia
- 🔧 **管理后台**: https://medicalgpt.asia/admin/
- 📊 **健康检查**: https://medicalgpt.asia/health

祝您部署顺利！🎉