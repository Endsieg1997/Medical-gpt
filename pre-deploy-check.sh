#!/bin/bash

# 医疗健康AI助手 - 部署前检查脚本
# 版本: 1.0
# 用途: 在部署前验证所有配置文件和依赖

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

# 检查必要文件
check_required_files() {
    log_info "检查必要文件..."
    
    local required_files=(
        ".env"
        "docker-compose.yml"
        "gptserver/composer.json"
        "gptserver/composer.lock"
        "docker/php/Dockerfile"
        "docker/php/php.ini"
        "docker/nginx/nginx.conf"
        "docker/nginx/conf.d/medical-gpt.conf"
        "docker/redis/redis.conf"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
            log_error "缺少文件: $file"
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log_success "所有必要文件都存在"
    else
        log_error "缺少 ${#missing_files[@]} 个必要文件"
        return 1
    fi
}

# 检查目录结构
check_directories() {
    log_info "检查目录结构..."
    
    local required_dirs=(
        "gptserver"
        "gptweb"
        "gptadmin"
        "docker/php"
        "docker/nginx"
        "docker/mysql"
        "docker/redis"
        "logs"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "缺少目录: $dir"
            return 1
        fi
    done
    
    log_success "目录结构正确"
}

# 检查环境变量
check_environment_variables() {
    log_info "检查环境变量配置..."
    
    if [ ! -f ".env" ]; then
        log_error ".env文件不存在"
        return 1
    fi
    
    # 加载环境变量
    source .env
    
    # 检查关键变量
    local required_vars=(
        "DB_HOST:mysql"
        "DB_DATABASE:gptlink_edu"
        "DB_USERNAME:gptlink"
        "DB_PASSWORD"
        "REDIS_HOST:redis"
        "REDIS_PASSWORD"
        "OPENAI_API_KEY"
        "OPENAI_MODEL:deepseek-chat"
        "OPENAI_HOST:https://api.deepseek.com"
    )
    
    local missing_vars=()
    
    for var_info in "${required_vars[@]}"; do
        IFS=':' read -r var_name expected_value <<< "$var_info"
        var_value=$(eval echo \$$var_name)
        
        if [ -z "$var_value" ]; then
            missing_vars+=("$var_name")
            log_error "环境变量未设置: $var_name"
        elif [ -n "$expected_value" ] && [ "$var_value" != "$expected_value" ]; then
            log_warning "环境变量值可能不正确: $var_name=$var_value (期望: $expected_value)"
        fi
    done
    
    # 检查API Key格式
    if [[ ! "$OPENAI_API_KEY" =~ ^sk- ]]; then
        log_warning "OPENAI_API_KEY格式可能不正确，应该以'sk-'开头"
    fi
    
    if [ ${#missing_vars[@]} -eq 0 ]; then
        log_success "环境变量配置正确"
    else
        log_error "缺少 ${#missing_vars[@]} 个必要的环境变量"
        return 1
    fi
}

# 检查Docker配置
check_docker_config() {
    log_info "检查Docker配置..."
    
    # 检查docker-compose.yml语法
    if ! docker-compose config > /dev/null 2>&1; then
        log_error "docker-compose.yml配置文件语法错误"
        docker-compose config
        return 1
    fi
    
    log_success "Docker配置正确"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."
    
    local ports=("80" "443" "3306" "6379" "9000" "9503")
    local occupied_ports=()
    
    for port in "${ports[@]}"; do
        if command -v netstat > /dev/null 2>&1; then
            if netstat -tuln | grep -q ":$port "; then
                occupied_ports+=("$port")
                log_warning "端口 $port 已被占用"
            fi
        elif command -v ss > /dev/null 2>&1; then
            if ss -tuln | grep -q ":$port "; then
                occupied_ports+=("$port")
                log_warning "端口 $port 已被占用"
            fi
        fi
    done
    
    if [ ${#occupied_ports[@]} -eq 0 ]; then
        log_success "所有必要端口都可用"
    else
        log_warning "有 ${#occupied_ports[@]} 个端口被占用，可能需要停止相关服务"
    fi
}

# 检查系统资源
check_system_resources() {
    log_info "检查系统资源..."
    
    # 检查磁盘空间
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local required_space=2097152  # 2GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_warning "磁盘空间不足，建议至少有2GB可用空间"
    else
        log_success "磁盘空间充足"
    fi
    
    # 检查内存
    if command -v free > /dev/null 2>&1; then
        local available_memory=$(free -m | awk 'NR==2{print $7}')
        if [ "$available_memory" -lt 1024 ]; then
            log_warning "可用内存不足，建议至少有1GB可用内存"
        else
            log_success "内存充足"
        fi
    fi
}

# 生成部署报告
generate_report() {
    log_info "生成部署检查报告..."
    
    local report_file="deployment-check-report.txt"
    
    cat > "$report_file" << EOF
医疗健康AI助手 - 部署前检查报告
生成时间: $(date)

=== 系统信息 ===
操作系统: $(uname -s)
架构: $(uname -m)
内核版本: $(uname -r)

=== Docker信息 ===
Docker版本: $(docker --version 2>/dev/null || echo "未安装")
Docker Compose版本: $(docker-compose --version 2>/dev/null || echo "未安装")

=== 环境变量 ===
APP_ENV: ${APP_ENV:-未设置}
MEDICAL_MODE: ${MEDICAL_MODE:-未设置}
DB_HOST: ${DB_HOST:-未设置}
REDIS_HOST: ${REDIS_HOST:-未设置}
OPENAI_MODEL: ${OPENAI_MODEL:-未设置}

=== 端口配置 ===
Web端口: 80, 443
MySQL端口: 3306
Redis端口: 6379
PHP端口: 9000, 9503

=== 建议 ===
1. 确保所有必要的端口都可用
2. 定期备份数据库数据
3. 监控系统资源使用情况
4. 及时更新Docker镜像
EOF
    
    log_success "部署检查报告已生成: $report_file"
}

# 主函数
main() {
    echo "=== 医疗健康AI助手 - 部署前检查 ==="
    echo "开始时间: $(date)"
    echo ""
    
    local check_passed=true
    
    # 执行所有检查
    check_required_files || check_passed=false
    check_directories || check_passed=false
    check_environment_variables || check_passed=false
    check_docker_config || check_passed=false
    check_ports
    check_system_resources
    
    # 生成报告
    generate_report
    
    echo ""
    if [ "$check_passed" = true ]; then
        log_success "所有检查通过，可以开始部署！"
        echo ""
        echo "下一步: 运行 ./deploy-cloud.sh 开始部署"
    else
        log_error "检查未通过，请修复上述问题后重新运行检查"
        exit 1
    fi
}

# 执行主函数
main "$@"