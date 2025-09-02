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

# 安装Redis和Swoole扩展
RUN pecl install redis swoole \
    && docker-php-ext-enable redis swoole

# 安装Composer（使用官方安装方式）
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer --version

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

# 安装PHP依赖（添加错误处理）
RUN cd /var/www/html/gptserver \
    && if [ -f composer.json ]; then \
        composer install --no-dev --optimize-autoloader --no-scripts --prefer-dist; \
    else \
        echo "Warning: composer.json not found"; \
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

# 创建健壮的启动脚本
RUN printf '#!/bin/bash\n\
set -e\n\
\n\
# 检查必要文件\n\
if [ ! -f "/var/www/html/gptserver/composer.json" ]; then\n\
    echo "Error: composer.json not found"\n\
    exit 1\n\
fi\n\
\n\
# 确保权限正确\n\
chown -R www-data:www-data /var/www/html/gptserver/storage\n\
chmod -R 777 /var/www/html/gptserver/storage\n\
\n\
# 启动Apache\n\
echo "Starting Apache..."\n\
exec apache2-foreground\n' > /start.sh \
    && chmod +x /start.sh

# 添加健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# 暴露端口
EXPOSE 80 9503

# 设置启动命令
CMD ["/start.sh"]