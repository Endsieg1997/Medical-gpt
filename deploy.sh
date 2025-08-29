#!/bin/bash

# 医疗健康AI助手 - Docker部署脚本
# 版本: 1.0
# 作者: Medical AI Team
# 日期: 2024-01-01

set -e

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

# 检查Docker和Docker Compose
check_requirements() {
    log_info "检查系统要求..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    log_success "系统要求检查通过"
}

# 检查环境变量
check_env() {
    log_info "检查环境变量..."
    
    if [ -z "$OPENAI_API_KEY" ]; then
        log_warning "未设置OPENAI_API_KEY环境变量"
        read -p "请输入OpenAI API Key: " OPENAI_API_KEY
        export OPENAI_API_KEY
    fi
    
    log_success "环境变量检查完成"
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    
    mkdir -p logs/nginx
    mkdir -p logs/mysql
    mkdir -p logs/php
    mkdir -p data/mysql
    mkdir -p data/redis
    mkdir -p ssl
    
    log_success "目录创建完成"
}

# 设置权限
set_permissions() {
    log_info "设置文件权限..."
    
    # 设置日志目录权限
    chmod -R 755 logs/
    chmod -R 755 data/
    
    # 设置PHP应用权限
    if [ -d "gptserver" ]; then
        chmod -R 755 gptserver/storage
        chmod -R 755 gptserver/bootstrap/cache
    fi
    
    log_success "权限设置完成"
}

# 构建和启动服务
start_services() {
    log_info "构建和启动Docker服务..."
    
    # 停止现有服务
    docker-compose down --remove-orphans
    
    # 构建镜像
    docker-compose build --no-cache
    
    # 启动服务
    docker-compose up -d
    
    log_success "服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    # 等待MySQL
    log_info "等待MySQL服务..."
    until docker-compose exec mysql mysqladmin ping -h"localhost" --silent; do
        sleep 2
    done
    
    # 等待Redis
    log_info "等待Redis服务..."
    until docker-compose exec redis redis-cli -a 666666 ping; do
        sleep 2
    done
    
    # 等待PHP-FPM
    log_info "等待PHP-FPM服务..."
    sleep 10
    
    log_success "所有服务已就绪"
}

# 初始化数据库
init_database() {
    log_info "初始化数据库..."
    
    # 运行数据库迁移（如果有的话）
    if [ -f "gptserver/artisan" ]; then
        docker-compose exec gptserver php artisan migrate --force
        docker-compose exec gptserver php artisan db:seed --force
    fi
    
    log_success "数据库初始化完成"
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 检查Nginx
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_success "Nginx服务正常"
    else
        log_error "Nginx服务异常"
    fi
    
    # 检查MySQL
    if docker-compose exec mysql mysqladmin ping -h"localhost" --silent; then
        log_success "MySQL服务正常"
    else
        log_error "MySQL服务异常"
    fi
    
    # 检查Redis
    if docker-compose exec redis redis-cli -a 666666 ping > /dev/null 2>&1; then
        log_success "Redis服务正常"
    else
        log_error "Redis服务异常"
    fi
}

# 显示服务信息
show_info() {
    log_success "医疗健康AI助手部署完成！"
    echo ""
    echo "=== 服务访问信息 ==="
    echo "前端地址: http://localhost"
    echo "管理后台: http://localhost/admin"
    echo "API接口: http://localhost/api"
    echo "健康检查: http://localhost/health"
    echo ""
    echo "=== 数据库信息 ==="
    echo "MySQL端口: 3306"
    echo "Redis端口: 6379"
    echo "数据库名: gptlink_edu"
    echo "用户名: gptlink"
    echo "密码: 666666"
    echo ""
    echo "=== 管理员账号 ==="
    echo "用户名: admin"
    echo "密码: 666666"
    echo ""
    echo "=== 日志查看 ==="
    echo "查看所有日志: docker-compose logs -f"
    echo "查看Nginx日志: docker-compose logs -f nginx"
    echo "查看PHP日志: docker-compose logs -f gptserver"
    echo "查看MySQL日志: docker-compose logs -f mysql"
    echo "查看Redis日志: docker-compose logs -f redis"
    echo ""
    echo "=== 服务管理 ==="
    echo "停止服务: docker-compose down"
    echo "重启服务: docker-compose restart"
    echo "更新服务: docker-compose pull && docker-compose up -d"
    echo ""
}

# 主函数
main() {
    echo "=== 医疗健康AI助手 Docker部署脚本 ==="
    echo "版本: 1.0"
    echo "开始时间: $(date)"
    echo ""
    
    check_requirements
    check_env
    create_directories
    set_permissions
    start_services
    wait_for_services
    init_database
    health_check
    show_info
    
    log_success "部署完成！"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"