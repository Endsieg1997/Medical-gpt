#!/bin/bash

# 医疗健康AI助手 - 云服务器部署脚本
# 专为 medicalgpt.asia 域名配置
# 版本: 3.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到 root 用户，建议使用普通用户运行此脚本"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        log_info "安装命令: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        log_info "安装命令: sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose"
        log_info "然后执行: sudo chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
    
    # 检查端口占用
    if netstat -tuln | grep -q ':80 '; then
        log_warning "端口 80 已被占用，请确保没有其他 Web 服务运行"
    fi
    
    if netstat -tuln | grep -q ':443 '; then
        log_warning "端口 443 已被占用，请确保没有其他 HTTPS 服务运行"
    fi
    
    log_success "系统要求检查完成"
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    
    mkdir -p data/mysql
    mkdir -p data/redis
    mkdir -p logs/nginx
    mkdir -p logs/php
    mkdir -p logs/mysql
    mkdir -p logs/redis
    mkdir -p ssl_certs
    
    # 设置目录权限
    chmod 755 data/mysql data/redis
    chmod 755 logs/nginx logs/php logs/mysql logs/redis
    chmod 700 ssl_certs
    
    log_success "目录创建完成"
}

# 检查环境配置文件
check_env_config() {
    log_info "检查环境配置..."
    
    if [[ ! -f .env.cloud ]]; then
        log_error "环境配置文件 .env.cloud 不存在"
        log_info "请复制 .env.cloud 文件并配置相关参数"
        exit 1
    fi
    
    # 检查关键配置项
    if grep -q "your_.*_here" .env.cloud; then
        log_warning "检测到未配置的默认值，请检查 .env.cloud 文件"
        log_info "需要配置的项目包括："
        grep "your_.*_here" .env.cloud | sed 's/=.*//' | sed 's/^/  - /'
        read -p "是否继续部署？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "环境配置检查完成"
}

# 验证配置与本地成功配置的一致性
validate_config_consistency() {
    log_info "验证配置一致性..."
    
    # 检查 DeepSeek API 配置
    if ! grep -q "OPENAI_MODEL=deepseek-chat" .env.cloud; then
        log_warning "建议使用与本地成功配置一致的 DeepSeek 模型"
    fi
    
    if ! grep -q "OPENAI_HOST=https://api.deepseek.com" .env.cloud; then
        log_warning "建议使用与本地成功配置一致的 DeepSeek API 地址"
    fi
    
    # 检查医疗模式配置
    if ! grep -q "MEDICAL_MODE=true" .env.cloud; then
        log_error "医疗模式未启用，这与本地成功配置不一致"
        exit 1
    fi
    
    # 检查关键医疗配置项
    local required_configs=("MED_CONTENT_FILTER" "MED_LOG_CONVERSATIONS" "MEDICAL_SAFETY_CHECK")
    for config in "${required_configs[@]}"; do
        if ! grep -q "$config=true" .env.cloud; then
            log_warning "$config 未启用，建议与本地成功配置保持一致"
        fi
    done
    
    log_success "配置一致性验证完成"
}

# 检查 SSL 证书
check_ssl_certificates() {
    log_info "检查 SSL 证书..."
    
    if [[ ! -f ssl_certs/medicalgpt.asia.crt ]] || [[ ! -f ssl_certs/medicalgpt.asia.key ]]; then
        log_warning "SSL 证书文件不存在"
        log_info "请将 SSL 证书文件放置在 ssl_certs 目录下："
        log_info "  - ssl_certs/medicalgpt.asia.crt (证书文件)"
        log_info "  - ssl_certs/medicalgpt.asia.key (私钥文件)"
        
        read -p "是否生成自签名证书用于测试？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            generate_self_signed_cert
        else
            log_error "请配置 SSL 证书后再运行部署脚本"
            exit 1
        fi
    else
        log_success "SSL 证书文件存在"
    fi
}

# 生成自签名证书（仅用于测试）
generate_self_signed_cert() {
    log_info "生成自签名 SSL 证书（仅用于测试）..."
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl_certs/medicalgpt.asia.key \
        -out ssl_certs/medicalgpt.asia.crt \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=Medical GPT/CN=medicalgpt.asia"
    
    chmod 600 ssl_certs/medicalgpt.asia.key
    chmod 644 ssl_certs/medicalgpt.asia.crt
    
    log_warning "已生成自签名证书，生产环境请使用正式的 SSL 证书"
}

# 停止现有服务
stop_existing_services() {
    log_info "停止现有服务..."
    
    if docker-compose -f docker-compose.cloud.yml ps -q | grep -q .; then
        docker-compose -f docker-compose.cloud.yml down
        log_success "现有服务已停止"
    else
        log_info "没有运行中的服务"
    fi
}

# 构建和启动服务
start_services() {
    log_info "构建和启动服务..."
    
    # 使用云服务器配置文件
    export COMPOSE_FILE=docker-compose.cloud.yml
    
    # 构建镜像
    docker-compose --env-file .env.cloud -f docker-compose.cloud.yml build --no-cache
    
    # 启动服务
    docker-compose --env-file .env.cloud -f docker-compose.cloud.yml up -d
    
    log_success "服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    local max_attempts=60
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f http://localhost/health > /dev/null 2>&1; then
            log_success "服务已就绪"
            return 0
        fi
        
        echo -n "."
        sleep 5
        ((attempt++))
    done
    
    log_error "服务启动超时，请检查日志"
    return 1
}

# 显示服务状态
show_status() {
    log_info "服务状态："
    docker-compose -f docker-compose.cloud.yml ps
    
    echo
    log_info "访问信息："
    echo "  🌐 网站地址: https://medicalgpt.asia"
    echo "  🔧 管理后台: https://medicalgpt.asia/admin/"
    echo "  📊 健康检查: https://medicalgpt.asia/health"
    
    echo
    log_info "日志查看："
    echo "  docker-compose -f docker-compose.cloud.yml logs -f"
    
    echo
    log_info "服务管理："
    echo "  启动: docker-compose -f docker-compose.cloud.yml up -d"
    echo "  停止: docker-compose -f docker-compose.cloud.yml down"
    echo "  重启: docker-compose -f docker-compose.cloud.yml restart"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian 系统
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        log_success "UFW 防火墙规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL 系统
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload
        log_success "Firewalld 防火墙规则已添加"
    else
        log_warning "未检测到防火墙管理工具，请手动开放 80 和 443 端口"
    fi
}

# 主函数
main() {
    echo "======================================"
    echo "  医疗健康AI助手 - 云服务器部署脚本"
    echo "  域名: medicalgpt.asia"
    echo "  版本: 3.0"
    echo "======================================"
    echo
    
    check_root
    check_requirements
    create_directories
    check_env_config
    validate_config_consistency
    check_ssl_certificates
    configure_firewall
    stop_existing_services
    start_services
    
    if wait_for_services; then
        echo
        log_success "🎉 部署完成！"
        show_status
    else
        log_error "部署失败，请检查日志"
        docker-compose -f docker-compose.cloud.yml logs
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi