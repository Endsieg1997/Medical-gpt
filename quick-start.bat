@echo off
chcp 65001 >nul
echo ========================================
echo     Medical-GPT 快速启动脚本
echo ========================================
echo.

echo [1/5] 检查 Docker 环境...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker 未安装或未启动，请先安装 Docker Desktop
    pause
    exit /b 1
)
echo ✅ Docker 环境正常

echo.
echo [2/5] 检查 Docker Compose 环境...
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker Compose 未安装
    pause
    exit /b 1
)
echo ✅ Docker Compose 环境正常

echo.
echo [3/5] 检查配置文件...
if not exist "gptserver\.env" (
    echo 📝 创建配置文件...
    copy "gptserver\.env.example" "gptserver\.env" >nul
    echo ✅ 配置文件已创建，使用默认配置
) else (
    echo ✅ 配置文件已存在
)

echo.
echo [4/5] 启动 Medical-GPT 服务...
echo 正在启动服务，请稍候...
docker-compose up -d

if %errorlevel% neq 0 (
    echo ❌ 服务启动失败，请检查错误信息
    pause
    exit /b 1
)

echo.
echo [5/5] 等待服务就绪...
echo 等待服务启动完成...
timeout /t 10 /nobreak >nul

echo.
echo ========================================
echo        🎉 启动完成！
echo ========================================
echo.
echo 📱 用户端访问地址: http://localhost:8080
echo 🔧 管理端访问地址: http://localhost:8080/admin
echo 📚 API文档地址: http://localhost:8080/api/docs/default
echo.
echo 👤 管理员账号: admin
echo 🔑 管理员密码: 666666
echo.
echo 📋 常用命令:
echo   查看服务状态: docker-compose ps
echo   查看日志: docker-compose logs -f
echo   停止服务: docker-compose down
echo   重启服务: docker-compose restart
echo.
echo ========================================
echo 按任意键打开用户端页面...
pause >nul
start http://localhost:8080