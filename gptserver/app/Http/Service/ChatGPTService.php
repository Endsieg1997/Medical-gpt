<?php

namespace App\Http\Service;

use App\Base\OpenAi\ChatCompletionsRequest;
use App\Base\OpenAi\OpenaiChatCompletionsRequest;
use App\Base\OpenAi\OpenAIClient;
use App\Http\Dto\ChatDto;
use App\Http\Dto\Config\AiChatConfigDto;
use App\Http\Dto\Config\WebsiteConfigDto;
use App\Job\MemberConsumptionJob;
use App\Job\UserChatLogRecordJob;
use App\Model\Config;
use Psr\SimpleCache\InvalidArgumentException;

class ChatGPTService
{
    /**
     * 分块返回
     *
     * @param mixed $userId
     * @param ChatDto $dto
     * @throws InvalidArgumentException
     */
    public function chatProcess($userId, ChatDto $dto)
    {
        // 医疗版本使用限制检查
        if (env('MEDICAL_MODE', false)) {
            $this->checkMedicalLimits($member, $prompt);
        }

        [$result, $request] = $this->exec($dto, $userId);

        // 如果没有正常返回，不进行扣费与记录
        if ($result->result) {

            if (! $request instanceof ChatCompletionsRequest) {
                $dto->cached($result->result['id'], $result->result['messages']);
            }

            asyncQueue(new MemberConsumptionJob($userId));
            asyncQueue(new UserChatLogRecordJob(
                $result->result['messages'],
                $result->result['id'],
                $dto,
                $userId,
                $cacheMessage['first_id'] ?? ''
            ));
        }
    }

    /**
     * 发送请求
     *
     * @param ChatDto $dto
     * @param $userId
     * @return array
     * @throws \Psr\SimpleCache\InvalidArgumentException
     * @throws \Throwable
     */
    public function exec(ChatDto $dto, $userId)
    {
        /* @var AiChatConfigDto $config */
        $config = Config::toDto(Config::AI_CHAT);

        // 发送请求
        $client = new OpenAIClient($config);

        $request = match ($config->channel){
            AiChatConfigDto::OPENAI => new OpenaiChatCompletionsRequest($dto, $config),
            default => new ChatCompletionsRequest($dto, $config),
        };

        /* @var ChatCompletionsRequest $result */
        $result = $client->exec($request);

        logger()->info('openai result', [
            'user_id' => $userId,
            'result' => $result->result,
            'request' => $result->data,
            'debug' => $result->debug,
            'class' => $request::class,
        ]);

        return [$result, $request];
    }

    /**
     * 检查医疗版本使用限制
     */
    private function checkMedicalLimits($member, $prompt)
    {
        // 检查每日请求次数限制
        $dailyLimit = (int)env('MED_MAX_DAILY_REQUESTS', 50);
        $today = date('Y-m-d');
        $todayCount = ChatLog::where('member_id', $member->id)
            ->whereDate('created_at', $today)
            ->count();
            
        if ($todayCount >= $dailyLimit) {
            throw new BusinessException(ErrCode::MED_DAILY_LIMIT_EXCEEDED, '今日咨询次数已达上限');
        }
        
        // 检查对话长度限制
        $maxLength = (int)env('MED_MAX_CONVERSATION_LENGTH', 20);
        if (mb_strlen($prompt) > $maxLength * 100) { // 假设每轮对话平均100字符
            throw new BusinessException(ErrCode::MED_CONVERSATION_TOO_LONG, '咨询内容过长');
        }
        
        // 内容过滤
        if (env('MED_CONTENT_FILTER', true)) {
            $this->checkContentFilter($prompt);
        }
    }

    /**
     * 内容过滤检查
     */
    private function checkContentFilter($content)
    {
        $blockedKeywords = explode(',', env('MED_BLOCKED_KEYWORDS', '政治,暴力,色情,赌博,非法药物'));
        
        foreach ($blockedKeywords as $keyword) {
            if (stripos($content, trim($keyword)) !== false) {
                throw new BusinessException(ErrCode::MED_CONTENT_FILTERED, '内容包含敏感词汇');
            }
        }
    }
}
