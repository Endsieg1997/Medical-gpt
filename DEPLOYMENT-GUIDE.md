# Medical GPT 部署指南

本指南提供了多种部署 Medical GPT 的方法，确保在各种环境下都能成功部署。

## 🚀 快速开始

### 推荐部署流程

1. **环境验证**（推荐第一步）
   ```bash
   ./validate-environment.sh
   ```

2. **选择部署方式**
   - **稳定部署**（推荐）：`./deploy-cloud.sh`
   - **增强部署**：`./quick-deploy-enhanced.sh`
   - **简化部署**：`./quick-deploy.sh`
   - **智能回退**：`./deploy-fallback.sh auto`

## 📋 部署脚本说明

### 1. validate-environment.sh
**环境验证脚本** - 部署前必备检查

- ✅ 检查系统依赖（Docker、Docker Compose等）
- ✅ 验证系统资源（磁盘空间、内存）
- ✅ 检查端口占用情况
- ✅ 验证项目配置文件

```bash
# 运行环境验证
./validate-environment.sh
```

### 2. deploy-cloud.sh
**稳定部署脚本** - 生产环境推荐

- ✅ 兼容性最好，支持新旧版本 Docker Compose
- ✅ 错误处理完善
- ✅ 适合生产环境

```bash
# 稳定部署
./deploy-cloud.sh
```

### 3. quick-deploy-enhanced.sh
**增强部署脚本** - 功能最全面

- ✅ 自动安装 Docker 和 Docker Compose
- ✅ 智能检测系统环境
- ✅ 优化的错误处理和恢复建议
- ✅ 详细的部署日志

```bash
# 增强部署
./quick-deploy-enhanced.sh
```

### 4. deploy-fallback.sh
**智能回退脚本** - 问题解决专家

- ✅ 多种部署方法自动尝试
- ✅ 诊断和修复常见问题
- ✅ 最小化部署选项
- ✅ 创建 Docker Compose 别名

```bash
# 自动选择最佳部署方法
./deploy-fallback.sh auto

# 诊断和修复问题
./deploy-fallback.sh diagnose

# 最小化部署
./deploy-fallback.sh minimal

# 查看所有选项
./deploy-fallback.sh help
```

## 🔧 常见问题解决

### 问题1: "docker compose: command not found"

**解决方案：**
```bash
# 方法1: 使用稳定部署脚本
./deploy-cloud.sh

# 方法2: 创建别名
./deploy-fallback.sh alias

# 方法3: 使用回退脚本
./deploy-fallback.sh auto
```

### 问题2: 端口被占用

**解决方案：**
```bash
# 检查端口占用
netstat -tulnp | grep -E ':(8080|3306|6379)'

# 停止占用端口的服务
sudo systemctl stop mysql  # 如果MySQL占用3306端口
sudo systemctl stop redis  # 如果Redis占用6379端口

# 或者修改.env文件中的端口配置
```

### 问题3: Docker服务未运行

**解决方案：**
```bash
# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 添加用户到docker组
sudo usermod -aG docker $USER
newgrp docker
```

### 问题4: 磁盘空间不足

**解决方案：**
```bash
# 清理Docker资源
docker system prune -a
docker volume prune

# 清理系统缓存
sudo apt-get clean  # Ubuntu/Debian
sudo yum clean all  # CentOS/RHEL
```

## 📊 部署后验证

### 检查服务状态
```bash
# 查看容器状态
docker-compose ps
# 或
docker compose ps

# 查看服务日志
docker-compose logs -f
# 或
docker compose logs -f
```

### 访问应用
- **主页**: http://localhost:8080
- **管理后台**: http://localhost:8080/admin
- **API文档**: http://localhost:8080/api/docs

### 健康检查
```bash
# 检查应用响应
curl -f http://localhost:8080

# 检查数据库连接
docker-compose exec app php artisan migrate:status
```

## 🛠️ 维护命令

### 常用操作
```bash
# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 更新服务
docker-compose pull && docker-compose up -d

# 查看日志
docker-compose logs --tail=50 -f

# 进入容器
docker-compose exec app bash
```

### 数据备份
```bash
# 备份数据库
docker-compose exec mysql mysqldump -u root -p medical_gpt > backup.sql

# 备份数据卷
docker run --rm -v medical-gpt_mysql_data:/data -v $(pwd):/backup alpine tar czf /backup/mysql_backup.tar.gz /data
```

## 🔒 安全建议

1. **修改默认密码**
   - 编辑 `.env` 文件中的数据库密码
   - 设置强密码策略

2. **配置防火墙**
   ```bash
   # 只允许必要端口
   sudo ufw allow 8080
   sudo ufw enable
   ```

3. **定期更新**
   ```bash
   # 更新系统
   sudo apt update && sudo apt upgrade
   
   # 更新Docker镜像
   docker-compose pull
   ```

4. **监控日志**
   ```bash
   # 监控应用日志
   docker-compose logs -f app
   ```

## 📞 获取帮助

如果遇到问题，请按以下顺序尝试：

1. 运行环境验证：`./validate-environment.sh`
2. 查看部署日志和错误信息
3. 尝试回退部署：`./deploy-fallback.sh auto`
4. 查看项目文档和常见问题
5. 提交问题反馈到项目仓库

---

**版本**: v1.0  
**更新时间**: 2024年1月  
**维护者**: Medical GPT Team