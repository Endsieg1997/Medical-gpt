#!/bin/bash

# 医疗健康AI助手 - 阿里云服务器部署脚本
# 版本: 2.0
# 作者: Medical AI Team
# 日期: 2024-01-15
# 描述: 专为阿里云ECS服务器优化的一键部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_NAME="medical-gpt"
PROJECT_DIR="/opt/${PROJECT_NAME}"
BACKUP_DIR="/opt/backups/${PROJECT_NAME}"
LOG_FILE="/var/log/${PROJECT_NAME}-deploy.log"
COMPOSE_FILE="docker-compose.aliyun.yml"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a $LOG_FILE
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a $LOG_FILE
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a $LOG_FILE
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a $LOG_FILE
}

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1" | tee -a $LOG_FILE
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1" | tee -a $LOG_FILE
}

# 显示横幅
show_banner() {
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "          医疗健康AI助手 - 阿里云部署脚本 v2.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "部署目录: $PROJECT_DIR"
    echo "日志文件: $LOG_FILE"
    echo ""
}

# 检查运行权限
check_permissions() {
    log_step "检查运行权限..."
    
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到以root用户运行，建议使用普通用户并配置sudo权限"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "部署已取消"
            exit 1
        fi
    fi
    
    # 检查sudo权限
    if ! sudo -n true 2>/dev/null; then
        log_error "需要sudo权限，请确保当前用户在sudoers中"
        exit 1
    fi
    
    log_success "权限检查通过"
}

# 检查系统环境
check_system() {
    log_step "检查系统环境..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法识别操作系统"
        exit 1
    fi
    
    source /etc/os-release
    log_info "操作系统: $PRETTY_NAME"
    
    # 检查系统资源
    local mem_total=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local disk_free=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    local cpu_cores=$(nproc)
    
    log_info "系统资源: CPU ${cpu_cores}核, 内存 ${mem_total}MB, 可用磁盘 ${disk_free}GB"
    
    # 检查最低要求
    if [[ $mem_total -lt 3000 ]]; then
        log_warning "内存不足4GB，可能影响性能"
    fi
    
    if [[ $disk_free -lt 20 ]]; then
        log_error "可用磁盘空间不足20GB"
        exit 1
    fi
    
    log_success "系统环境检查通过"
}

# 安装系统依赖
install_dependencies() {
    log_step "安装系统依赖..."
    
    # 更新包管理器
    log_info "更新包管理器..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y curl wget git unzip htop iotop nethogs ufw fail2ban
    elif command -v yum &> /dev/null; then
        sudo yum update -y -q
        sudo yum install -y curl wget git unzip htop iotop nethogs firewalld
    else
        log_error "不支持的包管理器"
        exit 1
    fi
    
    log_success "系统依赖安装完成"
}

# 安装Docker
install_docker() {
    log_step "安装Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker已安装: $(docker --version)"
    else
        log_info "开始安装Docker..."
        
        # 使用阿里云Docker安装脚本
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh --mirror Aliyun
        rm get-docker.sh
        
        # 启动Docker服务
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # 添加用户到docker组
        sudo usermod -aG docker $USER
        
        log_success "Docker安装完成"
    fi
    
    # 配置Docker镜像加速器
    log_info "配置Docker镜像加速器..."
    sudo mkdir -p /etc/docker
    
    cat << EOF | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://reg-mirror.qiniu.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    
    log_success "Docker镜像加速器配置完成"
}

# 安装Docker Compose
install_docker_compose() {
    log_step "安装Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose已安装: $(docker-compose --version)"
    else
        log_info "开始安装Docker Compose..."
        
        # 获取最新版本号
        local latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        # 下载并安装
        sudo curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        # 创建软链接
        sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        log_success "Docker Compose安装完成: $(docker-compose --version)"
    fi
}

# 配置防火墙
setup_firewall() {
    log_step "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian使用UFW
        log_info "配置UFW防火墙..."
        
        sudo ufw --force reset
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        
        # 允许SSH
        sudo ufw allow ssh
        
        # 允许HTTP和HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        
        # 启用防火墙
        sudo ufw --force enable
        
        log_success "UFW防火墙配置完成"
        
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL使用firewalld
        log_info "配置firewalld防火墙..."
        
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        
        # 允许HTTP和HTTPS
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --permanent --add-service=ssh
        
        # 重载配置
        sudo firewall-cmd --reload
        
        log_success "firewalld防火墙配置完成"
    else
        log_warning "未找到防火墙工具，请手动配置防火墙"
    fi
}

