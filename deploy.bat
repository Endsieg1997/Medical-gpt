@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM 医疗健康AI助手 - Windows Docker部署脚本
REM 版本: 1.0
REM 作者: Medical AI Team
REM 日期: 2024-01-01

echo ========================================
echo 医疗健康AI助手 Docker部署脚本
echo 版本: 1.0
echo 开始时间: %date% %time%
echo ========================================
echo.

REM 检查Docker和Docker Compose
echo [INFO] 检查系统要求...
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker未安装，请先安装Docker Desktop
    pause
    exit /b 1
)

docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Compose未安装，请先安装Docker Compose
    pause
    exit /b 1
)
echo [SUCCESS] 系统要求检查通过
echo.

REM 检查环境变量
echo [INFO] 检查环境变量...
if "%OPENAI_API_KEY%"=="" (
    echo [WARNING] 未设置OPENAI_API_KEY环境变量
    set /p OPENAI_API_KEY="请输入OpenAI API Key: "
    if "!OPENAI_API_KEY!"=="" (
        echo [ERROR] OpenAI API Key不能为空
        pause
        exit /b 1
    )
)
echo [SUCCESS] 环境变量检查完成
echo.

REM 创建必要的目录
echo [INFO] 创建必要的目录...
if not exist "logs\nginx" mkdir "logs\nginx"
if not exist "logs\mysql" mkdir "logs\mysql"
if not exist "logs\php" mkdir "logs\php"
if not exist "data\mysql" mkdir "data\mysql"
if not exist "data\redis" mkdir "data\redis"
if not exist "ssl" mkdir "ssl"
echo [SUCCESS] 目录创建完成
echo.

REM 停止现有服务
echo [INFO] 停止现有服务...
docker-compose down --remove-orphans >nul 2>&1
echo [SUCCESS] 现有服务已停止
echo.

REM 构建镜像
echo [INFO] 构建Docker镜像...
docker-compose build --no-cache
if errorlevel 1 (
    echo [ERROR] 镜像构建失败
    pause
    exit /b 1
)
echo [SUCCESS] 镜像构建完成
echo.

REM 启动服务
echo [INFO] 启动Docker服务...
docker-compose up -d
if errorlevel 1 (
    echo [ERROR] 服务启动失败
    pause
    exit /b 1
)
echo [SUCCESS] 服务启动完成
echo.

REM 等待服务就绪
echo [INFO] 等待服务就绪...
echo [INFO] 等待MySQL服务...
:wait_mysql
docker-compose exec -T mysql mysqladmin ping -h"localhost" --silent >nul 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak >nul
    goto wait_mysql
)

echo [INFO] 等待Redis服务...
:wait_redis
docker-compose exec -T redis redis-cli -a 666666 ping >nul 2>&1
if errorlevel 1 (
    timeout /t 2 /nobreak >nul
    goto wait_redis
)

echo [INFO] 等待PHP-FPM服务...
timeout /t 10 /nobreak >nul
echo [SUCCESS] 所有服务已就绪
echo.

REM 健康检查
echo [INFO] 执行健康检查...
curl -f http://localhost/health >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Nginx服务可能未完全就绪，请稍后检查
) else (
    echo [SUCCESS] Nginx服务正常
)

docker-compose exec -T mysql mysqladmin ping -h"localhost" --silent >nul 2>&1
if errorlevel 1 (
    echo [ERROR] MySQL服务异常
) else (
    echo [SUCCESS] MySQL服务正常
)

docker-compose exec -T redis redis-cli -a redis123 ping >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Redis服务异常
) else (
    echo [SUCCESS] Redis服务正常
)
echo.

REM 显示服务信息
echo ========================================
echo 医疗健康AI助手部署完成！
echo ========================================
echo.
echo === 服务访问信息 ===
echo 前端地址: http://localhost
echo 管理后台: http://localhost/admin
echo API接口: http://localhost/api
echo 健康检查: http://localhost/health
echo.
echo === 数据库信息 ===
echo MySQL端口: 3306
echo Redis端口: 6379
echo 数据库名: gptlink_edu
echo 用户名: gptlink
echo 密码: 666666
echo.
echo === 管理员账号 ===
echo 用户名: admin
echo 密码: 666666
echo.
echo === 日志查看 ===
echo 查看所有日志: docker-compose logs -f
echo 查看Nginx日志: docker-compose logs -f nginx
echo 查看PHP日志: docker-compose logs -f gptserver
echo 查看MySQL日志: docker-compose logs -f mysql
echo 查看Redis日志: docker-compose logs -f redis
echo.
echo === 服务管理 ===
echo 停止服务: docker-compose down
echo 重启服务: docker-compose restart
echo 更新服务: docker-compose pull ^&^& docker-compose up -d
echo.
echo [SUCCESS] 部署完成！
echo 完成时间: %date% %time%
echo.
echo 按任意键退出...
pause >nul