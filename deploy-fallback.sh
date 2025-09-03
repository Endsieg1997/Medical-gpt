#!/bin/bash

# Medical GPT 智能部署回退脚本
# 当主要部署脚本失败时，提供多种回退方案

set -euo pipefail

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
            OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
        else
            OS="Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
    else
        OS="Unknown"
    fi
    log_info "检测到操作系统: $OS"
}

# 创建Docker Compose别名
create_compose_alias() {
    log_info "创建Docker Compose别名..."
    
    # 检查是否已有别名
    if alias docker-compose &> /dev/null; then
        log_success "docker-compose 别名已存在"
        return 0
    fi
    
    # 创建临时别名
    if docker compose version &> /dev/null; then
        alias docker-compose='docker compose'
        log_success "已创建别名: docker-compose -> docker compose"
        
        # 尝试添加到shell配置文件
        local shell_config=""
        if [ -n "${BASH_VERSION:-}" ]; then
            shell_config="$HOME/.bashrc"
        elif [ -n "${ZSH_VERSION:-}" ]; then
            shell_config="$HOME/.zshrc"
        fi
        
        if [ -n "$shell_config" ] && [ -w "$shell_config" ]; then
            if ! grep -q "alias docker-compose='docker compose'" "$shell_config"; then
                echo "# Docker Compose别名 (由Medical GPT部署脚本添加)" >> "$shell_config"
                echo "alias docker-compose='docker compose'" >> "$shell_config"
                log_info "别名已添加到 $shell_config"
            fi
        fi
        
        return 0
    else
        log_error "无法创建别名，docker compose 不可用"
        return 1
    fi
}

# 手动部署方法1: 使用docker-compose
manual_deploy_v1() {
    log_info "=== 手动部署方法1: 使用docker-compose ==="
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose 命令不可用"
        return 1
    fi
    
    log_info "停止现有服务..."
    docker-compose down --remove-orphans 2>/dev/null || true
    
    log_info "拉取镜像..."
    if ! docker-compose pull; then
        log_warning "镜像拉取失败，尝试构建..."
    fi
    
    log_info "构建并启动服务..."
    if docker-compose up -d --build; then
        log_success "部署成功！"
        return 0
    else
        log_error "部署失败"
        return 1
    fi
}

# 手动部署方法2: 使用docker compose
manual_deploy_v2() {
    log_info "=== 手动部署方法2: 使用docker compose ==="
    
    if ! docker compose version &> /dev/null; then
        log_error "docker compose 命令不可用"
        return 1
    fi
    
    log_info "停止现有服务..."
    docker compose down --remove-orphans 2>/dev/null || true
    
    log_info "拉取镜像..."
    if ! docker compose pull; then
        log_warning "镜像拉取失败，尝试构建..."
    fi
    
    log_info "构建并启动服务..."
    if docker compose up -d --build; then
        log_success "部署成功！"
        return 0
    else
        log_error "部署失败"
        return 1
    fi
}

# 手动部署方法3: 逐步执行
manual_deploy_v3() {
    log_info "=== 手动部署方法3: 逐步执行 ==="
    
    # 确定compose命令
    local compose_cmd=""
    if docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    elif command -v docker-compose &> /dev/null; then
        compose_cmd="docker-compose"
    else
        log_error "未找到可用的Docker Compose命令"
        return 1
    fi
    
    log_info "使用命令: $compose_cmd"
    
    # 步骤1: 停止服务
    log_info "步骤1: 停止现有服务..."
    $compose_cmd down --remove-orphans 2>/dev/null || true
    
    # 步骤2: 清理旧容器和镜像
    log_info "步骤2: 清理旧资源..."
    docker system prune -f 2>/dev/null || true
    
    # 步骤3: 创建网络
    log_info "步骤3: 创建Docker网络..."
    docker network create medical-gpt-network 2>/dev/null || true
    
    # 步骤4: 启动数据库
    log_info "步骤4: 启动数据库服务..."
    if ! $compose_cmd up -d mysql redis; then
        log_error "数据库服务启动失败"
        return 1
    fi
    
    # 等待数据库启动
    log_info "等待数据库启动..."
    sleep 10
    
    # 步骤5: 启动应用
    log_info "步骤5: 启动应用服务..."
    if ! $compose_cmd up -d --build app; then
        log_error "应用服务启动失败"
        return 1
    fi
    
    # 步骤6: 启动Web服务
    log_info "步骤6: 启动Web服务..."
    if ! $compose_cmd up -d nginx; then
        log_error "Web服务启动失败"
        return 1
    fi
    
    log_success "逐步部署完成！"
    return 0
}