# 创建项目目录结构
setup_directories() {
    log_step "创建项目目录结构..."
    
    # 创建主要目录
    sudo mkdir -p $PROJECT_DIR
    sudo mkdir -p $BACKUP_DIR
    sudo mkdir -p /var/log
    
    # 创建项目子目录
    mkdir -p $PROJECT_DIR/{logs,data,ssl_certs,monitoring}
    mkdir -p $PROJECT_DIR/logs/{nginx,mysql,php,redis}
    mkdir -p $PROJECT_DIR/data/{mysql,redis}
    
    # 设置权限
    sudo chown -R $USER:$USER $PROJECT_DIR
    sudo chown -R $USER:$USER $BACKUP_DIR
    chmod -R 755 $PROJECT_DIR
    chmod -R 755 $BACKUP_DIR
    
    log_success "目录结构创建完成"
}

# 检查环境配置
check_environment_config() {
    log_step "检查环境配置..."
    
    local env_file="$PROJECT_DIR/gptserver/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_warning "环境配置文件不存在，从示例文件创建..."
        
        if [[ -f "$PROJECT_DIR/gptserver/.env.example" ]]; then
            cp "$PROJECT_DIR/gptserver/.env.example" "$env_file"
            log_info "已创建环境配置文件: $env_file"
        else
            log_error "找不到环境配置示例文件"
            exit 1
        fi
    fi
    
    # 检查关键配置项
    local missing_configs=()
    
    if ! grep -q "OPENAI_API_KEY=" "$env_file" || grep -q "OPENAI_API_KEY=$" "$env_file"; then
        missing_configs+=("OPENAI_API_KEY")
    fi
    
    if [[ ${#missing_configs[@]} -gt 0 ]]; then
        log_warning "以下配置项需要设置: ${missing_configs[*]}"
        log_info "请编辑文件: $env_file"
        
        read -p "是否现在编辑配置文件？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} "$env_file"
        fi
    fi
    
    log_success "环境配置检查完成"
}

# 拉取Docker镜像
pull_docker_images() {
    log_step "拉取Docker镜像..."
    
    cd $PROJECT_DIR
    
    # 拉取所需镜像
    local images=("mysql:8.0" "redis:7-alpine" "nginx:alpine")
    
    for image in "${images[@]}"; do
        log_info "拉取镜像: $image"
        docker pull $image
    done
    
    log_success "Docker镜像拉取完成"
}

# 部署服务
deploy_services() {
    log_step "部署服务..."
    
    cd $PROJECT_DIR
    
    # 检查compose文件
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "找不到Docker Compose配置文件: $COMPOSE_FILE"
        exit 1
    fi
    
    # 停止现有服务
    log_info "停止现有服务..."
    docker-compose -f $COMPOSE_FILE down --remove-orphans 2>/dev/null || true
    
    # 清理未使用的资源
    log_info "清理Docker资源..."
    docker system prune -f
    
    # 构建并启动服务
    log_info "构建并启动服务..."
    docker-compose -f $COMPOSE_FILE up -d --build
    
    log_success "服务部署完成"
}

# 等待服务就绪
wait_for_services() {
    log_step "等待服务就绪..."
    
    cd $PROJECT_DIR
    
    # 等待MySQL
    log_info "等待MySQL服务..."
    local timeout=120
    while [ $timeout -gt 0 ]; do
        if docker-compose -f $COMPOSE_FILE exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
            log_success "MySQL服务已就绪"
            break
        fi
        sleep 3
        timeout=$((timeout-3))
        echo -n "."
    done
    echo
    
    if [ $timeout -le 0 ]; then
        log_error "MySQL服务启动超时"
        docker-compose -f $COMPOSE_FILE logs mysql
        exit 1
    fi
    
    # 等待Redis
    log_info "等待Redis服务..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker-compose -f $COMPOSE_FILE exec -T redis redis-cli ping > /dev/null 2>&1; then
            log_success "Redis服务已就绪"
            break
        fi
        sleep 2
        timeout=$((timeout-2))
        echo -n "."
    done
    echo
    
    if [ $timeout -le 0 ]; then
        log_error "Redis服务启动超时"
        docker-compose -f $COMPOSE_FILE logs redis
        exit 1
    fi
    
    # 等待应用服务
    log_info "等待应用服务..."
    sleep 20
    
    # 等待Nginx
    log_info "等待Nginx服务..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -f http://localhost/health > /dev/null 2>&1; then
            log_success "Nginx服务已就绪"
            break
        fi
        sleep 3
        timeout=$((timeout-3))
        echo -n "."
    done
    echo
    
    if [ $timeout -le 0 ]; then
        log_warning "Nginx服务可能未完全就绪，请稍后检查"
    fi
    
    log_success "所有服务已启动"
}

# 执行健康检查
health_check() {
    log_step "执行健康检查..."
    
    cd $PROJECT_DIR
    
    # 检查容器状态
    log_info "检查容器状态..."
    local unhealthy_containers=$(docker-compose -f $COMPOSE_FILE ps --filter "status=exited" --format "table {{.Name}}\t{{.Status}}" | tail -n +2)
    
    if [[ -n "$unhealthy_containers" ]]; then
        log_error "发现异常容器:"
        echo "$unhealthy_containers"
        log_info "查看详细日志:"
        docker-compose -f $COMPOSE_FILE logs --tail=50
        exit 1
    fi
    
    # 检查服务端口
    local ports=("80" "443")
    for port in "${ports[@]}"; do
        if ss -tlnp | grep -q ":$port "; then
            log_success "端口 $port 正常监听"
        else
            log_warning "端口 $port 未监听"
        fi
    done
    
    # 检查Web服务
    if curl -f -s http://localhost > /dev/null; then
        log_success "Web服务响应正常"
    else
        log_warning "Web服务响应异常"
    fi
    
    # 检查API服务
    if curl -f -s http://localhost/api/health > /dev/null; then
        log_success "API服务响应正常"
    else
        log_warning "API服务响应异常"
    fi
    
    log_success "健康检查完成"
}

# 设置系统服务
setup_system_service() {
    log_step "设置系统服务..."
    
    # 创建systemd服务文件
    cat << EOF | sudo tee /etc/systemd/system/medical-gpt.service
[Unit]
Description=Medical GPT AI Assistant
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/local/bin/docker-compose -f $COMPOSE_FILE up -d
ExecStop=/usr/local/bin/docker-compose -f $COMPOSE_FILE down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    # 启用服务
    sudo systemctl daemon-reload
    sudo systemctl enable medical-gpt.service
    
    log_success "系统服务设置完成"
}

# 创建管理脚本
create_management_scripts() {
    log_step "创建管理脚本..."
    
    # 创建服务管理脚本
    cat << 'EOF' > $PROJECT_DIR/manage.sh
#!/bin/bash

# 医疗健康AI助手管理脚本

PROJECT_DIR="/opt/medical-gpt"
COMPOSE_FILE="docker-compose.aliyun.yml"

cd $PROJECT_DIR

case "$1" in
    start)
        echo "启动服务..."
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    stop)
        echo "停止服务..."
        docker-compose -f $COMPOSE_FILE down
        ;;
    restart)
        echo "重启服务..."
        docker-compose -f $COMPOSE_FILE restart
        ;;
    status)
        echo "服务状态:"
        docker-compose -f $COMPOSE_FILE ps
        ;;
    logs)
        echo "查看日志:"
        docker-compose -f $COMPOSE_FILE logs -f --tail=100
        ;;
    update)
        echo "更新服务..."
        docker-compose -f $COMPOSE_FILE pull
        docker-compose -f $COMPOSE_FILE up -d --build
        ;;
    backup)
        echo "备份数据..."
        ./backup.sh
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|update|backup}"
        exit 1
        ;;
