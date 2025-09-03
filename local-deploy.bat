@echo off
chcp 65001 >nul
echo ========================================
echo Medical-GPT Local Deployment Script
echo ========================================

echo Checking Docker environment...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Docker is not installed or not running
    echo Please install Docker Desktop and start it
    pause
    exit /b 1
)

echo Checking docker-compose...
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: docker-compose is not installed
    echo Please install docker-compose
    pause
    exit /b 1
)

echo Stopping existing services...
docker-compose down

echo Cleaning old containers and images...
docker system prune -f

echo Starting services with existing images...
docker-compose up -d --no-build

echo Waiting for services to start...
timeout /t 10 /nobreak >nul

echo Checking service status...
docker-compose ps

echo ========================================
echo Deployment completed!
echo MySQL: localhost:3306
echo Redis: localhost:6379
echo Hyperf Service: localhost:9501
echo Web Interface: http://localhost:9501
echo ========================================

echo To view service logs run: docker-compose logs
echo Opening web interface...
start http://localhost:9501
pause