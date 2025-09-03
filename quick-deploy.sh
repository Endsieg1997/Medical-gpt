#!/bin/bash

# 医疗健康AI助手 - 快速部署脚本
# 版本: 1.0
# 用途: 一键部署医疗AI助手到云服务器

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

# 显示欢迎信息
show_welcome() {
    clear
    echo "======================================"
    echo "   医疗健康AI助手 - 快速部署工具   "
    echo "======================================"
    echo "版本: 1.0"
    echo "时间: $(date)"
    echo "======================================"
    echo ""
}

# 检查系统要求
check_system() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "此脚本仅支持Linux系统"
        exit 1
    fi
    
    # 检查是否为root用户
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到root用户，建议使用普通用户运行"
        read -p "是否继续？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "系统检查通过"
}

# 安装Docker和Docker Compose
install_docker() {
    if ! command -v docker &> /dev/null; then
        log_info "安装Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        log_success "Docker安装完成"
    else
        log_success "Docker已安装"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_info "安装Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose安装完成"
    else
        log_success "Docker Compose已安装"
    fi
}

# 配置环境变量
setup_environment() {
    log_info "配置环境变量..."
    
    # 检查.env文件
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            log_info "已复制.env.example到.env"
        else
            log_error ".env文件不存在"
            exit 1
        fi
    fi
    
    # 交互式配置关键参数
    echo ""
    echo "=== 配置关键参数 ==="
    
    # API Key配置
    current_api_key=$(grep "OPENAI_API_KEY=" .env | cut -d'=' -f2)
    if [ -z "$current_api_key" ] || [ "$current_api_key" = "your-api-key-here" ]; then
        echo "请输入您的DeepSeek API Key:"
        read -p "API Key: " api_key
        sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$api_key|g" .env
    fi
    
    # 域名配置
    echo "请输入您的域名（留空使用IP访问）:"
    read -p "域名: " domain_name
    if [ -n "$domain_name" ]; then
        sed -i "s|APP_URL=.*|APP_URL=http://$domain_name|g" .env
    else
        server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "localhost")
        sed -i "s|APP_URL=.*|APP_URL=http://$server_ip|g" .env
        log_info "将使用IP访问: $server_ip"
    fi
    
    # 密码配置
    echo "是否修改默认密码？(当前: 666666)"
    read -p "修改密码 (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "请输入新密码:"
        read -s -p "新密码: " new_password
        echo
        sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$new_password|g" .env
        sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$new_password|g" .env
        sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=$new_password|g" .env
        log_success "密码已更新"
    fi
    
    log_success "环境变量配置完成"
}

# 运行部署前检查
run_pre_check() {
    log_info "运行部署前检查..."
    
    if [ -f "./pre-deploy-check.sh" ]; then
        chmod +x ./pre-deploy-check.sh
        if ./pre-deploy-check.sh; then
            log_success "部署前检查通过"
        else
            log_error "部署前检查失败"
            exit 1
        fi
    else
        log_warning "未找到pre-deploy-check.sh，跳过详细检查"
    fi
}

# 部署服务
deploy_services() {
    log_info "开始部署服务..."
    
    # 创建必要目录
    mkdir -p logs/{nginx,mysql,php}
    mkdir -p ssl_certs
    
    # 停止现有服务
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # 构建并启动服务
    log_info "构建Docker镜像（这可能需要几分钟）..."
    docker-compose build --no-cache
    
    log_info "启动服务容器..."
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_success "服务部署成功"
    else
        log_error "服务启动失败"
        docker-compose logs
        exit 1
    fi
}

# 配置SSL（可选）
setup_ssl() {
    if [ -n "$domain_name" ]; then
        echo ""
        echo "是否配置SSL证书？"
        read -p "配置SSL (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "配置SSL证书..."
            
            # 安装certbot
            if command -v apt-get &> /dev/null; then
                sudo apt-get update
                sudo apt-get install -y certbot
            elif command -v yum &> /dev/null; then
                sudo yum install -y certbot
            fi
            
            # 临时停止nginx容器
            docker-compose stop nginx
            
            # 申请证书
            sudo certbot certonly --standalone -d $domain_name
            
            # 复制证书
            sudo cp /etc/letsencrypt/live/$domain_name/fullchain.pem ssl_certs/cert.pem
            sudo cp /etc/letsencrypt/live/$domain_name/privkey.pem ssl_certs/key.pem
            sudo chown $USER:$USER ssl_certs/*.pem
            
            # 更新配置
            sed -i "s|APP_URL=http://|APP_URL=https://|g" .env
            
            # 重启nginx
            docker-compose start nginx
            
            log_success "SSL证书配置完成"
        fi
    fi
}

# 显示部署结果
show_result() {
    echo ""
    echo "======================================"
    echo "        部署完成！        "
    echo "======================================"
    
    # 获取访问地址
    app_url=$(grep "APP_URL=" .env | cut -d'=' -f2)
    
    echo "访问地址: $app_url"
    echo "管理后台: $app_url/admin"
    echo ""
    echo "默认管理员账号:"
    echo "用户名: admin"
    admin_password=$(grep "ADMIN_PASSWORD=" .env | cut -d'=' -f2)
    echo "密码: $admin_password"
    echo ""
    echo "=== 常用命令 ==="
    echo "查看服务状态: docker-compose ps"
    echo "查看日志: docker-compose logs -f"
    echo "重启服务: docker-compose restart"
    echo "停止服务: docker-compose down"
    echo ""
    echo "=== 重要提醒 ==="
    echo "1. 请及时修改默认密码"
    echo "2. 定期备份数据库数据"
    echo "3. 监控服务器资源使用"
    echo "4. 定期更新系统和镜像"
    echo "======================================"
}

# 主函数
main() {
    show_welcome
    
    # 确认开始部署
    echo "此脚本将自动部署医疗健康AI助手到当前服务器"
    read -p "是否继续？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "部署已取消"
        exit 0
    fi
    
    # 执行部署步骤
    check_system
    install_docker
    setup_environment
    run_pre_check
    deploy_services
    setup_ssl
    show_result
    
    log_success "快速部署完成！"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"