esac
EOF
    
    chmod +x $PROJECT_DIR/manage.sh
    
    # 创建备份脚本
    cat << EOF > $PROJECT_DIR/backup.sh
#!/bin/bash

# 医疗健康AI助手备份脚本

PROJECT_DIR="$PROJECT_DIR"
BACKUP_DIR="$BACKUP_DIR"
DATE=\$(date +%Y%m%d_%H%M%S)
COMPOSE_FILE="$COMPOSE_FILE"

cd \$PROJECT_DIR

# 创建备份目录
mkdir -p \$BACKUP_DIR

echo "开始备份: \$DATE"

# 备份数据库
echo "备份MySQL数据库..."
docker-compose -f \$COMPOSE_FILE exec -T mysql mysqldump -u root -p\${MYSQL_ROOT_PASSWORD} --all-databases > \$BACKUP_DIR/mysql_\$DATE.sql

# 备份Redis数据
echo "备份Redis数据..."
docker-compose -f \$COMPOSE_FILE exec -T redis redis-cli --rdb /data/dump_\$DATE.rdb
docker cp medical-gpt-redis:/data/dump_\$DATE.rdb \$BACKUP_DIR/

# 备份配置文件
echo "备份配置文件..."
tar -czf \$BACKUP_DIR/config_\$DATE.tar.gz gptserver/.env docker/ ssl_certs/

