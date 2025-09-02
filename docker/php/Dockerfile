# 使用官方PHP镜像
FROM php:8.1-apache

# 设置工作目录
WORKDIR /var/www/html

# 更新包管理器并安装基础依赖
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 安装依赖
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libbrotli-dev \
    libssl-dev \
    libzip-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装PHP扩展
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# 安装Redis扩展
RUN pecl install redis && docker-php-ext-enable redis

# 安装Swoole扩展
RUN pecl install swoole && docker-php-ext-enable swoole

# 安装Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# 设置Composer环境变量以允许root用户运行
ENV COMPOSER_ALLOW_SUPERUSER=1

# 复制应用代码
COPY . /var/www/html

# 设置权限 - 给予最宽松的权限以避免Composer安装问题
RUN chmod -R 777 /var/www/html

# 预安装Composer依赖（如果composer.json存在）
RUN if [ -f "/var/www/html/gptserver/composer.json" ]; then \
        cd /var/www/html/gptserver && \
        rm -rf vendor composer.lock && \
        COMPOSER_ALLOW_SUPERUSER=1 composer install --ignore-platform-reqs --no-interaction --prefer-dist --no-scripts; \
    fi

# 最后再次设置权限确保所有文件可访问
RUN chmod -R 777 /var/www/html

# 启用Apache mod_rewrite
RUN a2enmod rewrite

# 暴露端口
EXPOSE 80 9503

# 创建启动脚本
RUN printf '#!/bin/bash\n# 启动Swoole HTTP服务器\nphp /var/www/html/simple_start.php\n' > /start.sh && chmod +x /start.sh

# 启动命令
CMD ["/start.sh"]