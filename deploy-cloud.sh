#!/bin/bash

# 医疗健康AI助手 - 云服务器部署脚本
# 适用于 Ubuntu/CentOS/Debian 等 Linux 发行版
# 版本: 3.0 - 增强兼容性版本
# 更新时间: 2024-01-15
# 作者: Medical AI Team

# 设置严格模式和兼容性选项
set -euo pipefail  # 遇到错误立即退出，未定义变量报错，管道错误传播
IFS=$'\n\t'      # 设置安全的字段分隔符

# 检测操作系统和架构
detect_system() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            VER=$VERSION_ID
        elif type lsb_release >/dev/null 2>&1; then
            OS=$(lsb_release -si)
            VER=$(lsb_release -sr)
        else
            OS=$(uname -s)
            VER=$(uname -r)
        fi
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    ARCH=$(uname -m)
    log_info "检测到系统: $OS $VER ($ARCH)"
}

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

# 自动安装Docker（兼容多种系统）
install_docker() {
    log_info "开始安装Docker..."
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            $SUDO_CMD apt-get update
            $SUDO_CMD apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null
            $SUDO_CMD apt-get update
            $SUDO_CMD apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            $SUDO_CMD yum install -y yum-utils
            $SUDO_CMD yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            $SUDO_CMD yum install -y docker-ce docker-ce-cli containerd.io
            ;;
        *)
            log_info "尝试使用通用安装脚本..."
            curl -fsSL https://get.docker.com | $SUDO_CMD sh
            ;;
    esac
    
    # 启动Docker服务
    $SUDO_CMD systemctl enable docker
    $SUDO_CMD systemctl start docker
    
    # 添加当前用户到docker组（如果不是root）
    if [[ $EUID -ne 0 ]]; then
        $SUDO_CMD usermod -aG docker $USER
        log_info "已将用户 $USER 添加到 docker 组，请重新登录或运行 'newgrp docker'"
    fi
    
    log_success "Docker 安装完成"
}

# 自动安装Docker Compose（兼容多种方式）
install_docker_compose() {
    log_info "开始安装Docker Compose..."
    
    # 尝试安装Docker Compose Plugin（推荐方式）
    if command -v docker &> /dev/null; then
        case "$OS" in
            *"Ubuntu"*|*"Debian"*)
                $SUDO_CMD apt-get update
                $SUDO_CMD apt-get install -y docker-compose-plugin
                ;;
            *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
                $SUDO_CMD yum install -y docker-compose-plugin
                ;;
            *)
                # 使用二进制安装方式
                local compose_version="v2.20.2"
                $SUDO_CMD curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                $SUDO_CMD chmod +x /usr/local/bin/docker-compose
                ;;
        esac
    fi
    
    # 验证安装
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose 安装完成"
    elif docker compose version &> /dev/null; then
        log_success "Docker Compose Plugin 安装完成"
    else
        log_error "Docker Compose 安装失败"
        exit 1
    fi
}

