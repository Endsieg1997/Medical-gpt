#!/bin/bash

# 医疗健康AI助手 - 云服务器部署脚本
# 版本: 1.0
# 适用于: 云服务器外网部署
# 作者: Medical AI Team

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

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "检测到Linux系统"
    else
        log_error "此脚本仅支持Linux系统"
        exit 1
    fi
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，正在安装..."
        install_docker
    else
        log_success "Docker已安装"
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，正在安装..."
        install_docker_compose
    else
        log_success "Docker Compose已安装"
    fi
}

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

# 启动服务
start_services() {
    log_info "启动Docker服务..."
    
    # 停止现有服务
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # 清理旧镜像（可选）
    read -p "是否清理旧的Docker镜像？(y/n): " CLEAN_IMAGES
    if [[ $CLEAN_IMAGES =~ ^[Yy]$ ]]; then
        docker system prune -f
    fi
    
    # 构建并启动服务
    log_info "构建Docker镜像..."
    docker-compose build --no-cache
    
    log_info "启动服务容器..."
    docker-compose up -d
    
    log_success "服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    # 等待30秒让服务完全启动
    sleep 30
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败，请检查日志"
        docker-compose logs
        exit 1
    fi
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 检查Web服务
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_success "Web服务正常"
    else
        log_warning "Web服务可能需要更多时间启动"
    fi
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
    start_services
    wait_for_services
    health_check
    show_deployment_info
    
    log_success "云服务器部署完成！"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"