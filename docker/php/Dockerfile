# 医疗健康AI助手 - PHP服务容器
# 基于PHP 8.1 Apache镜像

FROM php:8.1-apache

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_NO_INTERACTION=1
ENV COMPOSER_CACHE_DIR=/tmp/composer-cache

# 设置工作目录
WORKDIR /var/www/html

# 安装系统依赖（一次性安装，减少层数）
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    vim \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libssl-dev \
    libicu-dev \
    pkg-config \
    zip \
    unzip \
    supervisor \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 安装PHP扩展（优化安装顺序）
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
        sockets \
        intl \
        opcache

# 安装Redis和Swoole扩展（增强兼容性）
RUN echo "Installing Redis and Swoole extensions with compatibility checks..." \
    && (pecl install redis || (echo "Redis install failed, trying alternative..." && pecl install redis-5.3.7)) \
    && (pecl install swoole || (echo "Swoole install failed, trying alternative..." && pecl install swoole-4.8.13)) \
    && docker-php-ext-enable redis swoole \
    && php -m | grep -E "(redis|swoole)" \
    && echo "Extensions installed successfully"

# 安装Composer（多种方式兼容性安装）
RUN echo "Installing Composer with multiple fallback methods..." \
    && (curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
        || wget -O - https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
        || (echo "Downloading Composer directly..." && curl -o /usr/local/bin/composer https://getcomposer.org/download/latest-stable/composer.phar && chmod +x /usr/local/bin/composer) \
        || (echo "Using alternative download..." && wget -O /usr/local/bin/composer https://getcomposer.org/download/latest-stable/composer.phar && chmod +x /usr/local/bin/composer)) \
    && composer --version \
    && echo "Composer installed successfully"

# 复制PHP配置文件
COPY ./docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini

# 复制应用代码
COPY . /var/www/html/

# 创建必要的目录并设置权限
RUN mkdir -p /var/www/html/gptserver/storage/logs \
    && mkdir -p /var/www/html/gptserver/storage/cache \
    && mkdir -p /var/www/html/gptserver/storage/framework/sessions \
    && mkdir -p /var/www/html/gptserver/storage/framework/views \
    && mkdir -p /var/www/html/gptserver/storage/framework/cache \
    && mkdir -p /var/www/html/logs/php \
    && mkdir -p /var/www/html/logs/nginx

# 安装PHP依赖（增强兼容性和错误处理）
RUN cd /var/www/html/gptserver \
    && if [ -f composer.json ]; then \
        echo "Setting up Composer for better compatibility..." \
        && composer config -g repos.packagist composer https://packagist.org \
        && composer config -g process-timeout 600 \
        && composer config -g memory-limit -1 \
        && composer config -g secure-http false \
        && composer config -g disable-tls false \
        && composer config -g cafile "" \
        && composer config -g capath "" \
        && echo "Installing dependencies with fallback options..." \
        && (composer install --no-dev --optimize-autoloader --no-scripts --prefer-dist --no-interaction \
            || composer install --no-dev --optimize-autoloader --no-scripts --prefer-dist --no-interaction --ignore-platform-reqs \
            || composer install --no-dev --no-scripts --prefer-dist --no-interaction --ignore-platform-reqs \
            || (echo "Trying with Chinese mirror..." && composer config -g repos.packagist composer https://mirrors.aliyun.com/composer/ && composer install --no-dev --no-scripts --prefer-dist --no-interaction --ignore-platform-reqs) \
            || (echo "Final fallback: basic install" && composer install --no-interaction --ignore-platform-reqs)) \
        && composer dump-autoload --optimize --no-dev \
        && echo "Composer installation completed successfully"; \
    else \
        echo "Warning: composer.json not found in gptserver directory"; \
        ls -la /var/www/html/gptserver/ || echo "Directory does not exist"; \
    fi

# 设置正确的文件权限
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/gptserver/storage \
    && chmod -R 777 /var/www/html/logs

# 启用Apache模块
RUN a2enmod rewrite headers ssl

# 使用默认Apache配置（nginx配置不适用于Apache）
# Apache将使用默认配置

# 创建增强的启动脚本（兼容性和错误处理）
RUN printf '#!/bin/bash\n\
set -e\n\
\n\
echo "=== Medical GPT Container Startup ==="\n\
echo "Checking system compatibility..."\n\
\n\
# 检查PHP版本和扩展\n\
php --version\n\
echo "Checking required PHP extensions..."\n\
php -m | grep -E "(pdo_mysql|redis|swoole|gd|zip)" || echo "Warning: Some extensions may be missing"\n\
\n\
# 检查必要文件和目录\n\
echo "Checking project structure..."\n\
if [ ! -d "/var/www/html/gptserver" ]; then\n\
    echo "Error: gptserver directory not found"\n\
    ls -la /var/www/html/\n\
    exit 1\n\
fi\n\
\n\
if [ ! -f "/var/www/html/gptserver/composer.json" ]; then\n\
    echo "Warning: composer.json not found, checking directory contents..."\n\
    ls -la /var/www/html/gptserver/\n\
else\n\
    echo "composer.json found, checking vendor directory..."\n\
    if [ ! -d "/var/www/html/gptserver/vendor" ]; then\n\
        echo "Warning: vendor directory not found, dependencies may not be installed"\n\
    fi\n\
fi\n\
\n\
# 创建必要目录（如果不存在）\n\
echo "Ensuring required directories exist..."\n\
mkdir -p /var/www/html/gptserver/storage/{logs,cache,framework/{sessions,views,cache}}\n\
mkdir -p /var/www/html/logs/{php,nginx}\n\
\n\
# 设置权限（兼容不同系统）\n\
echo "Setting up permissions..."\n\
chown -R www-data:www-data /var/www/html/gptserver/storage 2>/dev/null || echo "Warning: Could not change ownership"\n\
chmod -R 755 /var/www/html/gptserver 2>/dev/null || echo "Warning: Could not set directory permissions"\n\
chmod -R 777 /var/www/html/gptserver/storage 2>/dev/null || echo "Warning: Could not set storage permissions"\n\
chmod -R 777 /var/www/html/logs 2>/dev/null || echo "Warning: Could not set log permissions"\n\
\n\
# 检查Apache配置\n\
echo "Checking Apache configuration..."\n\
apache2ctl configtest || echo "Warning: Apache configuration test failed"\n\
\n\
# 启动Apache\n\
echo "Starting Apache server..."\n\
echo "Container is ready for connections"\n\
exec apache2-foreground\n' > /start.sh \
    && chmod +x /start.sh

# 添加健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# 暴露端口
EXPOSE 80 9503

# 设置启动命令
CMD ["/start.sh"]