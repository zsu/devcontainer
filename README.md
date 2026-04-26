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

## Host Setup

Run `scripts/setup.sh` on the host to install Docker, DevPod, and all required tools. Use `source` so the SSH agent environment is applied to your current shell:

```bash
source scripts/setup.sh
```

### SSH Key Setup (required for git authentication inside devcontainers)

The host's SSH agent is forwarded into every devcontainer, so git operations against private repos work without any extra configuration inside the container.

**One-time setup:**

1. Ensure your private key is on the host. Either generate a new one:
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com"
   ```
   Or copy an existing key from your machine:
   ```bash
   scp ~/.ssh/id_ed25519 user@host:~/.ssh/id_ed25519
   ssh user@host "chmod 600 ~/.ssh/id_ed25519"
   ```

2. If generating a new key, add the public key to GitHub under **Settings → SSH and GPG keys → New SSH key**:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

3. Ensure the key file has correct permissions (SSH will refuse to use it otherwise):
   ```bash
   chmod 600 ~/.ssh/id_ed25519
   ```

4. Load the key into the SSH agent (the agent is installed and enabled on boot by `setup.sh`):
   ```bash
   ssh-add ~/.ssh/id_ed25519
   ```

After this, the agent retains the key across reboots and forwards it into devcontainers automatically. No further steps are needed before `devpod up`.

**Verify:**
```bash
ssh-add -l                  # list loaded keys
ssh -T git@github.com       # test GitHub access
```

## Using DevPod

### Launch a devcontainer

Use SSH URLs so the repo remote inside the container is SSH-based and git operations use the forwarded SSH agent automatically. Always pass `--ide none` to suppress the browser/GUI:

```bash
devpod up git@github.com:<org>/<repo>.git[@branch] --ide none
```

Examples:
```bash
devpod up git@github.com:org/repo.git --ide none
devpod up git@github.com:org/repo.git@main --ide none
```

> **Avoid HTTPS URLs** (`https://github.com/...`) — DevPod clones the repo using the URL you provide, so an HTTPS URL results in an HTTPS remote inside the container which will prompt for credentials on every `git fetch`/`push`.

DevPod reads the `.devcontainer/devcontainer.json` from the repo, builds the image, and starts the container. Use the `claude/` or `claude_sandbox/` directory of this repo to point DevPod at a specific environment.

### SSH into a running devcontainer

```bash
ssh <workspace-name>.devpod
```

The workspace name is the repo name lowercased. For example:
```bash
devpod up git@github.com:org/MyRepo.git --ide none
ssh myrepo.devpod
```

List all workspaces and their exact names:
```bash
devpod list
```

### Stop and delete a workspace

```bash
devpod stop <workspace-name>
devpod delete <workspace-name>
```

### Troubleshooting

- **Container not starting**: ensure Docker is running — `sudo systemctl start docker`
- **SSH connection refused**: run `devpod up git@github.com:<org>/<repo>.git --ide none` again to restart a stopped workspace
- **Browser/GUI mode launching unexpectedly**: always pass `--ide none` to `devpod up`
- **Git auth fails inside container**: check that keys are loaded on the host — `ssh-add -l`
