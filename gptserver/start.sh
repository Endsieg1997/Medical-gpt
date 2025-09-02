#!/bin/bash

# 设置正确的工作目录
cd /var/www/html/gptserver

# 运行数据库迁移
php hyperf migrate

# 启动Hyperf服务器
php hyperf start
