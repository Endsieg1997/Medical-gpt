#!/bin/bash

# 医疗健康AI助手 - 快速部署测试脚本
# 用于验证修复后的配置是否正确

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

# 清理现有容器和镜像
cleanup_containers() {
    log_info "清理现有容器和镜像..."
    
    # 停止所有相关容器
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # 删除相关镜像
    docker rmi medical-gpt_gptserver 2>/dev/null || true
    docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
    
    log_success "清理完成"
}

# 构建并启动服务
build_and_start() {
    log_info "构建并启动服务..."
    
    # 强制重新构建
    docker-compose build --no-cache gptserver
    
    # 启动所有服务
    docker-compose up -d
    
    log_success "服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    # 等待60秒让服务完全启动
    for i in {1..60}; do
        if docker-compose ps | grep -q "Up"; then
            log_success "服务启动成功"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    log_error "服务启动超时"
    return 1
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 检查容器状态
    echo "=== 容器状态 ==="
    docker-compose ps
    
    # 检查日志
    echo "\n=== 最新日志 ==="
    docker-compose logs --tail=20
    
    # 测试HTTP服务
    echo "\n=== HTTP服务测试 ==="
    if curl -f http://localhost:9000/health > /dev/null 2>&1; then
        log_success "HTTP服务正常"
    else
        log_warning "HTTP服务可能需要更多时间启动"
    fi
    
    # 测试Swoole服务
    echo "\n=== Swoole服务测试 ==="
    if curl -f http://localhost:9503/health > /dev/null 2>&1; then
        log_success "Swoole服务正常"
    else
        log_warning "Swoole服务可能需要更多时间启动"
    fi
}

# 显示访问信息
show_access_info() {
    log_success "部署测试完成！"
    echo ""
    echo "=== 访问信息 ==="
    echo "Apache服务: http://localhost:9000"
    echo "Swoole服务: http://localhost:9503"
    echo "健康检查: http://localhost:9503/health"
    echo ""
    echo "=== 管理命令 ==="
    echo "查看状态: docker-compose ps"
    echo "查看日志: docker-compose logs -f"
    echo "重启服务: docker-compose restart"
    echo "停止服务: docker-compose down"
    echo ""
}

# 主函数
main() {
    echo "=== 医疗健康AI助手 - 快速部署测试 ==="
    echo "开始时间: $(date)"
    echo ""
    
    cleanup_containers
    build_and_start
    
    if wait_for_services; then
        health_check
        show_access_info
    else
        log_error "部署测试失败，请检查日志"
        docker-compose logs
        exit 1
    fi
    
    log_success "快速部署测试完成！"
}

# 错误处理
trap 'log_error "部署测试过程中发生错误"; exit 1' ERR

# 执行主函数
main "$@"