# Security Hooks Overview

## 🛡️ Multi-Layered Protection System

This project uses **4 specialized safety hooks** to protect against accidental damage, data loss, and credential exposure when working with Claude Code.

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Claude Code (AI Agent)                │
└─────────────────────┬───────────────────────────┘
                      │
                      │ Attempts operation
                      ▼
┌─────────────────────────────────────────────────┐
│              PreToolUse Hooks                   │
│          (Run BEFORE execution)                 │
├─────────────────────────────────────────────────┤
│  1. Bash Command Validator                      │
│     ├─ Blocks: rm -rf /, dd, fork bombs        │
│     ├─ Blocks: Piping to bash, system control  │
│     └─ Tests: 5/5 passing                       │
├─────────────────────────────────────────────────┤
│  2. Git Operations Protection                   │
│     ├─ Blocks: Force push, hard reset          │
│     ├─ Blocks: History rewriting, git clean    │
│     └─ Tests: 8/8 passing                       │
├─────────────────────────────────────────────────┤
│  3. Sensitive File Protection (Write/Edit)      │
│     ├─ Blocks: .env, credentials, keys         │
│     ├─ Blocks: Lock files, .git/, .ssh/        │
│     └─ Tests: 8/8 passing                       │
├─────────────────────────────────────────────────┤
│  4. Credential Exposure Prevention (Read)       │
│     ├─ Blocks: Reading .env files              │
│     ├─ Blocks: Reading credentials, keys       │
│     └─ Tests: 9/9 passing                       │
└─────────────────────────────────────────────────┘
                      │
                      │ If allowed (exit 0)
                      ▼
┌─────────────────────────────────────────────────┐
│         Operation Executes Safely               │
└─────────────────────────────────────────────────┘
```

## Protection Matrix

| Operation Type            | Bash Validator | Git Protection | File Protection | Read Protection |
| ------------------------- | -------------- | -------------- | --------------- | --------------- |
| `rm -rf /`                | 🛑 BLOCKED     | -              | -               | -               |
| `git push --force`        | -              | 🛑 BLOCKED     | -               | -               |
| Edit `.env`               | -              | -              | 🛑 BLOCKED      | -               |
| Read `.env`               | -              | -              | -               | 🛑 BLOCKED      |
| `curl \| bash`            | 🛑 BLOCKED     | -              | -               | -               |
| `git reset --hard`        | -              | 🛑 BLOCKED     | -               | -               |
| Write `package-lock.json` | -              | -              | 🛑 BLOCKED      | -               |
| Read `credentials.json`   | -              | -              | -               | 🛑 BLOCKED      |
| `npm run lint`            | ✅ ALLOWED     | -              | -               | -               |
| `git commit`              | -              | ✅ ALLOWED     | -               | -               |
| Edit `src/App.tsx`        | -              | -              | ✅ ALLOWED      | -               |
| Read `package.json`       | -              | -              | -               | ✅ ALLOWED      |

## Configuration

All hooks are configured in `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "command": "validate-bash-command.py" },
          { "command": "protect-git-operations.py" }
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{ "command": "protect-sensitive-files.py" }]
      },
      {
        "matcher": "Read",
        "hooks": [{ "command": "prevent-credential-exposure.py" }]
      }
    ]
  }
}
```

## Quick Reference

### Most Commonly Blocked Operations

1. **File Deletion**: `rm -rf /`, `rm -rf ~`, `rm -rf *`
2. **Force Push**: `git push --force`, `git push -f`
3. **Environment Files**: Editing or reading `.env*`
4. **Hard Reset**: `git reset --hard`
5. **Remote Scripts**: `curl ... | bash`
6. **Credentials**: Any access to credential files
7. **SSH Keys**: Reading or editing private keys
8. **Lock Files**: Modifying package manager lock files

### Testing

```bash
# Run all tests (30 total)
cd .claude/hooks && ./test-all-hooks.sh

# Expected: ✓ All hooks are working correctly! Passed: 30 Failed: 0
```

### Bypassing When Necessary

If you genuinely need to perform a blocked operation:

1. **Verify** it's correct and necessary
2. **Consider** safer alternatives first
3. **Run manually** in your terminal (recommended)
4. **Or temporarily disable** hooks in settings

## Security Benefits

### 1. Defense in Depth

Multiple layers of protection catch different types of risks:

- **Bash validator**: System-level operations
- **Git protection**: Version control safety
- **File protection**: Write/edit operations
- **Read protection**: Information disclosure

### 2. Fail-Safe Design

- Blocks dangerous operations **before** execution
- Clear error messages explain why
- Suggests safer alternatives
- No false sense of security

### 3. Team Protection

- Committed to version control
- Consistent across all team members
- Prevents accidents from any source
- Educational error messages

### 4. Audit Trail

Each blocked operation:

- Logs the attempted command
- Shows the reason for blocking
- Provides remediation guidance
- Helps identify risky patterns

## Threat Model

### What This Protects Against

✅ **Accidental Mistakes**

- Typos that could be destructive
- Misremembered commands
- Copy-paste errors

✅ **Cognitive Overload**

- Rushed decisions
- Tired developers
- Context switching errors

✅ **AI Agent Errors**

- Claude making destructive suggestions
- AI not understanding context
- Hallucinated dangerous commands

✅ **Credential Exposure**

- Secrets appearing in chat logs
- API keys in conversation history
- Passwords in screen recordings

### What This Does NOT Protect Against

❌ **Malicious Intent**

- Deliberately running commands manually
- Disabling hooks intentionally
- Social engineering attacks

❌ **Application-Level Vulnerabilities**

- SQL injection
- XSS attacks
- Business logic flaws

❌ **Cloud/Service Compromise**

- Compromised AWS credentials (used externally)
- GitHub account takeover
- Third-party service breaches

## Maintenance

### Adding New Patterns

1. Edit the appropriate hook script (`.py` file)
2. Add pattern to relevant category
3. Add test case to test script
4. Run test suite to verify

### Performance

- All hooks execute in < 5ms (Python regex)
- Timeout set to 5 seconds (safety buffer)
- No network calls or I/O
- Negligible impact on workflow

### Updates

When updating hooks:

1. Test thoroughly with `./test-all-hooks.sh`
2. Document new patterns in README.md
3. Update test coverage numbers
4. Commit changes to share with team

## Additional Resources

- [Full Documentation](./README.md)
- [Quick Start Guide](./QUICKSTART.md)
- [Claude Code Hooks Reference](https://docs.claude.com/en/docs/claude-code/hooks.md)
- [Security Best Practices](https://docs.claude.com/en/docs/claude-code/security)

## Summary Statistics

- **Total Hooks**: 4
- **Total Test Coverage**: 30 tests
- **Current Status**: ✅ All passing
- **Protected Patterns**: 50+ dangerous patterns
- **Protected File Types**: 30+ sensitive files
- **Git Operations Blocked**: 10+ destructive operations

---

**Status**: 🟢 Active and protecting your system
**Last Updated**: 2025-11-04
**Test Status**: ✅ 30/30 passing