# 备份上传文件
echo "备份上传文件..."
if [ -d "gptserver/storage" ]; then
    tar -czf \$BACKUP_DIR/storage_\$DATE.tar.gz gptserver/storage/
fi

# 清理7天前的备份
echo "清理旧备份..."
find \$BACKUP_DIR -name "*" -mtime +7 -delete

echo "备份完成: \$DATE"
echo "备份文件保存在: \$BACKUP_DIR"
ls -la \$BACKUP_DIR/
EOF
    
    chmod +x $PROJECT_DIR/backup.sh
    
    # 创建监控脚本
    cat << 'EOF' > $PROJECT_DIR/monitor.sh
#!/bin/bash

# 医疗健康AI助手监控脚本

PROJECT_DIR="/opt/medical-gpt"
COMPOSE_FILE="docker-compose.aliyun.yml"

cd $PROJECT_DIR

echo "=== 医疗健康AI助手系统监控 ==="
echo "时间: $(date)"
echo ""

echo "=== 容器状态 ==="
docker-compose -f $COMPOSE_FILE ps
echo ""

echo "=== 系统资源使用 ==="
echo "CPU使用率:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'
echo ""
echo "内存使用:"
free -h
echo ""
echo "磁盘使用:"
df -h /
echo ""

echo "=== Docker资源使用 ==="
docker stats --no-stream
echo ""

echo "=== 网络连接 ==="
ss -tlnp | grep -E ":(80|443|3306|6379|9000|9503)"
echo ""

echo "=== 最近错误日志 ==="
echo "Nginx错误:"
tail -n 5 logs/nginx/error.log 2>/dev/null || echo "无错误日志"
echo ""
echo "PHP错误:"
tail -n 5 logs/php/error.log 2>/dev/null || echo "无错误日志"
echo ""

echo "=== 服务健康检查 ==="
if curl -f -s http://localhost/health > /dev/null; then
    echo "✓ Web服务正常"
else
    echo "✗ Web服务异常"
fi

if curl -f -s http://localhost/api/health > /dev/null; then
    echo "✓ API服务正常"
else
    echo "✗ API服务异常"
fi
EOF
    
    chmod +x $PROJECT_DIR/monitor.sh
    
    log_success "管理脚本创建完成"
}

# 设置定时任务
setup_cron_jobs() {
    log_step "设置定时任务..."
    
    # 备份任务（每天凌晨2点）
    (crontab -l 2>/dev/null; echo "0 2 * * * $PROJECT_DIR/backup.sh >> /var/log/medical-gpt-backup.log 2>&1") | crontab -
    
    # 监控任务（每小时）
    (crontab -l 2>/dev/null; echo "0 * * * * $PROJECT_DIR/monitor.sh >> /var/log/medical-gpt-monitor.log 2>&1") | crontab -
    
    # 日志清理任务（每周日凌晨3点）
    (crontab -l 2>/dev/null; echo "0 3 * * 0 find $PROJECT_DIR/logs -name '*.log' -mtime +30 -delete") | crontab -
    
    log_success "定时任务设置完成"
}

