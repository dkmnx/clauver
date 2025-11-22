# DeepSeek Provider Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add DeepSeek AI provider support to Clauver CLI with full integration like existing providers

**Architecture:** Add DeepSeek to provider configuration arrays, create switching function, register command, and update shell completions following the same pattern as Z.AI and MiniMax providers

**Tech Stack:** Bash scripting, age encryption, Claude Code API provider abstraction

---

### Task 1: Add DeepSeek to Provider Configuration Arrays

**Files:**

- Modify: `clauver.sh:859-869`

**Step 1: Update PROVIDER_CONFIGS array**

```bash
# Current line 859-862
declare -A PROVIDER_CONFIGS=(
  ["zai"]="Z.AI|https://api.z.ai/api/anthropic|ZAI_API_KEY|glm-4.5-air|glm-4.6|glm-4.6"
  ["minimax"]="MiniMax|https://api.minimax.io/anthropic|MINIMAX_API_KEY|MiniMax-M2|MiniMax-M2|MiniMax-M2"
)

# Add DeepSeek entry after minimax
[\"deepseek\"]=\"DeepSeek|https://api.deepseek.com/anthropic|DEEPSEEK_API_KEY|deepseek-chat|deepseek-chat|deepseek-chat\"
```

**Step 2: Update PROVIDER_REQUIRES array**

```bash
# Current line 865-868
declare -A PROVIDER_REQUIRES=(
  ["zai"]="api_key"
  ["minimax"]="api_key"
  ["kimi"]="api_key,model,url"
)

# Add DeepSeek entry after minimax
[\"deepseek\"]=\"api_key\"
```

**Step 3: Verify syntax**

Run: `bash -n clauver.sh`
Expected: No output (syntax OK)

**Step 4: Commit**

```bash
git add clauver.sh
git commit -m "feat: add DeepSeek to provider configuration arrays"
```

### Task 2: Add DeepSeek Provider Defaults

**Files:**

- Modify: `clauver.sh:27-34`
- Modify: `clauver.sh:37-45`

**Step 1: Add DeepSeek defaults to PROVIDER_DEFAULTS**

```bash
# Current line 27-34
declare -A PROVIDER_DEFAULTS=(
  ["zai_base_url"]="https://api.z.ai/api/anthropic"
  ["zai_default_model"]="glm-4.6"
  ["minimax_base_url"]="https://api.minimax.io/anthropic"
  ["minimax_default_model"]="MiniMax-M2"
  ["kimi_base_url"]="https://api.kimi.com/coding/"
  ["kimi_default_model"]="kimi-for-coding"
)

# Add DeepSeek entries after kimi
[\"deepseek_base_url\"]=\"https://api.deepseek.com/anthropic\"
[\"deepseek_default_model\"]=\"deepseek-chat\"
```

**Step 2: Add DeepSeek timeout to PERFORMANCE_DEFAULTS**

```bash
# Current line 37-45
declare -A PERFORMANCE_DEFAULTS=(
  ["network_connect_timeout"]="10"
  ["network_max_time"]="30"
  ["minimax_small_fast_timeout"]="120"
  ["minimax_small_fast_max_tokens"]="24576"
  ["kimi_small_fast_timeout"]="240"
  ["kimi_small_fast_max_tokens"]="200000"
  ["test_api_timeout_ms"]="3000000"
)

# Add DeepSeek timeout after kimi
[\"deepseek_api_timeout_ms\"]=\"600000\"
```

**Step 3: Verify syntax**

Run: `bash -n clauver.sh`
Expected: No output (syntax OK)

**Step 4: Commit**

```bash
git add clauver.sh
git commit -m "feat: add DeepSeek provider defaults and timeout settings"
```

### Task 3: Add DeepSeek Case to Provider Switching

**Files:**

- Modify: `clauver.sh:923-956`

**Step 1: Add DeepSeek case to switch_to_provider**

```bash
# Find the switch_to_provider case statement around line 923-956
# Add DeepSeek case after kimi case

    "kimi")
      banner "Moonshot AI (Kimi)"
      export ANTHROPIC_BASE_URL="$url"
      export ANTHROPIC_AUTH_TOKEN="$api_key"
      export ANTHROPIC_MODEL="$model"
      export ANTHROPIC_SMALL_FAST_MODEL="$model"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="$model"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="$model"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="$model"
      export ANTHROPIC_SMALL_FAST_MODEL_TIMEOUT="${PERFORMANCE_DEFAULTS[kimi_small_fast_timeout]}"
      export ANTHROPIC_SMALL_FAST_MAX_TOKENS="${PERFORMANCE_DEFAULTS[kimi_small_fast_max_tokens]}"
      ;;
    "deepseek")
      banner "DeepSeek AI"
      export ANTHROPIC_BASE_URL="${PROVIDER_DEFAULTS[deepseek_base_url]}"
      export ANTHROPIC_AUTH_TOKEN="$api_key"
      export ANTHROPIC_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export ANTHROPIC_SMALL_FAST_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="${PROVIDER_DEFAULTS[deepseek_default_model]}"
      export API_TIMEOUT_MS="${PERFORMANCE_DEFAULTS[deepseek_api_timeout_ms]}"
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
      ;;
```

**Step 2: Verify syntax**

Run: `bash -n clauver.sh`
Expected: No output (syntax OK)

**Step 3: Commit**

```bash
git add clauver.sh
git commit -m "feat: add DeepSeek case to provider switching function"
```

### Task 4: Register DeepSeek Command

**Files:**

- Modify: `clauver.sh:1551-1566`
- Modify: `clauver.sh:1572-1589`
- Modify: `clauver.sh:1605-1621`

**Step 1: Add deepseek command to main dispatcher**

