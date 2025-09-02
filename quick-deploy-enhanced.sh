#!/bin/bash

# Medical GPT 增强快速部署脚本 v4.0
# 提供最大兼容性和用户友好的部署体验

# 严格模式
set -euo pipefail
IFS=$'\n\t'

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

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            VER=$VERSION_ID
        else
            OS="Unknown Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
        VER=$(sw_vers -productVersion)
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="Windows"
        VER="Unknown"
    else
        OS="Unknown"
        VER="Unknown"
    fi
    
    log_info "检测到操作系统: $OS $VER"
}

# 检查并安装依赖
check_and_install_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查curl
    if ! command -v curl &> /dev/null; then
        log_warning "curl 未安装，尝试安装..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y curl
        elif command -v brew &> /dev/null; then
            brew install curl
        else
            log_error "无法自动安装curl，请手动安装"
            exit 1
        fi
    fi
    
    # 检查git
    if ! command -v git &> /dev/null; then
        log_warning "git 未安装，尝试安装..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y git
        elif command -v yum &> /dev/null; then
            sudo yum install -y git
        elif command -v brew &> /dev/null; then
            brew install git
        else
            log_error "无法自动安装git，请手动安装"
            exit 1
        fi
    fi
    
    log_success "系统依赖检查完成"
}

# 智能安装Docker
install_docker_smart() {
    log_info "开始智能安装Docker..."
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            # 更新包索引
            sudo apt-get update
            
            # 安装必要的包
            sudo apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            
            # 添加Docker官方GPG密钥
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # 设置稳定版仓库
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # 安装Docker Engine
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            # 安装必要的包
            sudo yum install -y yum-utils
            
            # 添加Docker仓库
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            # 安装Docker Engine
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        *"macOS"*)
            if command -v brew &> /dev/null; then
                brew install --cask docker
                log_info "请启动Docker Desktop应用程序"
                read -p "Docker Desktop启动后按回车继续..."
            else
                log_error "请手动安装Docker Desktop for Mac"
                exit 1
            fi
            ;;
        *)
            log_info "使用通用安装脚本..."
            curl -fsSL https://get.docker.com | sudo sh
            ;;
    esac
    
    # 启动并启用Docker服务
    if command -v systemctl &> /dev/null; then
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
    
    # 添加用户到docker组
    if [[ $EUID -ne 0 ]]; then
        sudo usermod -aG docker $USER
        log_warning "已将用户添加到docker组，请重新登录或运行 'newgrp docker'"
    fi
    
    log_success "Docker安装完成"
}

# 智能安装Docker Compose
install_docker_compose_smart() {
    log_info "检查Docker Compose..."
    
    # 检查是否已安装Docker Compose Plugin
    if docker compose version &> /dev/null; then
        log_success "Docker Compose Plugin已安装"
        return 0
    fi
    
    # 检查是否已安装独立的docker-compose
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose已安装"
        return 0
    fi
    
    log_info "安装Docker Compose..."
    
    # 获取最新版本
    local latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$latest_version" ]; then
        latest_version="v2.20.2"
        log_warning "无法获取最新版本，使用默认版本: $latest_version"
    fi
    
    # 下载并安装
    sudo curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # 验证安装
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose安装完成"
    else
        log_error "Docker Compose安装失败"
        exit 1
    fi
}

