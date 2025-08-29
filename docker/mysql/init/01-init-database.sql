-- 医疗健康AI助手数据库初始化脚本
-- 创建时间: 2024-01-01
-- 版本: 1.0

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- 用户表
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '用户名',
  `email` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '邮箱',
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '密码',
  `nickname` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '昵称',
  `avatar` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '头像',
  `status` tinyint(4) NOT NULL DEFAULT '1' COMMENT '状态：1正常，0禁用',
  `user_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'medical' COMMENT '用户类型：medical医疗用户',
  `daily_requests` int(11) NOT NULL DEFAULT '0' COMMENT '今日请求次数',
  `total_requests` int(11) NOT NULL DEFAULT '0' COMMENT '总请求次数',
  `last_request_date` date DEFAULT NULL COMMENT '最后请求日期',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_user_type` (`user_type`),
  KEY `idx_status` (`status`),
  KEY `idx_last_request_date` (`last_request_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- ----------------------------
-- 对话记录表
-- ----------------------------
DROP TABLE IF EXISTS `conversations`;
CREATE TABLE `conversations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL COMMENT '用户ID',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '对话标题',
  `model` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'gpt-3.5-turbo' COMMENT 'AI模型',
  `message_count` int(11) NOT NULL DEFAULT '0' COMMENT '消息数量',
  `tokens_used` int(11) NOT NULL DEFAULT '0' COMMENT '使用的token数',
  `status` tinyint(4) NOT NULL DEFAULT '1' COMMENT '状态：1正常，0删除',
  `medical_category` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '医疗分类',
  `is_sensitive` tinyint(4) NOT NULL DEFAULT '0' COMMENT '是否包含敏感内容',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_medical_category` (`medical_category`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `fk_conversations_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对话记录表';

-- ----------------------------
-- 消息表
-- ----------------------------
DROP TABLE IF EXISTS `messages`;
CREATE TABLE `messages` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `conversation_id` bigint(20) unsigned NOT NULL COMMENT '对话ID',
  `user_id` bigint(20) unsigned NOT NULL COMMENT '用户ID',
  `role` enum('user','assistant','system') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '角色',
  `content` longtext COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '消息内容',
  `tokens` int(11) NOT NULL DEFAULT '0' COMMENT 'token数量',
  `model` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '使用的模型',
  `is_filtered` tinyint(4) NOT NULL DEFAULT '0' COMMENT '是否被过滤',
  `filter_reason` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '过滤原因',
  `medical_tags` json DEFAULT NULL COMMENT '医疗标签',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_conversation_id` (`conversation_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_role` (`role`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `fk_messages_conversation_id` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_messages_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息表';

-- ----------------------------
-- 系统配置表
-- ----------------------------
DROP TABLE IF EXISTS `system_config`;
CREATE TABLE `system_config` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `config_key` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '配置键',
  `config_value` longtext COLLATE utf8mb4_unicode_ci COMMENT '配置值',
  `config_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'string' COMMENT '配置类型',
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '配置描述',
  `is_public` tinyint(4) NOT NULL DEFAULT '0' COMMENT '是否公开',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统配置表';

-- ----------------------------
-- 操作日志表
-- ----------------------------
DROP TABLE IF EXISTS `operation_logs`;
CREATE TABLE `operation_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL COMMENT '用户ID',
  `action` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '操作动作',
  `resource` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '操作资源',
  `resource_id` bigint(20) DEFAULT NULL COMMENT '资源ID',
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'IP地址',
  `user_agent` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '用户代理',
  `request_data` json DEFAULT NULL COMMENT '请求数据',
  `response_data` json DEFAULT NULL COMMENT '响应数据',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'success' COMMENT '状态',
  `error_message` text COLLATE utf8mb4_unicode_ci COMMENT '错误信息',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_action` (`action`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_ip_address` (`ip_address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='操作日志表';

-- ----------------------------
-- 插入默认配置数据
-- ----------------------------
INSERT INTO `system_config` (`config_key`, `config_value`, `config_type`, `description`, `is_public`) VALUES
('medical_mode', 'true', 'boolean', '医疗模式开关', 1),
('medical_title', '医疗健康AI助手', 'string', '医疗系统标题', 1),
('medical_version', '1.0', 'string', '医疗系统版本', 1),
('max_daily_requests', '50', 'integer', '每日最大请求次数', 0),
('max_conversation_length', '20', 'integer', '最大对话长度', 0),
('enable_content_filter', 'true', 'boolean', '启用内容过滤', 0),
('blocked_keywords', '["药物滥用","自杀","暴力","违法"]', 'json', '屏蔽关键词', 0),
('openai_model', 'gpt-3.5-turbo', 'string', 'OpenAI模型', 0),
('system_prompt', '你是一个专业的医疗健康AI助手，专门为用户提供医疗健康相关的咨询和建议。', 'text', '系统提示词', 0);

-- ----------------------------
-- 创建默认管理员用户
-- ----------------------------
INSERT INTO `users` (`username`, `email`, `password`, `nickname`, `status`, `user_type`, `created_at`) VALUES
('admin', 'admin@medical-gpt.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '系统管理员', 1, 'admin', NOW());

-- 设置外键检查
SET FOREIGN_KEY_CHECKS = 1;

-- 创建索引优化
ALTER TABLE `conversations` ADD INDEX `idx_user_created` (`user_id`, `created_at`);
ALTER TABLE `messages` ADD INDEX `idx_conv_created` (`conversation_id`, `created_at`);
ALTER TABLE `operation_logs` ADD INDEX `idx_user_action_created` (`user_id`, `action`, `created_at`);

-- 创建视图：用户统计
CREATE VIEW `user_stats` AS
SELECT 
    u.id,
    u.username,
    u.user_type,
    u.daily_requests,
    u.total_requests,
    u.last_request_date,
    COUNT(DISTINCT c.id) as conversation_count,
    COUNT(DISTINCT m.id) as message_count,
    SUM(m.tokens) as total_tokens,
    u.created_at as register_date
FROM users u
LEFT JOIN conversations c ON u.id = c.user_id AND c.status = 1
LEFT JOIN messages m ON u.id = m.user_id
WHERE u.status = 1
GROUP BY u.id;

-- 创建存储过程：重置每日请求计数
DELIMITER //
CREATE PROCEDURE ResetDailyRequests()
BEGIN
    UPDATE users 
    SET daily_requests = 0 
    WHERE last_request_date < CURDATE() OR last_request_date IS NULL;
END //
DELIMITER ;

-- 创建事件：每日自动重置请求计数
-- SET GLOBAL event_scheduler = ON;
-- CREATE EVENT IF NOT EXISTS reset_daily_requests
-- ON SCHEDULE EVERY 1 DAY
-- STARTS TIMESTAMP(CURDATE() + INTERVAL 1 DAY)
-- DO CALL ResetDailyRequests();

SELECT 'Medical AI Assistant Database Initialized Successfully!' as message;