# 显示部署信息
show_deployment_info() {
    local public_ip=$(curl -s ifconfig.me 2>/dev/null || echo "未知")
    
    echo -e "${GREEN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "          医疗健康AI助手部署完成！"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    echo -e "${CYAN}=== 访问信息 ===${NC}"
    echo "前端地址: http://$public_ip"
    echo "管理后台: http://$public_ip/admin"
    echo "API接口: http://$public_ip/api"
    echo "健康检查: http://$public_ip/health"
    echo ""
    
    echo -e "${CYAN}=== 服务管理 ===${NC}"
    echo "管理脚本: $PROJECT_DIR/manage.sh"
    echo "启动服务: $PROJECT_DIR/manage.sh start"
    echo "停止服务: $PROJECT_DIR/manage.sh stop"
    echo "重启服务: $PROJECT_DIR/manage.sh restart"
    echo "查看状态: $PROJECT_DIR/manage.sh status"
    echo "查看日志: $PROJECT_DIR/manage.sh logs"
    echo "更新服务: $PROJECT_DIR/manage.sh update"
    echo "备份数据: $PROJECT_DIR/manage.sh backup"
    echo ""
    
    echo -e "${CYAN}=== 监控命令 ===${NC}"
    echo "系统监控: $PROJECT_DIR/monitor.sh"
    echo "容器状态: docker-compose -f $PROJECT_DIR/$COMPOSE_FILE ps"
    echo "资源使用: docker stats"
    echo "系统资源: htop"
    echo ""
    
    echo -e "${CYAN}=== 日志文件 ===${NC}"
    echo "部署日志: $LOG_FILE"
    echo "Nginx日志: $PROJECT_DIR/logs/nginx/"
    echo "PHP日志: $PROJECT_DIR/logs/php/"
    echo "MySQL日志: $PROJECT_DIR/logs/mysql/"
    echo "Redis日志: $PROJECT_DIR/logs/redis/"
    echo ""
    
    echo -e "${CYAN}=== 重要提醒 ===${NC}"
    echo "1. 请及时修改默认密码"
    echo "2. 配置SSL证书启用HTTPS"
    echo "3. 定期备份重要数据"
    echo "4. 监控系统资源使用情况"
    echo "5. 查看应用日志排查问题"
    echo ""
    
    echo -e "${YELLOW}完成时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    # 清理临时文件
    rm -f get-docker.sh
}

# 错误处理
error_handler() {
    local line_number=$1
    log_error "部署过程中发生错误 (行号: $line_number)"
    log_error "请查看日志文件: $LOG_FILE"
    
    # 显示最近的日志
    echo -e "${RED}最近的错误信息:${NC}"
    tail -n 10 $LOG_FILE
    
    cleanup
    exit 1
}

# 主函数
main() {
    # 设置错误处理
    trap 'error_handler $LINENO' ERR
    trap cleanup EXIT
    
    # 创建日志文件
    sudo touch $LOG_FILE
    sudo chown $USER:$USER $LOG_FILE
    
    show_banner
    
    # 执行部署步骤
    check_permissions
    check_system
    install_dependencies
    install_docker
    install_docker_compose
    setup_firewall
    setup_directories
    check_environment_config
    pull_docker_images
    deploy_services
    wait_for_services
    health_check
    setup_system_service
    create_management_scripts
    setup_cron_jobs
    
    show_deployment_info
    
    log_success "医疗健康AI助手部署完成！"
}

# 检查参数
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "医疗健康AI助手 - 阿里云部署脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --help, -h     显示帮助信息"
    echo "  --version, -v  显示版本信息"
    echo ""
    echo "环境变量:"
    echo "  MYSQL_ROOT_PASSWORD  MySQL root密码"
    echo "  MYSQL_PASSWORD       MySQL用户密码"
    echo "  REDIS_PASSWORD       Redis密码"
    echo "  OPENAI_API_KEY       OpenAI API密钥"
    echo ""
    exit 0
fi

if [[ "$1" == "--version" ]] || [[ "$1" == "-v" ]]; then
    echo "医疗健康AI助手部署脚本 v2.0"
    exit 0
fi

# 执行主函数
main "$@"