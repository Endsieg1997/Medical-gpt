<?php

/**
 * DeepSeek API 测试脚本
 * 用于验证API配置是否正确
 */

// 加载环境变量
require_once __DIR__ . '/gptserver/vendor/autoload.php';

// 从.env文件读取配置
$envFile = __DIR__ . '/.env';
if (file_exists($envFile)) {
    $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos($line, '=') !== false && !str_starts_with(trim($line), '#')) {
            list($key, $value) = explode('=', $line, 2);
            $_ENV[trim($key)] = trim($value);
        }
    }
}

// 获取配置
$apiKey = $_ENV['OPENAI_API_KEY'] ?? 'your-deepseek-api-key-here';
$baseUrl = $_ENV['OPENAI_HOST'] ?? 'https://api.deepseek.com';
$model = $_ENV['OPENAI_MODEL'] ?? 'deepseek-chat';

echo "=== DeepSeek API 配置测试 ===\n";
echo "API Key: " . substr($apiKey, 0, 10) . "...\n";
echo "Base URL: $baseUrl\n";
echo "Model: $model\n\n";

// 检查API Key是否已配置
if ($apiKey === 'your-deepseek-api-key-here') {
    echo "❌ 错误: 请在.env文件中配置正确的DeepSeek API Key\n";
    echo "请将 OPENAI_API_KEY 设置为您的实际DeepSeek API Key\n";
    exit(1);
}

// 准备API请求
$url = rtrim($baseUrl, '/') . '/v1/chat/completions';
$headers = [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $apiKey
];

$data = [
    'model' => $model,
    'messages' => [
        [
            'role' => 'system',
            'content' => '你是一个专业的医疗健康AI助手，专门为用户提供医疗健康相关的咨询和知识服务。'
        ],
        [
            'role' => 'user',
            'content' => '你好，请简单介绍一下你的功能。'
        ]
    ],
    'max_tokens' => 100,
    'temperature' => 0.7,
    'stream' => false
];

echo "正在测试API连接...\n";

// 发送请求
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

// 处理响应
if ($error) {
    echo "❌ cURL错误: $error\n";
    exit(1);
}

if ($httpCode !== 200) {
    echo "❌ HTTP错误: $httpCode\n";
    echo "响应内容: $response\n";
    exit(1);
}

$result = json_decode($response, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    echo "❌ JSON解析错误: " . json_last_error_msg() . "\n";
    echo "原始响应: $response\n";
    exit(1);
}

if (isset($result['error'])) {
    echo "❌ API错误: " . $result['error']['message'] . "\n";
    exit(1);
}

if (isset($result['choices'][0]['message']['content'])) {
    echo "✅ API测试成功!\n\n";
    echo "=== AI响应 ===\n";
    echo $result['choices'][0]['message']['content'] . "\n\n";
    echo "=== 请求统计 ===\n";
    if (isset($result['usage'])) {
        echo "输入tokens: " . ($result['usage']['prompt_tokens'] ?? 'N/A') . "\n";
        echo "输出tokens: " . ($result['usage']['completion_tokens'] ?? 'N/A') . "\n";
        echo "总计tokens: " . ($result['usage']['total_tokens'] ?? 'N/A') . "\n";
    }
    echo "\n✅ DeepSeek API配置正确，可以正常使用!\n";
} else {
    echo "❌ 未找到预期的响应内容\n";
    echo "完整响应: " . json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
    exit(1);
}