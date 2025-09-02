#!/bin/bash

# 医疗健康AI助手 - 网络配置检查脚本
# 用于验证外网访问和防火墙设置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检查服务器基本信息
check_server_info() {
    log_info "检查服务器基本信息..."
    
    echo "操作系统: $(uname -a)"
    echo "内核版本: $(uname -r)"
    
    # 获取公网IP
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "无法获取")
    echo "公网IP: $PUBLIC_IP"
    
    # 获取内网IP
    PRIVATE_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "无法获取")
    echo "内网IP: $PRIVATE_IP"
    
    log_success "服务器信息检查完成"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."
    
    PORTS=("80" "443" "22" "3306" "6379")
    
    for port in "${PORTS[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            PROCESS=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
            log_success "端口 $port 已被占用 - $PROCESS"
        else
            log_warning "端口 $port 未被占用"
        fi
    done
}

# 检查防火墙状态
check_firewall() {
    log_info "检查防火墙状态..."
    
    # 检查UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        log_info "检测到UFW防火墙"
        UFW_STATUS=$(sudo ufw status 2>/dev/null || echo "inactive")
        echo "UFW状态: $UFW_STATUS"
        
        if echo "$UFW_STATUS" | grep -q "Status: active"; then
            log_success "UFW防火墙已启用"
            sudo ufw status numbered 2>/dev/null | grep -E "(80|443|22)" || log_warning "未发现HTTP/HTTPS/SSH规则"
        else
            log_warning "UFW防火墙未启用"
        fi
    fi
    
    # 检查firewalld (CentOS/RHEL)
    if command -v firewall-cmd &> /dev/null; then
        log_info "检测到firewalld防火墙"
        if systemctl is-active --quiet firewalld; then
            log_success "firewalld防火墙已启用"
            firewall-cmd --list-services 2>/dev/null | grep -E "(http|https|ssh)" || log_warning "未发现HTTP/HTTPS/SSH服务"
        else
            log_warning "firewalld防火墙未启用"
        fi
    fi
    
    # 检查iptables
    if command -v iptables &> /dev/null; then
        log_info "检查iptables规则"
        IPTABLES_RULES=$(sudo iptables -L INPUT -n 2>/dev/null | grep -E "(80|443|22)" | wc -l)
        if [ "$IPTABLES_RULES" -gt 0 ]; then
            log_success "发现 $IPTABLES_RULES 条相关iptables规则"
        else
            log_warning "未发现HTTP/HTTPS/SSH相关的iptables规则"
        fi
    fi
}

# 检查Docker服务
check_docker() {
    log_info "检查Docker服务状态..."
    
    if command -v docker &> /dev/null; then
        if systemctl is-active --quiet docker; then
            log_success "Docker服务正在运行"
            
            # 检查Docker Compose
            if command -v docker-compose &> /dev/null; then
                log_success "Docker Compose已安装"
                
                # 检查项目服务状态
                if [ -f "docker-compose.yml" ]; then
                    log_info "检查项目服务状态..."
                    docker-compose ps
                else
                    log_warning "未找到docker-compose.yml文件"
                fi
            else
                log_error "Docker Compose未安装"
            fi
        else
            log_error "Docker服务未运行"
        fi
    else
        log_error "Docker未安装"
    fi
}

# 检查网络连通性
check_connectivity() {
    log_info "检查网络连通性..."
    
    # 检查DNS解析
    if nslookup google.com &> /dev/null; then
        log_success "DNS解析正常"
    else
        log_error "DNS解析失败"
    fi
    
    # 检查外网连接
    if curl -s --connect-timeout 5 http://www.google.com &> /dev/null; then
        log_success "外网连接正常"
    else
        log_warning "外网连接可能有问题"
    fi
    
    # 检查API连接
    if curl -s --connect-timeout 5 https://api.deepseek.com &> /dev/null; then
        log_success "DeepSeek API连接正常"
    else
        log_warning "DeepSeek API连接可能有问题"
    fi
}

# 检查本地服务
check_local_services() {
    log_info "检查本地服务访问..."
    
    # 检查健康检查接口
    if curl -f -s http://localhost/health &> /dev/null; then
        log_success "健康检查接口正常"
    else
        log_warning "健康检查接口无法访问"
    fi
    
    # 检查前端页面
    if curl -f -s http://localhost/ &> /dev/null; then
        log_success "前端页面可访问"
    else
        log_warning "前端页面无法访问"
    fi
    
    # 检查管理后台
    if curl -f -s http://localhost/admin &> /dev/null; then
        log_success "管理后台可访问"
    else
        log_warning "管理后台无法访问"
    fi
}

# 检查SSL证书
check_ssl() {
    log_info "检查SSL证书配置..."
    
    if [ -d "ssl_certs" ]; then
        if [ -f "ssl_certs/cert.pem" ] && [ -f "ssl_certs/key.pem" ]; then
            log_success "SSL证书文件存在"
            
            # 检查证书有效期
            CERT_EXPIRY=$(openssl x509 -in ssl_certs/cert.pem -noout -enddate 2>/dev/null | cut -d= -f2)
            if [ -n "$CERT_EXPIRY" ]; then
                log_info "证书到期时间: $CERT_EXPIRY"
            fi
        else
            log_warning "SSL证书文件不完整"
        fi
    else
        log_warning "SSL证书目录不存在"
    fi
}

# 性能检查
check_performance() {
    log_info "检查系统性能..."
    
    # 检查CPU使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "CPU使用率: ${CPU_USAGE}%"
    
    # 检查内存使用
    MEM_INFO=$(free -h | grep "Mem:")
    echo "内存使用: $MEM_INFO"
    
    # 检查磁盘使用
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
    echo "磁盘使用率: $DISK_USAGE"
    
    # 检查负载
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
    echo "系统负载: $LOAD_AVG"
}

# 生成配置建议
generate_recommendations() {
    log_info "生成配置建议..."
    
    echo ""
    echo "=== 配置建议 ==="
    
    # 防火墙建议
    if ! command -v ufw &> /dev/null && ! command -v firewall-cmd &> /dev/null; then
        echo "1. 建议安装并配置防火墙 (UFW或firewalld)"
    fi
    
    # SSL建议
    if [ ! -f "ssl_certs/cert.pem" ]; then
        echo "2. 建议配置SSL证书以启用HTTPS"
    fi
    
    # 性能建议
    echo "3. 定期监控系统资源使用情况"
    echo "4. 配置日志轮转以防止磁盘空间不足"
    echo "5. 设置自动备份策略"
    
    # 安全建议
    echo "6. 修改默认密码"
    echo "7. 启用内容过滤和IP限制"
    echo "8. 定期更新系统和Docker镜像"
}

# 主函数
main() {
    echo "=== 医疗健康AI助手 - 网络配置检查 ==="
    echo "检查时间: $(date)"
    echo ""
    
    check_server_info
    echo ""
    
    check_ports
    echo ""
    
    check_firewall
    echo ""
    
    check_docker
    echo ""
    
    check_connectivity
    echo ""
    
    check_local_services
    echo ""
    
    check_ssl
    echo ""
    
    check_performance
    echo ""
    
    generate_recommendations
    
    log_success "网络配置检查完成！"
}

# 执行主函数
main "$@"