# 检查系统要求（增强兼容性）
check_requirements() {
    log_info "检查系统要求和兼容性..."
    
    # 检测系统信息
    detect_system
    
    # 检查是否为root用户或有sudo权限
    if [[ $EUID -eq 0 ]]; then
        log_info "当前用户: root"
        SUDO_CMD=""
    elif sudo -n true 2>/dev/null; then
        log_info "当前用户有sudo权限"
        SUDO_CMD="sudo"
    else
        log_error "需要root权限或sudo权限来安装依赖"
        log_info "请使用 'sudo $0' 运行此脚本"
        exit 1
    fi
    
    # 检查系统资源
    local mem_total=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local disk_free=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    
    log_info "系统内存: ${mem_total}MB"
    log_info "可用磁盘空间: ${disk_free}GB"
    
    if [ "$mem_total" -lt 1024 ]; then
        log_warning "内存不足2GB，可能影响性能"
    fi
    
    if [ "$disk_free" -lt 10 ]; then
        log_warning "磁盘空间不足10GB，可能影响安装"
    fi
    
    # 检查Docker（支持自动安装）
    if ! command -v docker &> /dev/null; then
        log_warning "Docker 未安装"
        read -p "是否自动安装Docker? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker
        else
            log_error "Docker 是必需的，请手动安装后重试"
            log_info "安装指南: https://docs.docker.com/get-docker/"
            exit 1
        fi
    else
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log_info "Docker 版本: $docker_version"
        
        # 检查Docker服务状态（支持自动启动）
        if ! docker info &> /dev/null; then
            log_warning "Docker 服务未运行，尝试启动..."
            if command -v systemctl &> /dev/null; then
                $SUDO_CMD systemctl start docker || {
                    log_error "无法启动Docker服务"
                    exit 1
                }
            elif command -v service &> /dev/null; then
                $SUDO_CMD service docker start || {
                    log_error "无法启动Docker服务"
                    exit 1
                }
            else
                log_error "无法启动Docker服务，请手动启动"
                exit 1
            fi
            
            # 再次检查
            sleep 2
            if ! docker info &> /dev/null; then
                log_error "Docker 服务启动失败"
                exit 1
            fi
        fi
    fi
    
    # 检查Docker Compose（支持自动安装）
    local compose_cmd=""
    if command -v docker-compose &> /dev/null; then
        compose_cmd="docker-compose"
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log_info "Docker Compose 版本: $compose_version"
    elif docker compose version &> /dev/null; then
        compose_cmd="docker compose"
        local compose_version=$(docker compose version --short)
        log_info "Docker Compose (plugin) 版本: $compose_version"
    else
        log_warning "Docker Compose 未安装"
        read -p "是否自动安装Docker Compose? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_docker_compose
            compose_cmd="docker-compose"
        else
            log_error "Docker Compose 是必需的，请手动安装后重试"
            log_info "安装指南: https://docs.docker.com/compose/install/"
            exit 1
        fi
    fi
    
    # 导出compose命令供其他函数使用
    export COMPOSE_CMD="$compose_cmd"
    
    # 网络连接检查（增强兼容性）
    log_info "检查网络连接..."
    local network_ok=false
    
    # 尝试多个DNS服务器
    local dns_servers=("8.8.8.8" "114.114.114.114" "1.1.1.1" "223.5.5.5")
    for dns in "${dns_servers[@]}"; do
        if ping -c 1 -W 3 "$dns" &> /dev/null 2>&1; then
            network_ok=true
            log_success "网络连接正常 (通过 $dns)"
            break
        fi
    done
    
    if [ "$network_ok" = false ]; then
        # 尝试HTTP连接测试
        if curl -s --connect-timeout 5 http://www.baidu.com > /dev/null 2>&1 || \
           wget --timeout=5 --tries=1 -q --spider http://www.baidu.com > /dev/null 2>&1; then
            network_ok=true
            log_success "网络连接正常 (通过HTTP)"
        fi
    fi
    
    if [ "$network_ok" = false ]; then
        log_warning "网络连接检查失败，这可能影响Docker镜像下载和依赖安装"
        log_info "请检查网络设置或防火墙配置"
    fi
    
    # 环境变量验证（增强兼容性）
    log_info "验证环境变量配置..."
    local env_file=".env"
    
    if [[ ! -f "$env_file" ]]; then
        log_warning "未找到 .env 文件，将创建默认配置"
        create_default_env_file
    else
        log_info "检查现有 .env 文件..."
        validate_env_file "$env_file"
    fi
    
    # 配置文件完整性检查
    log_info "检查配置文件完整性..."
    local required_files=(
        "docker-compose.yml"
        "gptserver/composer.json"
        "docker/php/Dockerfile"
        "docker/mysql/my.cnf"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "缺少必要文件: $file"
            exit 1
        else
            log_success "✓ $file"
        fi
    done
    
    log_success "系统要求检查完成"
}

# 创建默认环境变量文件
create_default_env_file() {
    log_info "创建默认 .env 文件..."
    
    cat > .env << 'EOF'
# 数据库配置
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=medical_gpt
DB_USERNAME=root
DB_PASSWORD=123456

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

# 医疗模式配置
MEDICAL_MODE=true
SESSION_TIMEOUT=3600

# 安全配置
APP_KEY=base64:$(openssl rand -base64 32 2>/dev/null || echo "your_app_key_here")
JWT_SECRET=$(openssl rand -base64 64 2>/dev/null || echo "your_jwt_secret_here")

# 端口配置
WEB_PORT=8080
MYSQL_PORT=3306
REDIS_PORT=6379
EOF
    
    log_success "默认 .env 文件已创建"
    log_warning "请编辑 .env 文件，设置正确的配置值"
}

# 验证环境变量文件
validate_env_file() {
    local env_file="$1"
    local required_vars=(
        "DB_HOST" "DB_DATABASE" "DB_USERNAME" "DB_PASSWORD"
        "REDIS_HOST" "OPENAI_API_KEY" "APP_NAME" "APP_ENV"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$env_file"; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_warning "以下环境变量缺失或未设置:"
        for var in "${missing_vars[@]}"; do
            log_warning "  - $var"
        done
        
        read -p "是否自动添加缺失的环境变量? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            add_missing_env_vars "$env_file" "${missing_vars[@]}"
        fi
    else
        log_success "环境变量配置完整"
    fi
}

# 添加缺失的环境变量
add_missing_env_vars() {
    local env_file="$1"
    shift
    local missing_vars=("$@")
    
    log_info "添加缺失的环境变量到 $env_file..."
    
    for var in "${missing_vars[@]}"; do
        case "$var" in
            "DB_HOST") echo "DB_HOST=mysql" >> "$env_file" ;;
            "DB_DATABASE") echo "DB_DATABASE=medical_gpt" >> "$env_file" ;;
            "DB_USERNAME") echo "DB_USERNAME=root" >> "$env_file" ;;
            "DB_PASSWORD") echo "DB_PASSWORD=123456" >> "$env_file" ;;
            "REDIS_HOST") echo "REDIS_HOST=redis" >> "$env_file" ;;
            "OPENAI_API_KEY") echo "OPENAI_API_KEY=your_openai_api_key_here" >> "$env_file" ;;
            "APP_NAME") echo "APP_NAME=Medical GPT" >> "$env_file" ;;
            "APP_ENV") echo "APP_ENV=production" >> "$env_file" ;;
            *) echo "${var}=" >> "$env_file" ;;
        esac
        log_success "✓ 已添加 $var"
    done

