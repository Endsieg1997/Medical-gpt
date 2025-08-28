# 医疗健康AI助手部署指南

## 项目简介

本项目是基于GPTLink改造的医疗健康AI助手，专门为用户提供医疗健康咨询和知识服务。

## 主要特性

- 🏥 **专业医疗知识**：提供基础健康知识和医疗常识
- ⚕️ **健康咨询服务**：解答常见疾病症状、预防和护理方法
- 🔒 **安全可控**：内容过滤、使用限制、访问控制
- 📊 **使用统计**：每日咨询次数限制（50次）
- 🚫 **禁用付费**：完全免费使用，无付费功能

## 快速部署

### 1. 环境要求

- Docker & Docker Compose
- PHP 8.0+
- MySQL 8.0+
- Redis 7+
- Nginx

### 2. 配置文件

复制并修改环境配置：
```bash
cp gptserver/.env.example gptserver/.env
```

关键配置项：
```env
# 医疗模式开启
MEDICAL_MODE=true
MEDICAL_TITLE=医疗健康AI助手

# OpenAI API配置
OPENAI_API_KEY=your-openai-api-key
OPENAI_MODEL=gpt-3.5-turbo

# 功能限制
MED_MAX_DAILY_REQUESTS=50
MED_ENABLE_PAYMENT=false
MED_SIMPLE_AUTH=true
```

### 3. Docker部署

```bash
# 使用医疗版本配置启动
docker-compose -f docker-compose.education.yml up -d
```

### 4. 访问地址

- 前端界面：http://localhost
- 管理后台：http://localhost/admin
- API接口：http://localhost/api

## 功能说明

### 医疗AI助手功能

1. **健康知识问答**：提供基础医疗常识
2. **症状咨询**：解答常见疾病症状
3. **预防护理**：分享健康生活方式
4. **用药指导**：协助理解医疗检查报告
5. **急救知识**：提供健康管理建议

### 安全限制

- 每日咨询次数限制：50次
- 内容长度限制：2000字符
- 敏感词过滤：政治、暴力、色情、赌博、非法药物
- 免责声明：不能替代专业医生诊断

### 用户管理

- 简化注册流程（用户名+密码）
- 手机号可选
- 禁用付费功能
- 自动标记用户来源为"medical"

## 重要提醒

⚠️ **医疗免责声明**：
- 本AI助手仅提供健康咨询和医疗知识，不能替代专业医生的诊断
- 对于严重症状或紧急情况，请立即就医
- 用药建议仅供参考，具体用药请遵医嘱

## 技术支持

如有问题，请检查：
1. Docker容器运行状态
2. 数据库连接配置
3. OpenAI API Key有效性
4. 日志文件错误信息

## 更新日志

- v1.0：基础医疗健康AI助手功能
- 支持医疗知识问答和健康咨询
- 完整的安全限制和内容过滤
- 简化的用户注册和管理系统