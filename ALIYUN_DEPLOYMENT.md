# 医疗健康AI助手 - 阿里云服务器部署指南

## 概述

本指南基于本地成功部署经验，提供在阿里云服务器上部署医疗健康AI助手的完整流程。

**域名**: `medicalgpt.asia`  
**部署方式**: Docker Compose  
**SSL证书**: Let's Encrypt 自动申请  
**反向代理**: Nginx  

## 系统要求

### 服务器配置
- **操作系统**: CentOS 7/8 或 Ubuntu 18.04/20.04
- **内存**: 最少 2GB，推荐 4GB
- **存储**: 最少 20GB，推荐 50GB
- **CPU**: 最少 2核，推荐 4核
- **网络**: 公网IP，带宽不少于5Mbps

### 域名配置
- 确保域名 `medicalgpt.asia` 已解析到服务器公网IP
- 建议同时配置 `www.medicalgpt.asia` 子域名

## 快速部署

### 1. 准备服务器

```bash
# 更新系统
yum update -y  # CentOS
# 或
apt update && apt upgrade -y  # Ubuntu

# 安装基础工具
yum install -y git curl wget vim net-tools  # CentOS
# 或
apt install -y git curl wget vim net-tools  # Ubuntu
```

### 2. 上传代码

```bash
# 创建应用目录
mkdir -p /opt/medical-gpt
cd /opt/medical-gpt

# 方式1: 使用Git克隆（推荐）
git clone <your-repository-url> .

# 方式2: 手动上传文件
# 将本地项目文件上传到 /opt/medical-gpt 目录
```

### 3. 配置环境变量

```bash
# 复制环境配置文件
cp .env.aliyun .env

# 编辑配置文件
vim .env
```

**重要配置项**:
```bash
# 数据库密码（必须修改）
MYSQL_ROOT_PASSWORD=your_secure_mysql_root_password_here
MYSQL_PASSWORD=your_secure_mysql_password_here

# Redis密码（必须修改）
REDIS_PASSWORD=your_secure_redis_password_here

# API密钥（必须配置）
OPENAI_API_KEY=your_deepseek_api_key_here

# JWT密钥（必须修改）
JWT_SECRET=your_jwt_secret_key_here
ENCRYPTION_KEY=your_encryption_key_here

# 邮件配置（可选）
MAIL_USERNAME=your_email@aliyun.com
MAIL_PASSWORD=your_email_password
```

### 4. 执行部署脚本

```bash
# 给脚本执行权限
chmod +x deploy-aliyun.sh

# 执行部署（需要root权限）
sudo ./deploy-aliyun.sh
```

## 手动部署步骤

如果自动部署脚本遇到问题，可以按以下步骤手动部署：

### 1. 安装Docker

```bash
# CentOS
yum remove -y docker docker-client docker-client-latest docker-common
yum install -y yum-utils
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker

# Ubuntu
apt remove -y docker docker-engine docker.io containerd runc
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
```

### 2. 安装Docker Compose

```bash
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
```

### 3. 配置Docker镜像加速

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF
systemctl restart docker
```

### 4. 申请SSL证书

```bash
# 安装certbot
yum install -y epel-release certbot  # CentOS
# 或
apt install -y certbot  # Ubuntu

# 申请证书
certbot certonly --standalone -d medicalgpt.asia -d www.medicalgpt.asia --email admin@medicalgpt.asia --agree-tos --non-interactive

# 设置自动续期
echo "0 2 * * * root certbot renew --quiet && docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml restart nginx" >> /etc/crontab
```

### 5. 配置防火墙

```bash
# CentOS (firewalld)
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload

# Ubuntu (ufw)
ufw enable
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
```

### 6. 启动服务

```bash
cd /opt/medical-gpt

# 创建必要目录
mkdir -p logs/{nginx,php,mysql,redis}
mkdir -p data/{mysql,redis}

# 设置权限
chown -R 1000:1000 logs data
chmod -R 755 logs data

# 启动服务
docker-compose -f docker-compose.aliyun.yml up -d
```

## 服务管理

### 常用命令

```bash
# 查看服务状态
docker-compose -f docker-compose.aliyun.yml ps

# 查看日志
docker-compose -f docker-compose.aliyun.yml logs -f

# 重启服务
docker-compose -f docker-compose.aliyun.yml restart

# 停止服务
docker-compose -f docker-compose.aliyun.yml down

# 更新服务
docker-compose -f docker-compose.aliyun.yml pull
docker-compose -f docker-compose.aliyun.yml up -d
```

### 服务端口

- **Nginx**: 80 (HTTP), 443 (HTTPS)
- **PHP后端**: 9503 (内部)
- **MySQL**: 3306 (内部)
- **Redis**: 6379 (内部)

## 访问地址

部署完成后，可通过以下地址访问：

- **前端界面**: https://medicalgpt.asia/web/
- **管理后台**: https://medicalgpt.asia/admin/
- **API接口**: https://medicalgpt.asia/api/

## 监控和维护

### 日志位置

- **Nginx日志**: `/opt/medical-gpt/logs/nginx/`
- **PHP日志**: `/opt/medical-gpt/logs/php/`
- **MySQL日志**: `/opt/medical-gpt/logs/mysql/`
- **Redis日志**: `/opt/medical-gpt/logs/redis/`

### 数据备份

```bash
# 数据库备份
docker exec medical-gpt-mysql mysqldump -u root -p gptlink_edu > backup_$(date +%Y%m%d).sql

# Redis备份
docker exec medical-gpt-redis redis-cli BGSAVE
```

### 性能监控

```bash
# 查看容器资源使用
docker stats

# 查看系统资源
top
df -h
free -h
```

## 故障排除

### 常见问题

1. **容器启动失败**
   ```bash
   # 查看详细错误信息
   docker-compose -f docker-compose.aliyun.yml logs [service_name]
   ```

2. **SSL证书问题**
   ```bash
   # 检查证书状态
   certbot certificates
   
   # 手动续期
   certbot renew
   ```

3. **端口占用**
   ```bash
   # 查看端口占用
   netstat -tlnp | grep :80
   netstat -tlnp | grep :443
   ```

4. **权限问题**
   ```bash
   # 修复文件权限
   chown -R 1000:1000 /opt/medical-gpt/logs
   chown -R 1000:1000 /opt/medical-gpt/data
   ```

### 日志分析

```bash
# 查看Nginx访问日志
tail -f /opt/medical-gpt/logs/nginx/access.log

# 查看Nginx错误日志
tail -f /opt/medical-gpt/logs/nginx/error.log

# 查看PHP错误日志
tail -f /opt/medical-gpt/logs/php/error.log
```

## 安全建议

1. **定期更新系统和Docker镜像**
2. **使用强密码**
3. **启用防火墙**
4. **定期备份数据**
5. **监控系统资源和日志**
6. **限制SSH访问**
7. **使用非root用户运行应用**

## 性能优化

1. **调整PHP配置**
   - 增加内存限制
   - 优化OPcache设置

2. **优化MySQL配置**
   - 调整缓冲池大小
   - 优化查询缓存

3. **配置Redis持久化**
   - 启用AOF持久化
   - 调整内存策略

4. **Nginx优化**
   - 启用Gzip压缩
   - 配置静态文件缓存
   - 调整工作进程数

## 联系支持

如果在部署过程中遇到问题，请：

1. 检查日志文件
2. 确认配置文件正确
3. 验证网络连接
4. 查看系统资源使用情况

---

**注意**: 请确保在生产环境中修改所有默认密码和密钥，并定期进行安全更新。