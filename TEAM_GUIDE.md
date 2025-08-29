# Medical-GPT 项目团队分享指南

## 📋 项目概述

**Medical-GPT** 是一个基于 GPTLink 的医疗AI对话系统，专为医疗场景设计的智能问答平台。项目支持医疗安全检查、会话管理、用户权限控制等功能。

### 🎯 项目特色
- 🏥 **医疗专用模式**：集成医疗安全检查机制
- 💬 **智能对话**：基于 DeepSeek 模型的AI对话
- 📱 **移动端适配**：完美支持移动端访问
- 🔐 **权限管理**：完整的用户和管理员权限体系
- 💰 **付费套餐**：支持自定义付费套餐配置
- 📊 **数据导出**：一键导出对话记录

## 🏗️ 技术架构

### 整体架构
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   前端 (Vue)    │    │  管理端 (Vue)   │    │   后端 (PHP)    │
│   gptweb/       │    │   gptadmin/     │    │   gptserver/    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Nginx 反向代理 │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐    ┌─────────────────┐
                    │   MySQL 8.0     │    │   Redis 7       │
                    │   数据存储       │    │   缓存/会话     │
                    └─────────────────┘    └─────────────────┘
```

### 技术栈详情

#### 🔧 后端技术栈
- **框架**: Hyperf (基于 Swoole 的高性能 PHP 框架)
- **语言**: PHP 8.0+
- **数据库**: MySQL 8.0
- **缓存**: Redis 7
- **容器**: Docker + Docker Compose
- **Web服务器**: Nginx

#### 🎨 前端技术栈
- **用户端**: Vue.js (已编译的静态文件)
- **管理端**: Vue.js (已编译的静态文件)
- **样式**: CSS3 + 响应式设计
- **构建**: Webpack/Vite (已构建完成)

#### 🔌 核心依赖
- **AI SDK**: cblink/gptlink-sdk - GPT API 集成
- **认证**: 96qbhy/hyperf-auth - 用户认证系统
- **社交登录**: cblink/hyperf-socialite - 微信等社交登录
- **短信**: overtrue/easy-sms - 短信发送服务
- **JWT**: firebase/php-jwt - Token 认证
- **限流**: hyperf/rate-limit - API 限流保护

## 🚀 快速启动

### 环境要求
- Docker 20.0+
- Docker Compose 2.0+
- 至少 4GB 内存
- 至少 10GB 磁盘空间

### 一键部署

1. **克隆项目**
```bash
git clone <repository-url>
cd Medical-gpt
```

2. **配置环境变量**
```bash
# 复制配置文件
cp gptserver/.env.example gptserver/.env

# 编辑配置文件，设置必要参数
vim gptserver/.env
```

3. **启动服务**
```bash
# 使用 Docker Compose 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

4. **访问应用**
- 用户端: http://localhost:8080
- 管理端: http://localhost:8080/admin
- API文档: http://localhost:8080/api/docs/default

### 默认账号
- **管理员账号**: admin
- **管理员密码**: 666666

## 📁 项目结构

```
Medical-gpt/
├── 📂 gptserver/          # 后端 PHP 服务
│   ├── app/               # 应用核心代码
│   ├── config/            # 配置文件
│   ├── storage/           # 存储目录
│   └── .env.example       # 环境配置模板
├── 📂 gptweb/             # 前端用户界面
│   ├── assets/            # 静态资源
│   └── index.html         # 主页面
├── 📂 gptadmin/           # 管理端界面
│   ├── assets/            # 静态资源
│   └── index.html         # 管理主页
├── 📂 docker/             # Docker 配置
│   ├── mysql/             # MySQL 配置
│   ├── nginx/             # Nginx 配置
│   ├── php/               # PHP 配置
│   └── redis/             # Redis 配置
├── 📂 docs/               # 项目文档
├── 📂 logs/               # 日志目录
├── docker-compose.yml     # Docker 编排文件
├── .env                   # 主环境配置
└── README.md              # 项目说明
```

## ⚙️ 核心配置

### 数据库配置
```env
DB_DRIVER=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=gptlink_edu
DB_USERNAME=gptlink
DB_PASSWORD=666666
```

### Redis 配置
```env
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=666666
```

