#!/bin/bash

# 医疗健康AI助手 - 阿里云服务器部署脚本
# 域名: medicalgpt.asia
# 基于本地成功部署经验

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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查系统要求
check_system() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    source /etc/os-release
    log_info "操作系统: $PRETTY_NAME"
    
    # 检查内存
    MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [[ $MEMORY -lt 2048 ]]; then
        log_warning "建议至少2GB内存，当前: ${MEMORY}MB"
    fi
    
    # 检查磁盘空间
    DISK=$(df -h / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ ${DISK%.*} -lt 20 ]]; then
        log_warning "建议至少20GB磁盘空间，当前可用: ${DISK}G"
    fi
}

# 安装Docker和Docker Compose
install_docker() {
    log_info "安装Docker和Docker Compose..."
    
    # 卸载旧版本
    yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    
    # 安装依赖
    yum install -y yum-utils device-mapper-persistent-data lvm2
    
    # 添加Docker仓库
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    
    # 安装Docker CE
    yum install -y docker-ce docker-ce-cli containerd.io
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    # 配置Docker镜像加速器
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
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
  "storage-driver": "overlay2"
}
EOF
    
    systemctl restart docker
    
    # 安装Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker和Docker Compose安装完成"
}

# 安装SSL证书
install_ssl() {
    log_info "安装SSL证书..."
    
    # 安装certbot
    yum install -y epel-release
    yum install -y certbot
    
    # 停止可能占用80端口的服务
    systemctl stop nginx 2>/dev/null || true
    systemctl stop httpd 2>/dev/null || true
    
    # 申请SSL证书
    certbot certonly --standalone -d medicalgpt.asia -d www.medicalgpt.asia --email admin@medicalgpt.asia --agree-tos --non-interactive
    
    # 设置自动续期
    echo "0 2 * * * root certbot renew --quiet && docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml restart nginx" >> /etc/crontab
    
    log_success "SSL证书安装完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    # 启动firewalld
    systemctl start firewalld
    systemctl enable firewalld
    
    # 开放必要端口
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --permanent --add-port=22/tcp
    
    # 重载防火墙规则
    firewall-cmd --reload
    
    log_success "防火墙配置完成"
}

# 部署应用
deploy_app() {
    log_info "部署医疗AI助手应用..."
    
    # 创建应用目录
    mkdir -p /opt/medical-gpt
    cd /opt/medical-gpt
    
    # 如果是Git仓库，拉取最新代码
    if [[ -d ".git" ]]; then
        git pull origin main
    else
        log_warning "请确保应用代码已上传到 /opt/medical-gpt 目录"
    fi
    
    # 复制环境配置文件
    if [[ ! -f ".env" ]]; then
        cp .env.aliyun .env
        log_warning "请编辑 .env 文件，配置必要的环境变量"
    fi
    
    # 创建必要目录
    mkdir -p logs/{nginx,php,mysql,redis}
    mkdir -p data/{mysql,redis}
    mkdir -p ssl_certs
    
    # 设置权限
    chown -R 1000:1000 logs data
    chmod -R 755 logs data
    
    # 构建并启动服务
    docker-compose -f docker-compose.aliyun.yml down
    docker-compose -f docker-compose.aliyun.yml build --no-cache
    docker-compose -f docker-compose.aliyun.yml up -d
    
    log_success "应用部署完成"
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    sleep 10
    
    # 检查容器状态
    docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml ps
    
    # 检查端口监听
    netstat -tlnp | grep -E ':80|:443|:3306|:6379|:9503'
    
    # 测试HTTP响应
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
        log_success "HTTP服务正常"
    else
        log_error "HTTP服务异常"
    fi
    
    # 测试HTTPS响应
    if curl -s -k -o /dev/null -w "%{http_code}" https://localhost | grep -q "200\|301\|302"; then
        log_success "HTTPS服务正常"
    else
        log_warning "HTTPS服务可能需要配置SSL证书"
    fi
}

# 设置监控
setup_monitoring() {
    log_info "设置系统监控..."
    
    # 创建监控脚本
    cat > /opt/medical-gpt/monitor.sh <<'EOF'
#!/bin/bash

# 检查容器状态
check_containers() {
    containers=("medical-gpt-mysql" "medical-gpt-redis" "medical-gpt-server" "medical-gpt-nginx")
    
    for container in "${containers[@]}"; do
        if ! docker ps | grep -q "$container"; then
            echo "$(date): Container $container is not running" >> /var/log/medical-gpt-monitor.log
            docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml restart "$container"
        fi
    done
}

# 检查磁盘空间
check_disk() {
    usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    if [[ $usage -gt 80 ]]; then
        echo "$(date): Disk usage is ${usage}%" >> /var/log/medical-gpt-monitor.log
    fi
}

# 检查内存使用
check_memory() {
    usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $usage -gt 80 ]]; then
        echo "$(date): Memory usage is ${usage}%" >> /var/log/medical-gpt-monitor.log
    fi
}

check_containers
check_disk
check_memory
EOF
    
    chmod +x /opt/medical-gpt/monitor.sh
    
    # 添加到crontab
    echo "*/5 * * * * root /opt/medical-gpt/monitor.sh" >> /etc/crontab
    
    log_success "监控设置完成"
}

# 显示部署信息
show_info() {
    log_success "=== 部署完成 ==="
    echo
    log_info "访问地址:"
    echo "  前端界面: https://medicalgpt.asia/web/"
    echo "  管理后台: https://medicalgpt.asia/admin/"
    echo "  API接口: https://medicalgpt.asia/api/"
    echo
    log_info "重要文件位置:"
    echo "  应用目录: /opt/medical-gpt"
    echo "  配置文件: /opt/medical-gpt/.env"
    echo "  日志目录: /opt/medical-gpt/logs"
    echo "  SSL证书: /etc/letsencrypt/live/medicalgpt.asia/"
    echo
    log_info "常用命令:"
    echo "  查看服务状态: docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml ps"
    echo "  查看日志: docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml logs -f"
    echo "  重启服务: docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml restart"
    echo "  停止服务: docker-compose -f /opt/medical-gpt/docker-compose.aliyun.yml down"
    echo
    log_warning "请确保:"
    echo "  1. 域名 medicalgpt.asia 已正确解析到此服务器"
    echo "  2. 已编辑 .env 文件配置必要的API密钥"
    echo "  3. 防火墙已开放 80 和 443 端口"
    echo "  4. SSL证书已正确安装"
}

# 主函数
main() {
    log_info "开始部署医疗健康AI助手到阿里云服务器..."
    
    check_root
    check_system
    install_docker
    setup_firewall
    install_ssl
    deploy_app
    check_services
    setup_monitoring
    show_info
    
    log_success "部署完成！"
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi