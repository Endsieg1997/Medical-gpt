@echo off
chcp 65001 >nul
echo ========================================
echo 医疗健康AI助手 - Windows快速部署脚本
echo ========================================
echo.

REM 检查Docker是否安装
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Docker未安装，请先安装Docker Desktop
    echo 下载地址: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

REM 检查Docker Compose是否可用
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Docker Compose不可用，请确保Docker Desktop正在运行
    pause
    exit /b 1
)

echo [信息] Docker环境检查通过
echo.

REM 检查.env文件
if not exist ".env" (
    echo [信息] 复制环境变量配置文件...
    copy ".env.example" ".env"
    echo [警告] 请编辑.env文件，配置您的API Key和其他设置
    echo [警告] 特别注意配置OPENAI_API_KEY
    pause
)

REM 创建必要目录
echo [信息] 创建必要目录...
if not exist "logs" mkdir logs
if not exist "logs\nginx" mkdir logs\nginx
if not exist "logs\mysql" mkdir logs\mysql
if not exist "logs\php" mkdir logs\php
if not exist "data" mkdir data
if not exist "data\mysql" mkdir data\mysql
if not exist "data\redis" mkdir data\redis
if not exist "ssl_certs" mkdir ssl_certs

REM 停止现有服务
echo [信息] 停止现有服务...
docker-compose down --remove-orphans 2>nul

REM 构建并启动服务
echo [信息] 构建并启动服务...
docker-compose up -d --build

if %errorlevel% equ 0 (
    echo.
    echo [成功] 服务启动完成！
    echo.
    echo ========================================
    echo 访问信息:
    echo ========================================
    echo 前端地址: http://localhost
    echo 管理后台: http://localhost/admin
    echo 健康检查: http://localhost/health
    echo.
    echo ========================================
    echo 管理员账号:
    echo ========================================
    echo 用户名: admin
    echo 密码: 666666
    echo.
    echo ========================================
    echo 服务管理命令:
    echo ========================================
    echo 查看服务状态: docker-compose ps
    echo 查看日志: docker-compose logs -f
    echo 停止服务: docker-compose down
    echo 重启服务: docker-compose restart
    echo.
    echo [提醒] 请及时修改默认密码！
    echo [提醒] 如需外网访问，请配置域名和云服务器安全组！
) else (
    echo.
    echo [错误] 服务启动失败，请检查配置和日志
    echo 查看详细日志: docker-compose logs
)

echo.
pause