# 安装Docker
install_docker() {
    log_info "安装Docker..."
    
    # 更新包管理器
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    elif command -v yum &> /dev/null; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
    else
        log_error "不支持的包管理器，请手动安装Docker"
        exit 1
    fi
    
    # 启动Docker服务
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 添加当前用户到docker组
    sudo usermod -aG docker $USER
    
    log_success "Docker安装完成"
}

# 安装Docker Compose
install_docker_compose() {
    log_info "安装Docker Compose..."
    
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker Compose安装完成"
}



# 配置域名
config_domain() {
    log_info "配置域名设置..."
    
    read -p "请输入您的域名（如：example.com，留空使用IP访问）: " DOMAIN_NAME
    
    if [ -n "$DOMAIN_NAME" ]; then
        # 更新.env文件中的域名
        sed -i "s|APP_URL=.*|APP_URL=http://$DOMAIN_NAME|g" .env
        
        # 更新Nginx配置中的域名
        sed -i "s|medicalgpt.asia|$DOMAIN_NAME|g" docker/nginx/conf.d/medical-gpt.conf
        
        log_success "域名配置完成: $DOMAIN_NAME"
        
        # 询问是否配置SSL
        read -p "是否配置SSL证书？(y/n): " SETUP_SSL
        if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
            setup_ssl
        fi
    else
        # 获取服务器IP
        SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "未知IP")
        sed -i "s|APP_URL=.*|APP_URL=http://$SERVER_IP|g" .env
        log_success "配置完成，将使用IP访问: $SERVER_IP"
    fi
}