### AI 模型配置
```env
OPENAI_API_KEY=sk-bc607febd5244be593f2f91647219206
OPENAI_MODEL=deepseek-chat
OPENAI_HOST=https://api.deepseek.com
OPENAI_MAX_TOKENS=2000
OPENAI_TEMPERATURE=0.7
```

### 医疗模式配置
```env
MEDICAL_MODE=true
MEDICAL_SAFETY_CHECK=true
DAILY_REQUEST_LIMIT=50
SESSION_TIMEOUT=1800
```

## 🔧 开发指南

### 本地开发环境

1. **后端开发**
```bash
cd gptserver

# 安装依赖
composer install

# 启动开发服务器
php bin/hyperf.php start
```

2. **前端开发**
```bash
# 前端和管理端都是已编译的静态文件
# 如需修改，请参考源码仓库：
# 前端: https://github.com/gptlink/gptlink-web
# 管理端: 开发中
```

### 数据库迁移
```bash
# 进入后端容器
docker exec -it medical-gpt-server bash

# 运行迁移
php bin/hyperf.php migrate
```

### 日志查看
```bash
# 查看应用日志
docker-compose logs -f gptserver

# 查看 Nginx 日志
docker-compose logs -f nginx

# 查看数据库日志
docker-compose logs -f mysql
```

## 🛠️ 常用命令

### Docker 管理
```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 重启特定服务
docker-compose restart gptserver

# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f [service_name]
```

### 数据库操作
```bash
# 连接数据库
docker exec -it medical-gpt-mysql mysql -u gptlink -p666666 gptlink_edu

# 备份数据库
docker exec medical-gpt-mysql mysqldump -u gptlink -p666666 gptlink_edu > backup.sql

# 恢复数据库
docker exec -i medical-gpt-mysql mysql -u gptlink -p666666 gptlink_edu < backup.sql
```

### Redis 操作
```bash
# 连接 Redis
docker exec -it medical-gpt-redis redis-cli -a 666666

# 查看 Redis 信息
docker exec medical-gpt-redis redis-cli -a 666666 info
```

## 🔍 故障排除

### 常见问题

1. **服务启动失败**
   - 检查端口是否被占用
   - 确认 Docker 服务正常运行
   - 查看服务日志定位问题

2. **数据库连接失败**
   - 确认数据库服务已启动
   - 检查数据库配置是否正确
   - 验证网络连接

3. **AI 接口调用失败**
   - 检查 API Key 是否有效
   - 确认网络连接正常
   - 查看 API 调用日志

### 性能优化

1. **数据库优化**
   - 定期清理日志表
   - 添加必要的索引
   - 监控慢查询

2. **缓存优化**
   - 合理设置 Redis 过期时间
   - 监控缓存命中率
   - 定期清理无用缓存

## 📚 相关资源

### 官方文档
- [Hyperf 官方文档](https://hyperf.wiki/)
- [Docker 官方文档](https://docs.docker.com/)
- [MySQL 8.0 文档](https://dev.mysql.com/doc/refman/8.0/en/)
- [Redis 文档](https://redis.io/documentation)

### 项目仓库
- 前端源码: https://github.com/gptlink/gptlink-web
- 部署脚本: https://github.com/gptlink/gptlink-deploy

### API 文档
- 用户端 API: http://localhost:8080/api/docs/default
- 管理端 API: http://localhost:8080/api/docs/admin

## 🤝 团队协作

### 开发流程
1. 从 main 分支创建功能分支
2. 在功能分支上进行开发
3. 提交代码并创建 Pull Request
4. 代码审查通过后合并到 main 分支
5. 部署到测试/生产环境

### 代码规范
- 遵循 PSR-12 PHP 编码标准
- 使用有意义的变量和函数命名
- 添加必要的注释和文档
- 编写单元测试

### 版本管理
- 使用语义化版本号 (Semantic Versioning)
- 重要更新需要更新 CHANGELOG
- 生产环境部署前需要充分测试

---

**联系方式**
- 项目负责人: [填写负责人信息]
- 技术支持: [填写技术支持联系方式]
- 项目群组: [填写项目群组信息]

**最后更新**: 2024年1月
**文档版本**: v1.0