# 创建优化的环境配置
create_optimized_env() {
    log_info "创建优化的环境配置..."
    
    # 生成安全的密钥
    local app_key="base64:$(openssl rand -base64 32 2>/dev/null || echo "$(date +%s)$(whoami)$(hostname)" | base64)"
    local jwt_secret="$(openssl rand -base64 64 2>/dev/null || echo "$(date +%s)$(whoami)$(hostname)jwt" | base64)"
    
    cat > .env << EOF
# 数据库配置
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=medical_gpt
DB_USERNAME=root
DB_PASSWORD=MedicalGPT@2024

# Redis配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# OpenAI配置
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-3.5-turbo
OPENAI_HOST=https://api.openai.com

# 应用配置
APP_NAME="Medical GPT"
APP_ENV=production
APP_DEBUG=false
APP_URL=http://localhost:8080
APP_TIMEZONE=Asia/Shanghai
APP_KEY=$app_key

# JWT配置
JWT_SECRET=$jwt_secret

# 医疗模式配置
MEDICAL_MODE=true
SESSION_TIMEOUT=3600

# 端口配置
WEB_PORT=8080
MYSQL_PORT=3306
REDIS_PORT=6379

# Composer配置
COMPOSER_CACHE_DIR=/tmp/composer-cache
COMPOSER_ALLOW_SUPERUSER=1
COMPOSER_NO_INTERACTION=1
COMPOSER_MEMORY_LIMIT=-1
EOF
    
    log_success "环境配置文件已创建"
    log_warning "请编辑 .env 文件，设置您的 OPENAI_API_KEY"
}

# 一键部署函数
quick_deploy() {
    log_info "开始一键部署 Medical GPT..."
    
    # 检测系统
    detect_os
    
    # 检查依赖
    check_and_install_dependencies
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_warning "Docker未安装"
        read -p "是否自动安装Docker? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker_smart
        else
            log_error "Docker是必需的，请手动安装后重试"
            exit 1
        fi
    else
        log_success "Docker已安装"
    fi
    
    # 检查Docker Compose
    install_docker_compose_smart
    
    # 确定compose命令
    local compose_cmd="docker-compose"
    if docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    fi
    
    # 创建环境配置
    if [ ! -f ".env" ]; then
        create_optimized_env
    else
        log_info "使用现有的 .env 文件"
    fi
    
    # 停止现有服务
    log_info "停止现有服务..."
    $compose_cmd down --remove-orphans 2>/dev/null || true
    
    # 清理资源（可选）
    read -p "是否清理旧的Docker资源以释放空间? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "清理Docker资源..."
        docker system prune -f 2>/dev/null || true
    fi
    
    # 构建并启动服务
    log_info "构建Docker镜像..."
    $compose_cmd build --no-cache --parallel
    
    log_info "启动服务..."
    $compose_cmd up -d
    
    # 等待服务就绪
    log_info "等待服务启动完成..."
    sleep 30
    
    # 显示状态
    log_info "服务状态:"
    $compose_cmd ps
    
    # 健康检查
    log_info "执行健康检查..."
    local web_port=$(grep "WEB_PORT" .env | cut -d'=' -f2 || echo "8080")
    
    for i in {1..10}; do
        if curl -f "http://localhost:$web_port" > /dev/null 2>&1; then
            log_success "应用服务正常运行"
            break
        fi
        if [ $i -eq 10 ]; then
            log_warning "应用可能仍在启动中，请稍后检查"
        fi
        sleep 5
    done
    
    # 显示访问信息
    echo
    log_success "部署完成！"
    echo "==========================================="
    echo "  应用地址: http://localhost:$web_port"
    echo "  管理后台: http://localhost:$web_port/admin"
    echo "  API文档: http://localhost:$web_port/api/docs"
    echo "==========================================="
    echo
    log_info "查看日志: $compose_cmd logs -f"
    log_info "停止服务: $compose_cmd down"
    log_info "重启服务: $compose_cmd restart"
    
    # 提示配置OpenAI API Key
    if grep -q "your_openai_api_key_here" .env; then
        echo
        log_warning "请设置您的OpenAI API Key:"
        echo "  1. 编辑 .env 文件"
        echo "  2. 将 OPENAI_API_KEY 设置为您的实际API Key"
        echo "  3. 运行 $compose_cmd restart 重启服务"
    fi
}

# 主函数
main() {
    echo "==========================================="
    echo "     Medical GPT 增强快速部署脚本 v4.0"
    echo "==========================================="
    echo
    
    # 检查是否在项目目录中
    if [ ! -f "docker-compose.yml" ]; then
        log_error "请在Medical GPT项目根目录中运行此脚本"
        exit 1
    fi
    
    quick_deploy
}

# 错误处理
trap 'log_error "脚本执行失败，请检查错误信息"' ERR

# 运行主函数
main "$@"