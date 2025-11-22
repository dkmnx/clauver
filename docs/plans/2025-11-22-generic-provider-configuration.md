# Generic Provider Configuration System Design

**Goal:** Extend Kimi's interactive configuration system to work for all providers, allowing dynamic prompting for different parameters like URL, API key, model, etc.

**Architecture:** Create a unified `config_provider_settings()` function that reads from `PROVIDER_REQUIRES` metadata to dynamically prompt for required fields with appropriate validation and defaults.

**Tech Stack:** Bash scripting, existing configuration system, validation functions

---

## Design Overview

### Core Components

1. **Dynamic Field Processing**
   - Parse `PROVIDER_REQUIRES` to determine what fields to prompt for
   - Support field types: `api_key`, `model`, `url` (extensible)
   - Use existing validation functions for each field type

2. **Configuration Storage**
   - Each provider gets its own namespace: `{provider}_model`, `{provider}_base_url`, etc.
   - Uses existing `get_config()` and `set_config()` functions
   - Maintains backward compatibility with current Kimi configuration

3. **User Experience**
   - Show current values before prompting
   - Provide sensible defaults from `PROVIDER_DEFAULTS`
   - Allow skipping prompts by pressing Enter
   - Consistent validation and error handling

### Data Flow

```
PROVIDER_REQUIRES["provider"] = "api_key,model,url"
↓
Parse into fields: ["api_key", "model", "url"]
↓
For each field:
  - Get current value: get_config("provider_field")
  - Show current value if exists
  - Prompt with default: PROVIDER_DEFAULTS["provider_default_field"]
  - Validate input using field-specific validation
  - Store: set_config("provider_field", value)
```

### Field Types & Validation

- **api_key**: Secret input (`read -rs`), stored encrypted, validated with `validate_api_key()`
- **model**: Validated with `validate_model_name()`
- **url**: Validated with `validate_url()`
- **Future fields**: Can be added easily by extending validation logic

### Integration Points

- Called from existing `config_provider()` function
- Works alongside current API key configuration flow
- Optional - users can skip configuration prompts
- Backward compatible with existing configurations

### User Experience Flow

```bash
$ clauver config minimax
Current API key: [hidden]
Enter API key: [hidden input]
Current model: MiniMax-M2
Model (default: MiniMax-M2): [user can change or press Enter]
Configuration saved!
```

### Benefits

- Unified experience across all providers
- No breaking changes to existing workflows
- Easy to extend with new field types
- Maintains security with encrypted API key storage
- Uses existing validation and configuration infrastructure

---

## Implementation Plan

### Task 1: Create Generic Configuration Function
- Implement `config_provider_settings()` function
- Handle dynamic field processing based on `PROVIDER_REQUIRES`
- Integrate existing validation functions
- Support field-specific prompting and defaults

### Task 2: Update Provider Requirements
- Modify `PROVIDER_REQUIRES` array to include `model` and `url` for appropriate providers
- Ensure backward compatibility with current Kimi configuration
- Add appropriate default values to `PROVIDER_DEFAULTS`

### Task 3: Integration
- Call `config_provider_settings()` from `config_provider()` function
- Ensure seamless integration with existing API key flow
- Test with all provider types

### Task 4: Testing
- Unit tests for each field type validation
- Integration tests for provider configuration flows
- Verify backward compatibility
- Test edge cases and error conditions

### Task 5: Documentation
- Update README with new configuration capabilities
- Update CLAUDE.md with implementation details
- Add examples for custom provider configuration

---

## Success Criteria

- All providers support interactive configuration
- Existing configurations continue to work unchanged
- Users can customize model and URL for any provider
- Validation prevents invalid configurations
- Security is maintained with encrypted API key storage
- Code follows existing patterns and standards