# 医疗健康AI助手 - Hyperf服务容器
# 基于PHP 8.1 CLI镜像，专为Hyperf框架优化

FROM php:8.1-apache

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_NO_INTERACTION=1

# 设置工作目录
WORKDIR /var/www/html/gptserver

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libssl-dev \
    libicu-dev \
    pkg-config \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 安装PHP扩展
RUN docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        pcntl \
        bcmath \
        zip \
        sockets \
        intl \
        opcache

# 安装Redis和Swoole扩展
RUN pecl install redis swoole \
    && docker-php-ext-enable redis swoole

# 安装Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# 复制PHP配置文件
COPY ./docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini

# 复制gptserver应用代码
COPY ./gptserver /var/www/html/gptserver

# 安装PHP依赖
RUN if [ -f composer.json ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# 创建必要的目录并设置权限
RUN mkdir -p storage/logs storage/cache \
    && chmod -R 777 storage

# 复制启动脚本
COPY ./gptserver/start.sh /start.sh
RUN chmod +x /start.sh

# 暴露Hyperf默认端口
EXPOSE 9501

# 启动命令
CMD ["/start.sh"]