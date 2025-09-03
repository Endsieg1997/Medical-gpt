# 本地到云端配置迁移指南

本指南帮助您将本地成功运行的医疗GPT配置安全迁移到云服务器，确保云端部署的稳定性。

## 📋 迁移前检查清单

### 1. 本地配置验证
在迁移前，请确认本地部署正常运行：

```bash
# 检查本地服务状态
docker-compose ps

# 测试本地服务
curl http://localhost:8080
```

### 2. 关键配置项记录
记录以下本地成功配置：

- ✅ **DeepSeek API配置**：`OPENAI_API_KEY`, `OPENAI_MODEL`, `OPENAI_HOST`
- ✅ **数据库配置**：`DB_PASSWORD`, `MYSQL_ROOT_PASSWORD`
- ✅ **Redis配置**：`REDIS_PASSWORD`
- ✅ **医疗模式配置**：所有 `MED_*` 开头的配置项
- ✅ **管理员配置**：`ADMIN_USERNAME`, `ADMIN_PASSWORD`

## 🔄 自动配置迁移

### 步骤1：配置文件对比

云端配置已自动继承本地成功配置：

| 配置项 | 本地配置 | 云端配置 | 状态 |
|--------|----------|----------|------|
| AI模型 | `deepseek-chat` | `deepseek-chat` | ✅ 已同步 |
| API地址 | `https://api.deepseek.com` | `https://api.deepseek.com` | ✅ 已同步 |
| 医疗模式 | `MEDICAL_MODE=true` | `MEDICAL_MODE=true` | ✅ 已同步 |
| 内容过滤 | `MED_CONTENT_FILTER=true` | `MED_CONTENT_FILTER=true` | ✅ 已同步 |
| 安全检查 | `MEDICAL_SAFETY_CHECK=true` | `MEDICAL_SAFETY_CHECK=true` | ✅ 已同步 |

### 步骤2：密码和密钥配置

编辑 `.env.cloud` 文件，设置安全密码：

```bash
# 复制本地API密钥（已预配置）
OPENAI_API_KEY=sk-bc607febd5244be593f2f91647219206

# 设置数据库密码（请修改为强密码）
MYSQL_ROOT_PASSWORD=your_secure_mysql_root_password_here
MYSQL_PASSWORD=your_secure_mysql_password_here

# 设置Redis密码（请修改为强密码）
REDIS_PASSWORD=your_secure_redis_password_here

# 设置管理员密码（请修改为强密码）
ADMIN_PASSWORD=your_secure_admin_password_here
```

## 🛡️ 安全性增强

### 云端vs本地的安全差异

| 安全特性 | 本地部署 | 云端部署 |
|----------|----------|----------|
| 端口暴露 | 全部端口 | 仅80/443端口 |
| 数据库访问 | `3306:3306` | `127.0.0.1:3306:3306` |
| Redis访问 | `6379:6379` | `127.0.0.1:6379:6379` |
| SSL证书 | 可选 | 必需 |
| 防火墙 | 本地防火墙 | 云服务器+安全组 |

### 自动安全配置

云端部署脚本会自动：

1. **限制数据库访问**：仅允许本地连接
2. **配置防火墙**：自动开放80/443端口
3. **SSL证书检查**：验证HTTPS配置
4. **配置验证**：确保与本地成功配置一致

## 🚀 一键迁移部署

### 执行迁移

```bash
# 1. 编辑云端环境配置
vim .env.cloud

# 2. 执行一键部署（包含配置验证）
bash deploy-cloud.sh
```

### 部署过程验证

部署脚本会自动验证：

- ✅ **配置一致性**：确保使用DeepSeek API配置
- ✅ **医疗模式**：验证所有医疗相关配置
- ✅ **安全配置**：检查内容过滤和安全检查
- ✅ **SSL证书**：验证HTTPS配置
- ✅ **服务健康**：等待所有服务正常启动

## 📊 迁移后验证

### 1. 服务状态检查

```bash
# 检查所有服务状态
docker-compose -f docker-compose.cloud.yml ps

# 查看服务日志
docker-compose -f docker-compose.cloud.yml logs -f
```

### 2. 功能测试

```bash
# 测试HTTP重定向
curl -I http://medicalgpt.asia

# 测试HTTPS访问
curl -I https://medicalgpt.asia

# 测试API接口
curl https://medicalgpt.asia/api/health
```

### 3. 医疗功能验证

访问 `https://medicalgpt.asia` 并测试：

- ✅ 医疗对话功能
- ✅ 内容安全过滤
- ✅ 请求限制功能
- ✅ 管理后台访问

## 🔧 故障排除

### 常见问题及解决方案

#### 1. 配置不一致警告

```bash
[WARNING] 建议使用与本地成功配置一致的 DeepSeek 模型
```

**解决方案**：检查 `.env.cloud` 中的 `OPENAI_MODEL` 配置

#### 2. SSL证书问题

```bash
[ERROR] SSL 证书文件不存在
```

**解决方案**：
- 生产环境：获取正式SSL证书
- 测试环境：使用脚本生成自签名证书

#### 3. 服务启动失败

```bash
# 查看详细错误日志
docker-compose -f docker-compose.cloud.yml logs mysql
docker-compose -f docker-compose.cloud.yml logs redis
docker-compose -f docker-compose.cloud.yml logs gptserver
```

## 📈 性能优化建议

### 云端性能配置

云端部署已包含以下优化：

1. **MySQL优化**：
   - 缓冲池大小：512MB
   - 连接数限制：1000
   - 慢查询日志：启用

2. **Redis优化**：
   - 内存限制：256MB
   - LRU淘汰策略
   - 持久化配置

3. **PHP优化**：
   - 内存限制：512MB
   - 执行时间：300秒
   - 文件上传：20MB

4. **Nginx优化**：
   - Gzip压缩：启用
   - 静态文件缓存：启用
   - 限流配置：启用

## 📞 技术支持

如果在迁移过程中遇到问题：

1. **查看日志**：`docker-compose -f docker-compose.cloud.yml logs`
2. **检查配置**：确保 `.env.cloud` 配置正确
3. **验证网络**：确保域名DNS解析正确
4. **安全组设置**：确保云服务器安全组开放80/443端口

---

**注意**：本迁移指南确保云端部署继承本地成功配置，最大程度降低部署风险。