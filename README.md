# Devcontainer Configurations

Two devcontainer definitions for Claude CLI + Python 3 development environments.

## claude/

General-purpose development environment with unrestricted internet access.

- **Base**: python:3-bookworm (Debian 12)
- **Tools**: Claude Code CLI, Python 3 + pip + venv, GitHub CLI, Node.js/npm, Zellij, Git, fzf, jq, vim, zsh
- **Network**: Full internet access — no firewall restrictions
- **Use when**: Everyday development, running Claude CLI, accessing any external APIs or resources

## claude_sandbox/

Restricted execution environment with outbound firewall for running untrusted or AI-generated code safely.

- **Base**: python:3-bookworm (Debian 12)
- **Tools**: Same as `claude/`, plus iptables/ipset for network control
- **Network**: Allowlist-only — permits GitHub, Anthropic API, npm, PyPI, VSCode marketplace, and host network; blocks everything else
- **Use when**: Running untrusted code, testing AI-generated scripts, or when outbound network isolation is required
