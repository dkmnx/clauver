# Clauver version - matching VERSION from clauver.sh
$script:ClauverVersion = "1.12.1"

# Configuration constants - extracted from hardcoded values in clauver.sh (lines 30-51)
$script:ProviderDefaults = @{
    'zai_base_url' = 'https://api.z.ai/api/anthropic'
    'zai_default_model' = 'glm-4.6'
    'minimax_base_url' = 'https://api.minimax.io/anthropic'
    'minimax_default_model' = 'MiniMax-M2'
    'kimi_base_url' = 'https://api.kimi.com/coding/'
    'kimi_default_model' = 'kimi-for-coding'
    'deepseek_base_url' = 'https://api.deepseek.com/anthropic'
    'deepseek_default_model' = 'deepseek-chat'
}

# Timeout and token limits - matching PERFORMANCE_DEFAULTS from clauver.sh (lines 40-50)
$script:PerformanceDefaults = @{
    'network_connect_timeout' = '10'
    'network_max_time' = '30'
    'minimax_small_fast_timeout' = '120'
    'minimax_small_fast_max_tokens' = '24576'
    'kimi_small_fast_timeout' = '240'
    'kimi_small_fast_max_tokens' = '200000'
    'deepseek_api_timeout_ms' = '600000'
    'test_api_timeout_ms' = '3000000'
}

# Provider configuration metadata - matching PROVIDER_REQUIRES from clauver.sh
$script:ProviderRequires = @{
    'zai' = @('api_key', 'model', 'url')
    'minimax' = @('api_key', 'model', 'url')
    'deepseek' = @('api_key', 'model', 'url')
    'kimi' = @('api_key', 'model', 'url')
}

# Provider abstraction layer - matching PROVIDER_CONFIGS from clauver.sh
$script:ProviderConfigs = @{
    'zai' = @{
        'Name' = 'Z.AI'
        'BaseUrl' = 'https://api.z.ai/api/anthropic'
        'ApiKeyVar' = 'ZAI_API_KEY'
        'DefaultHaikuModel' = 'glm-4.5-air'
        'DefaultSonnetModel' = 'glm-4.6'
        'DefaultOpusModel' = 'glm-4.6'
    }
    'minimax' = @{
        'Name' = 'MiniMax'
        'BaseUrl' = 'https://api.minimax.io/anthropic'
        'ApiKeyVar' = 'MINIMAX_API_KEY'
        'Model' = 'MiniMax-M2'
    }
    'deepseek' = @{
        'Name' = 'DeepSeek'
        'BaseUrl' = 'https://api.deepseek.com/anthropic'
        'ApiKeyVar' = 'DEEPSEEK_API_KEY'
        'Model' = 'deepseek-chat'
    }
}

# Validation constants
$script:MinApiKeyLength = 10
$script:AnthropicTestTimeout = 5
$script:ProviderTestTimeout = 10
$script:DownloadTimeout = 60

# GitHub API configuration
$script:GitHubApiBase = "https://api.github.com/repos/dkmnx/clauver"
$script:RawContentBase = "https://raw.githubusercontent.com/dkmnx/clauver"

# Export constants
