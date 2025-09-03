#!/bin/bash

# Medical GPT 环境验证脚本
# 用于在部署前检查所有必要的依赖和配置

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

# 验证结果统计
PASSED=0
FAILED=0
WARNINGS=0

# 检查函数
check_command() {
    local cmd="$1"
    local name="$2"
    local required="${3:-true}"
    
    if command -v "$cmd" &> /dev/null; then
        log_success "$name 已安装"
        ((PASSED++))
        return 0
    else
        if [ "$required" = "true" ]; then
            log_error "$name 未安装 (必需)"
            ((FAILED++))
        else
            log_warning "$name 未安装 (可选)"
            ((WARNINGS++))
        fi
        return 1
    fi
}

check_docker_compose() {
    log_info "检查Docker Compose..."
    
    if docker compose version &> /dev/null 2>&1; then
        local version=$(docker compose version --short 2>/dev/null || echo "unknown")
        log_success "Docker Compose Plugin 已安装 (版本: $version)"
        ((PASSED++))
        return 0
    elif command -v docker-compose &> /dev/null && docker-compose --version &> /dev/null 2>&1; then
        local version=$(docker-compose --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1 || echo "unknown")
        log_success "Docker Compose 已安装 (版本: $version)"
        ((PASSED++))
        return 0
    else
        log_error "Docker Compose 未安装或无法正常工作"
        ((FAILED++))
        return 1
    fi
}

check_docker_service() {
    log_info "检查Docker服务状态..."
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行或无权限访问"
        log_info "请尝试: sudo systemctl start docker"
        log_info "或将用户添加到docker组: sudo usermod -aG docker \$USER"
        ((FAILED++))
        return 1
    else
        log_success "Docker服务正常运行"
        ((PASSED++))
        return 0
    fi
}

check_ports() {
    log_info "检查端口占用情况..."
    
    local ports=("8080" "3306" "6379")
    local port_names=("Web服务" "MySQL" "Redis")
    local all_free=true
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${port_names[$i]}"
        
        if command -v netstat &> /dev/null; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                log_warning "端口 $port ($name) 已被占用"
                ((WARNINGS++))
                all_free=false
            fi
        elif command -v ss &> /dev/null; then
            if ss -tuln 2>/dev/null | grep -q ":$port "; then
                log_warning "端口 $port ($name) 已被占用"
                ((WARNINGS++))
                all_free=false
            fi
        else
            log_warning "无法检查端口占用情况 (netstat/ss 未安装)"
            ((WARNINGS++))
            return 1
        fi
    done
    
    if [ "$all_free" = "true" ]; then
        log_success "所有必需端口都可用"
        ((PASSED++))
    fi
}

check_disk_space() {
    log_info "检查磁盘空间..."
    
    local available=$(df . | tail -1 | awk '{print $4}')
    local available_gb=$((available / 1024 / 1024))
    
    if [ "$available_gb" -lt 2 ]; then
        log_error "磁盘空间不足 (可用: ${available_gb}GB, 建议: 至少2GB)"
        ((FAILED++))
        return 1
    elif [ "$available_gb" -lt 5 ]; then
        log_warning "磁盘空间较少 (可用: ${available_gb}GB, 建议: 至少5GB)"
        ((WARNINGS++))
    else
        log_success "磁盘空间充足 (可用: ${available_gb}GB)"
        ((PASSED++))
    fi
}

check_memory() {
    log_info "检查内存..."
    
    if [ -f "/proc/meminfo" ]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}' 2>/dev/null || grep MemFree /proc/meminfo | awk '{print $2}')
        local mem_total_gb=$((mem_total / 1024 / 1024))
        local mem_available_gb=$((mem_available / 1024 / 1024))
        
        if [ "$mem_total_gb" -lt 2 ]; then
            log_warning "系统内存较少 (总计: ${mem_total_gb}GB, 建议: 至少2GB)"
            ((WARNINGS++))
        else
            log_success "系统内存充足 (总计: ${mem_total_gb}GB, 可用: ${mem_available_gb}GB)"
            ((PASSED++))
        fi
    else
        log_warning "无法检查内存信息"
        ((WARNINGS++))
    fi
}

check_env_file() {
    log_info "检查环境配置文件..."
    
    if [ -f ".env" ]; then
        log_success ".env 文件存在"
        
        # 检查关键配置
        if grep -q "OPENAI_API_KEY=" .env && ! grep -q "OPENAI_API_KEY=$" .env && ! grep -q "OPENAI_API_KEY=your_openai_api_key_here" .env; then
            log_success "OpenAI API Key 已配置"
        else
            log_warning "OpenAI API Key 未配置或使用默认值"
            ((WARNINGS++))
        fi
        
        ((PASSED++))
    else
        log_warning ".env 文件不存在，部署时将自动创建"
        ((WARNINGS++))
    fi
}

check_docker_compose_file() {
    log_info "检查Docker Compose配置文件..."
    
    if [ -f "docker-compose.yml" ]; then
        log_success "docker-compose.yml 文件存在"
        ((PASSED++))
    else
        log_error "docker-compose.yml 文件不存在"
        ((FAILED++))
        return 1
    fi
}

# 主验证流程
main() {
    echo "==========================================="
    echo "     Medical GPT 环境验证脚本 v1.0"
    echo "==========================================="
    echo
    
    log_info "开始环境验证..."
    echo
    
    # 基础命令检查
    log_info "=== 基础工具检查 ==="
    check_command "curl" "curl"
    check_command "wget" "wget" false
    check_command "git" "git"
    check_command "unzip" "unzip" false
    echo
    
    # Docker检查
    log_info "=== Docker环境检查 ==="
    check_command "docker" "Docker"
    check_docker_service
    check_docker_compose
    echo
    
    # 系统资源检查
    log_info "=== 系统资源检查 ==="
    check_disk_space
    check_memory
    check_ports
    echo
    
    # 项目文件检查
    log_info "=== 项目配置检查 ==="
    check_docker_compose_file
    check_env_file
    echo
    
    # 结果汇总
    echo "==========================================="
    echo "           验证结果汇总"
    echo "==========================================="
    log_success "通过检查: $PASSED 项"
    if [ "$WARNINGS" -gt 0 ]; then
        log_warning "警告: $WARNINGS 项"
    fi
    if [ "$FAILED" -gt 0 ]; then
        log_error "失败: $FAILED 项"
    fi
    echo
    
    if [ "$FAILED" -eq 0 ]; then
        log_success "环境验证通过！可以开始部署 Medical GPT"
        if [ "$WARNINGS" -gt 0 ]; then
            log_info "建议解决上述警告后再进行部署"
        fi
        echo
        log_info "推荐的部署命令："
        log_info "  ./deploy-cloud.sh          # 稳定版本 (推荐)"
        log_info "  ./quick-deploy-enhanced.sh # 增强版本"
        log_info "  ./quick-deploy.sh          # 简化版本"
        exit 0
    else
        log_error "环境验证失败！请解决上述问题后重试"
        echo
        log_info "常见解决方案："
        log_info "  1. 安装Docker: curl -fsSL https://get.docker.com | sudo sh"
        log_info "  2. 启动Docker: sudo systemctl start docker"
        log_info "  3. 添加用户到docker组: sudo usermod -aG docker \$USER"
        log_info "  4. 安装Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
}

# 执行主函数
main "$@"