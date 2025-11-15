# Troubleshooting

Common issues and solutions for _Clauver_.

## PATH Issues

If `clauver` is not found after installation, export the path for the current session.

```bash
export PATH="$HOME/.clauver/bin:$PATH"
```

Make it permanent by adding the path to your shell config file.

```bash
# Bash
echo 'export PATH="$HOME/.clauver/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Zsh
echo 'export PATH="$HOME/.clauver/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Fish
echo 'set -gx PATH $HOME/.clauver/bin $PATH' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish
```

## Provider Test Fails

1. Make sure you have a valid API key and valid subscription or enough credits
for the provider.
2. Check your API key is correctly configured: `clauver list`
3. Ensure you have internet connectivity
4. Test the provider directly: `clauver test <provider>`

## Claude Command Not Found

Install Claude Code CLI:

```bash
npm install -g @anthropic-ai/claude-code
```

## API Key Won't Update

If updating an API key doesn't take effect:

```bash
# 1. Verify the new key was saved
clauver list

# 2. If it shows the old key, try reconfiguring
clauver config <provider>

# 3. Check your age key exists
ls -la ~/.clauver/age.key

# 4. If age key is missing, restore from backup or reconfigure
```

## Encryption/Decryption Errors

If you see "Failed to decrypt secrets file" or similar errors:

```bash
# 1. Verify age is installed
age --version

# 2. Check if your age key exists and has correct permissions
ls -la ~/.clauver/age.key
chmod 600 ~/.clauver/age.key  # Fix permissions if needed

# 3. If age key is corrupted or lost, restore from backup:
cp ~/backup/clauver-age.key.backup ~/.clauver/age.key
chmod 600 ~/.clauver/age.key

# 4. If no backup exists, start fresh:
rm ~/.clauver/secrets.env.age
clauver config <provider>  # Reconfigure all providers
```

## Missing age Command

If you see "age command not found":

```bash
# Debian/Ubuntu
sudo apt install age

# Fedora/RHEL
sudo dnf install age

# Arch Linux
sudo pacman -S age

# macOS
brew install age

# Verify installation
age --version
```

## Corrupted Configuration

If clauver behaves unexpectedly:

```bash
# 1. Check current configuration
clauver list
clauver status

# 2. Backup your age key first (IMPORTANT!)
cp ~/.clauver/age.key ~/age.key.backup

# 3. Test decryption manually
age -d -i ~/.clauver/age.key ~/.clauver/secrets.env.age

# 4. If decryption fails, secrets file may be corrupted
# Remove and reconfigure (your age key is still safe):
rm ~/.clauver/secrets.env.age
clauver config <provider>
```

## Getting Help

If you're still having issues:

1. Check the [main README.md](README.md) for complete documentation
2. Run `clauver help` for command usage
3. Use `clauver status` to check your configuration
4. Test individual providers with `clauver test <provider>`

---

For bug reports or feature requests, please visit the [GitHub repository](https://github.com/dkmnx/clauver).
