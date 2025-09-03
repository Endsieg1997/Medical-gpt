# 快速开始指南

本指南将帮助您快速在云服务器上部署医疗健康AI助手。

## 🚀 一键部署（推荐）

### Linux/macOS 云服务器

```bash
# 1. 克隆项目
git clone https://github.com/your-repo/medical-gpt.git
cd medical-gpt

# 2. 运行一键部署脚本
chmod +x deploy-cloud.sh
./deploy-cloud.sh
```

### Windows 服务器

```cmd
# 1. 克隆项目
git clone https://github.com/your-repo/medical-gpt.git
cd medical-gpt

# 2. 运行快速部署脚本
quick-deploy.bat
```

## 📋 部署前准备

### 系统要求
- **操作系统**: Ubuntu 18.04+, CentOS 7+, Windows Server 2019+
- **内存**: 最少 2GB，推荐 4GB+
- **存储**: 最少 10GB 可用空间
- **网络**: 需要访问外网（用于拉取 Docker 镜像和 API 调用）

### 必需软件
- Docker 20.10+
- Docker Compose 2.0+

### API Key 准备
获取 DeepSeek API Key：
1. 访问 [DeepSeek 官网](https://platform.deepseek.com/)
2. 注册账号并获取 API Key
3. 确保账户有足够余额

## ⚙️ 配置说明

### 域名配置
部署脚本会提示您输入域名，支持：
- 完整域名：`medicalgpt.asia`
- IP 地址：`123.456.789.012`
- 本地测试：`localhost`

### 环境变量
关键配置项：
```env
# 应用配置
APP_URL=http://medicalgpt.asia
APP_ENV=production

# DeepSeek AI 配置
DEEPSEEK_API_KEY=your-api-key-here
DEEPSEEK_MODEL=deepseek-chat

# 数据库配置（自动生成）
DB_HOST=mysql
DB_DATABASE=medical_gpt
DB_USERNAME=medical_user
DB_PASSWORD=auto-generated-password

# 管理员配置
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password
```

## 🔧 部署后操作

### 1. 验证部署
```bash
# 检查服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f

# 运行网络检查
./check-network.sh
```

### 2. 访问应用
- **前端界面**: `http://medicalgpt.asia`
- **管理后台**: `http://medicalgpt.asia/admin`
- **API 文档**: `http://medicalgpt.asia/api/docs`
- **健康检查**: `http://medicalgpt.asia/health`

### 3. 管理员登录
- 用户名：`admin`（或自定义）
- 密码：部署时设置的密码

## 🛡️ 安全配置

### 网络配置
请确保云服务器安全组已开放必要端口：
- 80 (HTTP)
- 443 (HTTPS)
- 22 (SSH)

### SSL 证书
```bash
# 自动申请 Let's Encrypt 证书
./deploy-cloud.sh --ssl

# 或手动配置
sudo certbot --nginx -d medicalgpt.asia
```

## 📊 监控和维护

### 查看日志
```bash
# 应用日志
docker-compose logs app

# Nginx 日志
docker-compose logs nginx

# 数据库日志
docker-compose logs mysql
```

### 备份数据
```bash
# 备份数据库
docker-compose exec mysql mysqldump -u medical_user -p medical_gpt > backup.sql

# 备份上传文件
tar -czf uploads_backup.tar.gz ./data/uploads/
```

### 更新应用
```bash
# 拉取最新代码
git pull origin main

# 重新构建并启动
docker-compose down
docker-compose up -d --build
```

## 🔍 故障排查

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :80
   
   # 检查 Docker 状态
   systemctl status docker
   ```

2. **API 调用失败**
   ```bash
   # 检查 API Key 配置
   docker-compose exec app cat .env | grep DEEPSEEK
   
   # 测试网络连接
   curl -I https://api.deepseek.com
   ```

3. **数据库连接失败**
   ```bash
   # 检查数据库状态
   docker-compose exec mysql mysql -u root -p -e "SHOW DATABASES;"
   ```

### 获取帮助
- 查看详细文档：[CLOUD_DEPLOYMENT.md](./CLOUD_DEPLOYMENT.md)
- 运行诊断工具：`./check-network.sh`
- 提交问题：[GitHub Issues](https://github.com/your-repo/medical-gpt/issues)

## 📞 技术支持

如果遇到问题，请：
1. 首先运行 `./check-network.sh` 进行自动诊断
2. 查看相关日志文件
3. 搜索已知问题和解决方案
4. 提交详细的问题报告

---

🎉 **恭喜！** 您已成功部署医疗健康AI助手。开始体验智能医疗对话服务吧！