```bash
# Current line 1551-1566
  anthropic)
    shift
    switch_to_anthropic "$@"
    ;;
  zai)
    shift
    switch_to_zai "$@"
    ;;
  minimax)
    shift
    switch_to_minimax "$@"
    ;;
  kimi)
    shift
    switch_to_kimi "$@"
    ;;

# Add deepseek command after kimi
  deepseek)
    shift
    switch_to_provider "deepseek" "$@"
    ;;
```

**Step 2: Add deepseek to default provider case**

```bash
# Current line 1572-1589
      case "$default_provider" in
        anthropic)
          switch_to_anthropic "$@"
          ;;
        zai)
          switch_to_zai "$@"
          ;;
        minimax)
          switch_to_minimax "$@"
          ;;
        kimi)
          switch_to_kimi "$@"
          ;;

# Add deepseek case after kimi
        deepseek)
          switch_to_provider "deepseek" "$@"
          ;;
```

**Step 3: Add deepseek to default provider fallback case**

```bash
# Current line 1605-1621
        case "$default_provider" in
          anthropic)
            switch_to_anthropic "$@"
            ;;
          zai)
            switch_to_zai "$@"
            ;;
          minimax)
            switch_to_minimax "$@"
            ;;
          kimi)
            switch_to_kimi "$@"
            ;;

# Add deepseek case after kimi
          deepseek)
            switch_to_provider "deepseek" "$@"
            ;;
```

**Step 4: Verify syntax**

Run: `bash -n clauver.sh`
Expected: No output (syntax OK)

**Step 5: Commit**

```bash
git add clauver.sh
git commit -m "feat: register DeepSeek command in main dispatcher"
```

### Task 5: Update Shell Completions

**Files:**

- Modify: `completion/clauver.bash`
- Modify: `completion/clauver.zsh`
- Modify: `completion/clauver.fish`

**Step 1: Update bash completion**

```bash
# Find the provider list in clauver.bash
# Add "deepseek" to the list

# Example: look for line like this and add deepseek
# local providers="anthropic zai minimax kimi"
local providers="anthropic zai minimax kimi deepseek"
```

**Step 2: Update zsh completion**

```bash
# Find the provider list in clauver.zsh
# Add "deepseek" to the list

# Example: look for line like this and add deepseek
# providers=(anthropic zai minimax kimi)
providers=(anthropic zai minimax kimi deepseek)
```

**Step 3: Update fish completion**

```bash
# Find the provider list in clauver.fish
# Add "deepseek" to the list

# Example: look for line like this and add deepseek
# complete -c clauver -f -n "__fish_seen_subcommand_from config" -a "anthropic zai minimax kimi"
complete -c clauver -f -n "__fish_seen_subcommand_from config" -a "anthropic zai minimax kimi deepseek"
```

**Step 4: Test completions**

Run: `source completion/clauver.bash && complete -p clauver`
Expected: Shows clauver completion definitions

**Step 5: Commit**

```bash
git add completion/
git commit -m "feat: add DeepSeek to shell completions"
```

### Task 6: Test DeepSeek Integration

**Files:**

- Test: `clauver.sh`

**Step 1: Test syntax validation**

Run: `shellcheck clauver.sh`
Expected: No warnings or errors

**Step 2: Test help command**

Run: `./clauver.sh --help`
Expected: Shows help with DeepSeek provider mentioned

**Step 3: Test status command**

Run: `./clauver.sh status`
Expected: Shows DeepSeek in provider list as "not configured"

**Step 4: Test config command**

Run: `./clauver.sh config deepseek`
Expected: Prompts for DEEPSEEK_API_KEY

**Step 5: Commit**

```bash
git add .
git commit -m "test: verify DeepSeek integration works correctly"
```

### Task 7: Update Documentation

**Files:**

- Modify: `README.md`
- Modify: `CLAUDE.md`

**Step 1: Update README.md provider list**

```markdown
# Find the provider management section in README.md
# Add DeepSeek to the list

## Provider Management

### Built-in Providers:
- **anthropic**: Native Anthropic Claude (requires `claude` CLI)
- **zai**: Zhipu AI's GLM models
- **minimax**: MiniMax AI's MiniMax-M2 model
- **kimi**: Moonshot AI's Kimi K2 model
- **deepseek**: DeepSeek AI's deepseek-chat model
```

**Step 2: Update CLAUDE.md provider list**

```markdown
# Find the provider support section in CLAUDE.md
# Add DeepSeek to the list

### Provider Support

**Built-in Providers:**
- **anthropic**: Native Anthropic Claude (requires `claude` CLI)
- **zai**: Zhipu AI's GLM models
- **minimax**: MiniMax AI's MiniMax-M2 model
- **kimi**: Moonshot AI's Kimi K2 model
- **deepseek**: DeepSeek AI's deepseek-chat model
```

**Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: add DeepSeek to provider documentation"
```

### Task 8: Final Integration Test

**Files:**

- Test: `clauver.sh`

**Step 1: Test full workflow**

```bash
# Set test API key (fake key for testing)
DEEPSEEK_API_KEY="sk-test123" ./clauver.sh config deepseek

# Test switching to DeepSeek
./clauver.sh deepseek --help

# Test setting as default
./clauver.sh default deepseek
./clauver.sh --help
```

**Step 2: Verify environment variables**

```bash
# Test that environment variables are set correctly
DEEPSEEK_API_KEY="sk-test123" ./clauver.sh deepseek --help 2>&1 | grep -E "(ANTHROPIC_BASE_URL|ANTHROPIC_MODEL|API_TIMEOUT_MS)" || echo "Environment variables not visible in help output (expected)"
```

**Step 3: Final commit**

```bash
git add .
git commit -m "feat: complete DeepSeek provider integration"
```
