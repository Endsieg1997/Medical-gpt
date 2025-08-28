<?php

namespace App\Http\Dto\Config;

use App\Model\Config;
use Cblink\Dto\Dto;

/**
 * @property string $channel  渠道
 * @property string $default_system_prompt 默认系统咒语
 * @property string $gptlink_key gptlink key
 * @property string $openai_key openai key
 * @property string $openai_model openai model
 * @property int|string $openai_tokens 最大tokens
 * @property int $openai_response_tokens 返回最大tokens
 * @property string $openai_host 请求地址
 * @property string $openai_proxy_host 代理地址
 * @property string $azure_endpoint
 * @property string $azure_model
 * @property string $azure_key
 * @property string $azure_api_version
 */
class AiChatConfigDto extends Dto implements ConfigDtoInterface
{
    const GPTLINK = 'gptlink';
    const OPENAI = 'openai';

    protected $fillable = [
        'type',
        'channel',
        'default_system_prompt',
        'gptlink_key',
        'openai_key', 'openai_model', 'openai_tokens', 'openai_response_tokens', 'openai_host', 'openai_proxy_host',
        'azure_endpoint', 'azure_model', 'azure_key', 'azure_api_version',
    ];

    /**
     * 默认数据
     * @return array
     */
    public function getDefaultConfig(): array
    {
        $config = [
            'type' => $this->getItem('type'),
            'channel' => $this->getItem('channel'),
            'default_system_prompt' => $this->getItem('default_system_prompt'),
            'gptlink_key' => $this->getItem('gptlink_key'),
            'openai_key' => $this->getItem('openai_key'),
            'openai_model' => $this->getItem('openai_model'),
            'openai_tokens' => $this->getItem('openai_tokens'),
            'openai_response_tokens' => $this->getItem('openai_response_tokens'),
            'openai_host' => $this->getItem('openai_host'),
            'openai_proxy_host' => $this->getItem('openai_proxy_host'),
            'azure_endpoint' => $this->getItem('azure_endpoint'),
            'azure_model' => $this->getItem('azure_model'),
            'azure_key' => $this->getItem('azure_key'),
            'azure_api_version' => $this->getItem('azure_api_version'),
        ];

        // 医疗模式下从环境变量读取配置
        if (env('MEDICAL_MODE', false)) {
            $config['channel'] = env('AI_CHANNEL', 'openai');
            $config['default_system_prompt'] = $this->getMedicalSystemPrompt();
            $config['gptlink_key'] = env('GPTLINK_KEY', '');
            $config['openai_key'] = env('OPENAI_API_KEY', '');
            $config['openai_model'] = env('OPENAI_MODEL', 'gpt-3.5-turbo');
            $config['openai_tokens'] = (int)env('OPENAI_TOKENS', 4000);
            $config['openai_response_tokens'] = (int)env('OPENAI_RESPONSE_TOKENS', 1000);
            $config['openai_host'] = env('OPENAI_HOST', 'https://api.openai.com');
        }

        return $config;
    }

    /**
     * 更新或创建时的数据.
     */
    public function getConfigFillable(): array
    {
        return [
            'config' => [
                'channel' => $this->getItem('channel'),
                'default_system_prompt' => $this->getItem('default_system_prompt'),
                'gptlink_key' => $this->getItem('gptlink_key'),
                'openai_key' => $this->getItem('openai_key'),
                'openai_model' => $this->getItem('openai_model'),
                'openai_tokens' => $this->getItem('openai_tokens'),
                'openai_response_tokens' => $this->getItem('openai_response_tokens'),
                'openai_host' => $this->getItem('openai_host'),
                'openai_proxy_host' => $this->getItem('openai_proxy_host'),
                'azure_endpoint' => $this->getItem('azure_endpoint'),
                'azure_model' => $this->getItem('azure_model'),
                'azure_key' => $this->getItem('azure_key'),
                'azure_api_version' => $this->getItem('azure_api_version'),
            ]
        ];
    }

    /**
     * @return string
     */
    public function getOpenAiKey()
    {
        // 医疗模式下优先使用环境变量中的API Key
        if (env('MEDICAL_MODE', false) && env('OPENAI_API_KEY')) {
            return [env('OPENAI_API_KEY')];
        }

        $keys = explode("\n", $this->getItem('openai_key'));

        return $keys[array_rand($keys)];
    }

    /**
     * 唯一标识数据.
     */
    public function getUniqueFillable(): array
    {
        return [
            'type' => $this->getItem('type', Config::AI_CHAT),
        ];
    }

    /**
     * 获取医疗健康系统提示词
     */
    private function getMedicalSystemPrompt(): string
    {
        return "你是一个专业的医疗健康AI助手，专门为用户提供医疗健康相关的咨询和知识服务。\n\n你的职责包括：\n1. 提供基础的健康知识和医疗常识\n2. 解答常见疾病的症状、预防和护理方法\n3. 分享健康生活方式和养生建议\n4. 协助理解医疗检查报告和用药指导\n5. 提供急救知识和健康管理建议\n\n重要提醒：\n- 我只能提供健康咨询和医疗知识，不能替代专业医生的诊断\n- 对于严重症状或紧急情况，请立即就医\n- 用药建议仅供参考，具体用药请遵医嘱\n\n请始终保持专业、准确、负责的态度，用通俗易懂的语言回答问题。";
    }
}
