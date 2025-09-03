#!/bin/bash

# Medical GPT SSL证书配置脚本
# 支持自签名证书和Let's Encrypt证书

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

# 域名配置
DOMAIN="medicalgpt.asia"
SSL_DIR="./ssl_certs"
CERT_FILE="$SSL_DIR/cert.pem"
KEY_FILE="$SSL_DIR/key.pem"

# 创建SSL目录
create_ssl_directory() {
    log_info "创建SSL证书目录..."
    mkdir -p "$SSL_DIR"
    chmod 755 "$SSL_DIR"
    log_success "SSL目录创建完成: $SSL_DIR"
}

# 生成自签名证书
generate_self_signed_cert() {
    log_info "生成自签名SSL证书..."
    
    # 创建证书配置文件
    cat > "$SSL_DIR/cert.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = CN
ST = Beijing
L = Beijing
O = Medical GPT
OU = IT Department
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

    # 生成私钥
    openssl genrsa -out "$KEY_FILE" 2048
    
    # 生成证书
    openssl req -new -x509 -key "$KEY_FILE" -out "$CERT_FILE" -days 365 -config "$SSL_DIR/cert.conf" -extensions v3_req
    
    # 设置权限
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    
    log_success "自签名证书生成完成"
    log_warning "注意: 自签名证书会在浏览器中显示安全警告"
}

# 安装Certbot
install_certbot() {
    log_info "安装Certbot..."
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif command -v yum &> /dev/null; then
        sudo yum install -y certbot
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y certbot
    else
        log_error "无法自动安装Certbot，请手动安装"
        return 1
    fi
    
    log_success "Certbot安装完成"
}

# 获取Let's Encrypt证书
get_letsencrypt_cert() {
    log_info "获取Let's Encrypt证书..."
    
    # 检查Certbot是否安装
    if ! command -v certbot &> /dev/null; then
        log_warning "Certbot未安装，正在安装..."
        install_certbot || return 1
    fi
    
    # 停止nginx以释放80端口
    log_info "临时停止nginx服务..."
    docker-compose stop nginx || true
    
    # 获取证书
    sudo certbot certonly --standalone \
        --email admin@$DOMAIN \
        --agree-tos \
        --no-eff-email \
        -d $DOMAIN \
        -d www.$DOMAIN
    
    if [ $? -eq 0 ]; then
        # 复制证书到项目目录
        sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_FILE"
        sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$KEY_FILE"
        
        # 设置权限
        sudo chown $(whoami):$(whoami) "$CERT_FILE" "$KEY_FILE"
        chmod 644 "$CERT_FILE"
        chmod 600 "$KEY_FILE"
        
        log_success "Let's Encrypt证书获取成功"
        
        # 设置自动续期
        setup_auto_renewal
    else
        log_error "Let's Encrypt证书获取失败"
        return 1
    fi
    
    # 重启nginx
    log_info "重启nginx服务..."
    docker-compose start nginx
}

# 设置证书自动续期
setup_auto_renewal() {
    log_info "设置证书自动续期..."
    
    # 创建续期脚本
    cat > "$SSL_DIR/renew-cert.sh" << 'EOF'
#!/bin/bash
# Let's Encrypt证书自动续期脚本

DOMAIN="medicalgpt.asia"
SSL_DIR="./ssl_certs"
PROJECT_DIR="$(dirname "$SSL_DIR")"

cd "$PROJECT_DIR"

# 停止nginx
docker-compose stop nginx

# 续期证书
sudo certbot renew --standalone

if [ $? -eq 0 ]; then
    # 复制新证书
    sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/cert.pem"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/key.pem"
    
    # 设置权限
    sudo chown $(whoami):$(whoami) "$SSL_DIR/cert.pem" "$SSL_DIR/key.pem"
    chmod 644 "$SSL_DIR/cert.pem"
    chmod 600 "$SSL_DIR/key.pem"
    
    echo "证书续期成功"
else
    echo "证书续期失败"
fi

# 重启nginx
docker-compose start nginx
EOF

    chmod +x "$SSL_DIR/renew-cert.sh"
    
    # 添加到crontab
    (crontab -l 2>/dev/null; echo "0 3 1 * * $PWD/$SSL_DIR/renew-cert.sh") | crontab -
    
    log_success "自动续期设置完成（每月1号凌晨3点执行）"
}

# 验证证书
verify_certificate() {
    log_info "验证SSL证书..."
    
    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        # 检查证书有效性
        openssl x509 -in "$CERT_FILE" -text -noout > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_success "证书文件有效"
            
            # 显示证书信息
            echo "证书信息:"
            openssl x509 -in "$CERT_FILE" -subject -dates -noout
            echo
        else
            log_error "证书文件无效"
            return 1
        fi
    else
        log_error "证书文件不存在"
        return 1
    fi
}

# 主菜单
show_menu() {
    echo
    echo "========================================"
    echo "     Medical GPT SSL证书配置工具"
    echo "========================================"
    echo "1. 生成自签名证书（开发/测试环境）"
    echo "2. 获取Let's Encrypt证书（生产环境）"
    echo "3. 验证现有证书"
    echo "4. 查看证书信息"
    echo "5. 退出"
    echo "========================================"
    echo
}

# 主函数
main() {
    log_info "Medical GPT SSL证书配置工具"
    
    # 创建SSL目录
    create_ssl_directory
    
    while true; do
        show_menu
        read -p "请选择操作 (1-5): " choice
        
        case $choice in
            1)
                generate_self_signed_cert
                verify_certificate
                ;;
            2)
                echo
                log_warning "注意: 获取Let's Encrypt证书需要:"
                echo "  1. 域名已正确解析到此服务器"
                echo "  2. 服务器可以从互联网访问"
                echo "  3. 80端口未被占用"
                echo
                read -p "确认继续? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    get_letsencrypt_cert
                    verify_certificate
                fi
                ;;
            3)
                verify_certificate
                ;;
            4)
                if [ -f "$CERT_FILE" ]; then
                    echo "证书详细信息:"
                    openssl x509 -in "$CERT_FILE" -text -noout
                else
                    log_error "证书文件不存在"
                fi
                ;;
            5)
                log_info "退出SSL配置工具"
                exit 0
                ;;
            *)
                log_error "无效选择，请重试"
                ;;
        esac
        
        echo
        read -p "按回车键继续..."
    done
}

# 检查是否以root权限运行（Let's Encrypt需要）
if [ "$1" = "letsencrypt" ] && [ $EUID -eq 0 ]; then
    log_error "请不要以root权限运行此脚本"
    exit 1
fi

# 运行主函数
main "$@"