# 配置SSL证书
setup_ssl() {
    log_info "配置SSL证书..."
    
    # 安装certbot
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif command -v yum &> /dev/null; then
        sudo yum install -y certbot
    fi
    
    # 创建SSL证书目录
    mkdir -p ssl_certs
    
    log_info "请确保域名已正确解析到此服务器IP"
    read -p "按回车键继续申请SSL证书..."
    
    # 申请SSL证书
    sudo certbot certonly --standalone -d $DOMAIN_NAME
    
    # 复制证书到项目目录
    sudo cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem ssl_certs/cert.pem
    sudo cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem ssl_certs/key.pem
    sudo chown $USER:$USER ssl_certs/*.pem
    
    # 启用HTTPS配置
    sed -i 's|# server {|server {|g' docker/nginx/conf.d/medical-gpt.conf
    sed -i 's|#     listen 443|    listen 443|g' docker/nginx/conf.d/medical-gpt.conf
    sed -i 's|#     server_name|    server_name|g' docker/nginx/conf.d/medical-gpt.conf
    sed -i 's|#     ssl_|    ssl_|g' docker/nginx/conf.d/medical-gpt.conf
    sed -i 's|# }|}|g' docker/nginx/conf.d/medical-gpt.conf
    
    # 更新APP_URL为HTTPS
    sed -i "s|APP_URL=http://|APP_URL=https://|g" .env
    
    log_success "SSL证书配置完成"
}

# 检查和配置环境变量
setup_environment() {
    log_info "配置环境变量..."
    
    # 检查.env文件是否存在
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            log_info "复制.env.example到.env"
            cp .env.example .env
        else
            log_error ".env文件不存在，请先创建.env文件"
            exit 1
        fi
    fi
    
    # 检查关键环境变量
    source .env
    
    if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your-api-key-here" ]; then
        log_warning "请配置OPENAI_API_KEY"
        read -p "请输入您的DeepSeek API Key: " API_KEY
        sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$API_KEY|g" .env
    fi
    
    # 检查数据库密码
    if [ -z "$DB_PASSWORD" ]; then
        log_warning "数据库密码未设置，使用默认密码"
        sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=666666|g" .env
    fi
    
    # 检查Redis密码
    if [ -z "$REDIS_PASSWORD" ]; then
        log_warning "Redis密码未设置，使用默认密码"
        sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=666666|g" .env
    fi
    
    log_success "环境变量配置完成"
}

# 创建必要目录
create_directories() {
    log_info "创建必要的目录..."
    
    mkdir -p logs/{nginx,mysql,php}
    mkdir -p data/{mysql,redis}
    mkdir -p ssl_certs
    
    # 设置权限
    chmod -R 755 logs/
    chmod -R 755 data/
    
    log_success "目录创建完成"
}

# 验证配置文件
validate_configs() {
    log_info "验证配置文件..."
    
    # 检查docker-compose.yml
    if ! docker-compose config > /dev/null 2>&1; then
        log_error "docker-compose.yml配置文件有误"
        docker-compose config
        exit 1
    fi
    
    # 检查必要文件
    local required_files=(
        "gptserver/composer.json"
        "docker/php/Dockerfile"
        "docker/nginx/nginx.conf"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "必要文件不存在: $file"
            exit 1
        fi
    done
    
    log_success "配置文件验证通过"
}

# 部署应用（增强兼容性和错误处理）
deploy_application() {
    log_info "开始部署应用..."
    
    # 创建备份点
    local backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    create_backup "$backup_dir"
    
    # 预检查
    log_info "执行部署前检查..."
    pre_deployment_check
    
    # 停止现有服务（增强错误处理）
    log_info "停止现有服务..."
    if $COMPOSE_CMD ps -q | grep -q .; then
        log_info "发现运行中的服务，正在停止..."
        $COMPOSE_CMD down --remove-orphans --timeout 30 || {
            log_warning "优雅停止失败，强制停止..."
            $COMPOSE_CMD kill
            $COMPOSE_CMD down --remove-orphans
        }
    else
        log_info "没有运行中的服务"
    fi
    
    # 清理资源（可选）
    read -p "是否清理旧的Docker资源? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "清理旧的镜像和容器..."
        docker system prune -f 2>/dev/null || true
        docker volume prune -f 2>/dev/null || true
    fi
    
    # 构建服务（分步进行）
    log_info "构建Docker镜像..."
    if ! $COMPOSE_CMD build --no-cache --parallel; then
        log_error "镜像构建失败"
        rollback_deployment "$backup_dir"
        exit 1
    fi
    
    # 启动基础服务（MySQL, Redis）
    log_info "启动基础服务..."
    if ! $COMPOSE_CMD up -d mysql redis; then
        log_error "基础服务启动失败"
        rollback_deployment "$backup_dir"
        exit 1
    fi
    
    # 等待基础服务就绪
    log_info "等待基础服务就绪..."
    wait_for_services
    
    # 启动应用服务
    log_info "启动应用服务..."
    if ! $COMPOSE_CMD up -d gptserver; then
        log_error "应用服务启动失败"
        rollback_deployment "$backup_dir"
        exit 1
    fi
    
    # 健康检查
    log_info "执行健康检查..."
    if ! health_check; then
        log_error "健康检查失败"
        rollback_deployment "$backup_dir"
        exit 1
    fi
    
    # 部署成功
    log_success "应用部署成功！"
    
    # 显示服务状态
    log_info "服务状态:"
    $COMPOSE_CMD ps
    
    # 显示访问信息
    show_access_info
    
    # 清理备份（可选）
    read -p "部署成功，是否删除备份? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$backup_dir"
        log_info "备份已清理"
    else
        log_info "备份保存在: $backup_dir"
    fi
}

# 创建备份
create_backup() {
    local backup_dir="$1"
    log_info "创建备份到: $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # 备份配置文件
    if [ -f ".env" ]; then
        cp ".env" "$backup_dir/"
    fi
    
    if [ -f "docker-compose.yml" ]; then
        cp "docker-compose.yml" "$backup_dir/"
    fi
    
    # 备份数据（如果存在）
    if [ -d "data" ]; then
        cp -r "data" "$backup_dir/"
    fi
    
    log_success "备份创建完成"
}

# 部署前检查
pre_deployment_check() {
    log_info "执行部署前检查..."
    
    # 检查磁盘空间
    local disk_free=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$disk_free" -lt 5 ]; then
        log_error "磁盘空间不足5GB，无法继续部署"
        exit 1
    fi
    
    # 检查内存
    local mem_free=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$mem_free" -lt 512 ]; then
        log_warning "可用内存不足512MB，可能影响部署"
    fi
    
    # 检查Docker服务
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行"
        exit 1
    fi
    
    log_success "部署前检查通过"
}

# 回滚部署
rollback_deployment() {
    local backup_dir="$1"
    log_warning "开始回滚部署..."
    
    # 停止服务
    $COMPOSE_CMD down --remove-orphans 2>/dev/null || true
    
    # 恢复配置文件
    if [ -d "$backup_dir" ]; then
        if [ -f "$backup_dir/.env" ]; then
            cp "$backup_dir/.env" "."
        fi
        
        if [ -f "$backup_dir/docker-compose.yml" ]; then
            cp "$backup_dir/docker-compose.yml" "."
        fi
        
        if [ -d "$backup_dir/data" ]; then
            rm -rf "data"
            cp -r "$backup_dir/data" "."
        fi
    fi
    
    log_info "回滚完成，备份保存在: $backup_dir"
}

# 显示访问信息
show_access_info() {
    log_info "应用访问信息:"
    
    # 获取配置的端口
    local web_port=$(grep "WEB_PORT" .env 2>/dev/null | cut -d'=' -f2 || echo "8080")
    
    # 获取服务器IP或域名
    local app_url=$(grep "APP_URL" .env 2>/dev/null | cut -d'=' -f2 || echo "http://localhost:$web_port")
    
    echo "  网站地址: $app_url"
    echo "  管理后台: $app_url/admin"
    echo "  API文档: $app_url/api/docs"
    
    if $COMPOSE_CMD ps | grep -q "phpmyadmin"; then
        echo "  数据库管理: http://localhost:8081"
    fi
}

# 启动服务（保持向后兼容）
start_services() {
    log_info "启动Docker服务..."
    deploy_application
}

# 等待服务就绪（增强兼容性）
wait_for_services() {
    log_info "等待服务启动..."
    
    # 等待MySQL（多种检查方式）
    log_info "等待MySQL服务..."
    local mysql_ready=false
    for i in {1..60}; do
        # 方式1: 使用mysqladmin
        if $COMPOSE_CMD exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
            mysql_ready=true
        # 方式2: 使用mysql客户端
        elif $COMPOSE_CMD exec -T mysql mysql -u root -p123456 -e "SELECT 1" 2>/dev/null; then
            mysql_ready=true
        # 方式3: 检查端口
        elif $COMPOSE_CMD exec -T mysql netstat -ln | grep -q ":3306"; then
            mysql_ready=true
        fi
        
        if [ "$mysql_ready" = true ]; then
            log_success "MySQL服务已就绪"
            break
        fi
        
        if [ $i -eq 60 ]; then
            log_error "MySQL服务启动超时"
            $COMPOSE_CMD logs mysql
            return 1
        fi
        
        printf "."
        sleep 2
    done
    echo
    
    # 等待Redis（多种检查方式）
    log_info "等待Redis服务..."
    local redis_ready=false
    for i in {1..30}; do
        # 方式1: 使用redis-cli ping
        if $COMPOSE_CMD exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; then
            redis_ready=true
        # 方式2: 检查端口
        elif $COMPOSE_CMD exec -T redis netstat -ln | grep -q ":6379"; then
            redis_ready=true
        # 方式3: 使用nc检查端口
        elif $COMPOSE_CMD exec -T redis nc -z localhost 6379 2>/dev/null; then
            redis_ready=true
        fi
        
        if [ "$redis_ready" = true ]; then
            log_success "Redis服务已就绪"
            break
        fi
        
        if [ $i -eq 30 ]; then
            log_error "Redis服务启动超时"
            $COMPOSE_CMD logs redis
            return 1
        fi
        
        printf "."
        sleep 2
    done
    echo
    
    return 0
}

# 健康检查（增强功能）
health_check() {
    log_info "执行健康检查..."
    
    local web_port=$(grep "WEB_PORT" .env 2>/dev/null | cut -d'=' -f2 || echo "8080")
    local health_url="http://localhost:${web_port}"
    
    # 检查Web服务（多种方式）
    log_info "检查Web服务..."
    local web_ready=false
    for i in {1..30}; do
        # 方式1: 检查健康端点
        if curl -f "${health_url}/health" > /dev/null 2>&1; then
            web_ready=true
        # 方式2: 检查主页
        elif curl -f "${health_url}" > /dev/null 2>&1; then
            web_ready=true
        # 方式3: 检查端口是否开放
        elif nc -z localhost "$web_port" 2>/dev/null; then
            web_ready=true
        fi
        
        if [ "$web_ready" = true ]; then
            log_success "Web服务正常"
            break
        fi
        
        if [ $i -eq 30 ]; then
            log_warning "Web服务健康检查失败，但可能仍在启动中"
            return 1
        fi
        
        printf "."
        sleep 3
    done
    echo
    
    # 检查容器状态
    log_info "检查容器状态..."
    local unhealthy_containers=()
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            local status=$($COMPOSE_CMD ps -q "$container" | xargs docker inspect --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
            if [ "$status" = "unhealthy" ]; then
                unhealthy_containers+=("$container")
            fi
        fi
    done < <($COMPOSE_CMD config --services)
    
    if [ ${#unhealthy_containers[@]} -gt 0 ]; then
        log_warning "发现不健康的容器: ${unhealthy_containers[*]}"
        return 1
    fi
    
    # 检查服务连接性
    log_info "检查服务连接性..."
    if $COMPOSE_CMD exec -T gptserver php -r "echo 'PHP OK';" 2>/dev/null | grep -q "PHP OK"; then
        log_success "PHP服务连接正常"
    else
        log_warning "PHP服务连接检查失败"
    fi
    
    log_success "健康检查完成"
    return 0
}

# 显示部署信息
show_deployment_info() {
    log_success "医疗健康AI助手云服务器部署完成！"
    echo ""
    echo "=== 访问信息 ==="
    
    if [ -n "$DOMAIN_NAME" ]; then
        if [[ $(grep -c "https://" .env) -gt 0 ]]; then
            echo "网站地址: https://$DOMAIN_NAME"
            echo "管理后台: https://$DOMAIN_NAME/admin"
        else
            echo "网站地址: http://$DOMAIN_NAME"
            echo "管理后台: http://$DOMAIN_NAME/admin"
        fi
    else
        SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "服务器IP")
        echo "网站地址: http://$SERVER_IP"
        echo "管理后台: http://$SERVER_IP/admin"
    fi
    
    echo ""
    echo "=== 管理员账号 ==="
    echo "用户名: admin"
    echo "密码: 666666"
    echo ""
    echo "=== 服务管理 ==="
    echo "查看服务状态: docker-compose ps"
    echo "查看日志: docker-compose logs -f"
    echo "重启服务: docker-compose restart"
    echo "停止服务: docker-compose down"
    echo ""
    echo "=== 安全提醒 ==="
    echo "1. 请及时修改默认密码"
    echo "2. 定期更新系统和Docker镜像"
    echo "3. 监控服务器资源使用情况"
    echo "4. 定期备份数据库数据"
    echo ""
}

# 主函数
main() {
    echo "=== 医疗健康AI助手 - 云服务器部署脚本 ==="
    echo "版本: 1.0"
    echo "开始时间: $(date)"
    echo ""
    
    # 检查是否为root用户
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到root用户，建议使用普通用户运行此脚本"
        read -p "是否继续？(y/n): " CONTINUE
        if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    check_requirements
    setup_environment
    config_domain
    create_directories
    validate_configs
    deploy_application
    show_deployment_info
    
    log_success "云服务器部署完成！"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"