<?php
echo "Testing DeepSeek API..." . PHP_EOL;
echo "API Key: " . substr(getenv('OPENAI_API_KEY'), 0, 10) . "..." . PHP_EOL;
echo "Base URL: " . getenv('OPENAI_HOST') . PHP_EOL;
echo "Model: " . getenv('OPENAI_MODEL') . PHP_EOL;
echo PHP_EOL;

$apiKey = getenv('OPENAI_API_KEY');
$baseUrl = getenv('OPENAI_HOST');
$model = getenv('OPENAI_MODEL');

if (empty($apiKey) || empty($baseUrl) || empty($model)) {
    echo "Error: Missing required environment variables" . PHP_EOL;
    exit(1);
}

$url = rtrim($baseUrl, '/') . '/v1/chat/completions';
$headers = [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $apiKey
];

$data = [
    'model' => $model,
    'messages' => [
        ['role' => 'system', 'content' => '你是一个专业的医疗健康AI助手。'],
        ['role' => 'user', 'content' => '你好，请简单介绍一下你的功能。']
    ],
    'max_tokens' => 100,
    'temperature' => 0.7,
    'stream' => false
];

echo "Sending request to API..." . PHP_EOL;

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

if ($error) {
    echo "cURL Error: " . $error . PHP_EOL;
    exit(1);
}

if ($httpCode !== 200) {
    echo "HTTP Error: " . $httpCode . PHP_EOL;
    echo "Response: " . $response . PHP_EOL;
    exit(1);
}

$result = json_decode($response, true);
if (isset($result['choices'][0]['message']['content'])) {
    echo "API Test Success!" . PHP_EOL;
    echo "AI Response: " . $result['choices'][0]['message']['content'] . PHP_EOL;
} else {
    echo "Unexpected response format" . PHP_EOL;
    echo json_encode($result, JSON_PRETTY_PRINT) . PHP_EOL;
}
?>