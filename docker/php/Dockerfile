# 医疗健康AI助手 - PHP服务容器
# 基于PHP 8.1 Apache镜像

FROM php:8.1-apache

# 设置工作目录
WORKDIR /var/www/html

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 安装PHP扩展
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    sockets

# 安装Redis扩展
RUN pecl install redis && docker-php-ext-enable redis

# 安装Swoole扩展
RUN pecl install swoole && docker-php-ext-enable swoole

# 安装Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# 先复制composer文件
COPY ./gptserver/composer.json ./gptserver/composer.lock /var/www/html/gptserver/

# 设置Composer环境变量
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_NO_INTERACTION=1

# 安装PHP依赖
RUN cd /var/www/html/gptserver && composer install --no-dev --optimize-autoloader --no-scripts

# 复制应用代码
COPY . /var/www/html/

# 设置权限
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# 启用Apache mod_rewrite
RUN a2enmod rewrite

# 创建正确的启动脚本
RUN printf '#!/bin/bash\n\n# 启动Apache服务\napache2ctl -D FOREGROUND\n' > /start.sh && chmod +x /start.sh

# 暴露端口
EXPOSE 80 9503

# 启动命令
CMD ["/start.sh"]