# 最小化部署（仅核心服务）
minimal_deploy() {
    log_info "=== 最小化部署: 仅核心服务 ==="
    
    # 确定compose命令
    local compose_cmd=""
    if docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    elif command -v docker-compose &> /dev/null; then
        compose_cmd="docker-compose"
    else
        log_error "未找到可用的Docker Compose命令"
        return 1
    fi
    
    # 创建最小化的docker-compose配置
    cat > docker-compose.minimal.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - APP_ENV=production
      - DB_HOST=mysql
      - REDIS_HOST=redis
    depends_on:
      - mysql
      - redis
    restart: unless-stopped

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: MedicalGPT@2024
      MYSQL_DATABASE: medical_gpt
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  mysql_data:
  redis_data:
EOF
    
    log_info "使用最小化配置部署..."
    if $compose_cmd -f docker-compose.minimal.yml up -d --build; then
        log_success "最小化部署成功！"
        log_info "访问地址: http://localhost:8080"
        return 0
    else
        log_error "最小化部署失败"
        return 1
    fi
}

# 诊断和修复
diagnose_and_fix() {
    log_info "=== 诊断和修复 ==="
    
    # 检查Docker服务
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行"
        log_info "尝试启动Docker服务..."
        if command -v systemctl &> /dev/null; then
            sudo systemctl start docker || log_error "无法启动Docker服务"
        fi
    fi
    
    # 检查端口占用
    log_info "检查端口占用..."
    local ports=("8080" "3306" "6379")
    for port in "${ports[@]}"; do
        if command -v netstat &> /dev/null && netstat -tuln | grep -q ":$port "; then
            log_warning "端口 $port 被占用"
            log_info "尝试查找占用进程: netstat -tulnp | grep :$port"
        fi
    done
    
    # 清理Docker资源
    log_info "清理Docker资源..."
    docker system prune -f 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
    
    # 检查磁盘空间
    local available=$(df . | tail -1 | awk '{print $4}')
    local available_gb=$((available / 1024 / 1024))
    if [ "$available_gb" -lt 2 ]; then
        log_warning "磁盘空间不足: ${available_gb}GB"
    fi
    
    log_success "诊断完成"
}

# 显示帮助信息
show_help() {
    echo "Medical GPT 智能部署回退脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  1, v1, method1    使用docker-compose命令部署"
    echo "  2, v2, method2    使用docker compose命令部署"
    echo "  3, v3, method3    逐步执行部署"
    echo "  minimal           最小化部署（仅核心服务）"
    echo "  alias             创建docker-compose别名"
    echo "  diagnose, fix     诊断和修复常见问题"
    echo "  auto              自动选择最佳部署方法"
    echo "  help, -h, --help  显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 auto          # 自动部署"
    echo "  $0 v1            # 使用方法1部署"
    echo "  $0 minimal       # 最小化部署"
    echo "  $0 diagnose      # 诊断问题"
}

# 自动选择最佳部署方法
auto_deploy() {
    log_info "=== 自动选择最佳部署方法 ==="
    
    # 首先运行诊断
    diagnose_and_fix
    
    # 尝试方法2 (docker compose)
    if docker compose version &> /dev/null; then
        log_info "尝试使用 docker compose..."
        if manual_deploy_v2; then
            return 0
        fi
    fi
    
    # 尝试方法1 (docker-compose)
    if command -v docker-compose &> /dev/null; then
        log_info "尝试使用 docker-compose..."
        if manual_deploy_v1; then
            return 0
        fi
    fi
    
    # 尝试创建别名后再试
    if create_compose_alias; then
        log_info "别名创建成功，重试部署..."
        if manual_deploy_v1; then
            return 0
        fi
    fi
    
    # 尝试逐步部署
    log_info "尝试逐步部署..."
    if manual_deploy_v3; then
        return 0
    fi
    
    # 最后尝试最小化部署
    log_warning "常规部署失败，尝试最小化部署..."
    if minimal_deploy; then
        return 0
    fi
    
    log_error "所有部署方法都失败了"
    return 1
}

# 主函数
main() {
    echo "==========================================="
    echo "    Medical GPT 智能部署回退脚本 v1.0"
    echo "==========================================="
    echo
    
    detect_os
    
    case "${1:-auto}" in
        "1"|"v1"|"method1")
            manual_deploy_v1
            ;;
        "2"|"v2"|"method2")
            manual_deploy_v2
            ;;
        "3"|"v3"|"method3")
            manual_deploy_v3
            ;;
        "minimal")
            minimal_deploy
            ;;
        "alias")
            create_compose_alias
            ;;
        "diagnose"|"fix")
            diagnose_and_fix
            ;;
        "auto")
            auto_deploy
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo
        log_success "部署完成！"
        log_info "访问地址: http://localhost:8080"
        log_info "查看日志: docker-compose logs -f 或 docker compose logs -f"
        log_info "停止服务: docker-compose down 或 docker compose down"
    else
        echo
        log_error "部署失败！"
        log_info "请检查错误信息并尝试其他部署方法"
        log_info "获取帮助: $0 help"
        exit 1
    fi
}

# 执行主函数
main "$@"