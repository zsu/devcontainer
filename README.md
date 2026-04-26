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

## Setup

### Linux host (DevPod — SSH into devcontainer)

Run `scripts/setup.sh` on the host to install Docker, DevPod, and all required tools. Supports Ubuntu/Debian and RHEL/CentOS/Rocky/Alma/Fedora. Use `source` so the SSH agent environment is applied to your current shell:

```bash
source scripts/setup.sh
```

### Windows client (VS Code + Dev Containers)

```powershell
.\scripts\setup.ps1
```

Installs Rancher Desktop (free Docker engine, Apache 2.0), VS Code, and the Dev Containers extension via `winget`.

### macOS client (VS Code + Dev Containers)

```bash
bash scripts/setup-mac.sh
```

Installs Rancher Desktop, VS Code, and the Dev Containers extension via Homebrew.

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

4. Load the key into the SSH agent. **Run `source scripts/setup.sh` first if you haven't already** — it installs and starts the agent service. Steps 1–3 above can be done before or after `setup.sh`, but `ssh-add` requires the agent to be running:
   ```bash
   ssh-add ~/.ssh/id_ed25519
   ```

After this, the agent retains the key across reboots and forwards it into devcontainers automatically. No further steps are needed before `devpod up`.

**Verify:**
```bash
ssh-add -l                  # list loaded keys
ssh -T git@github.com       # test GitHub access
```

## Using the devcontainer

There are two ways to launch and connect to the devcontainer depending on your platform:

---

### Option A — Linux host: DevPod (SSH access)

**How it works:** DevPod runs on the Linux host, builds and starts the container, and gives you direct SSH access. No GUI required.

**Step 1 — Launch the container**

Use an SSH URL so the repo remote inside the container uses SSH (required for git auth passthrough). Always pass `--ide none` to prevent DevPod from opening a browser:

```bash
devpod up git@github.com:<org>/<repo>.git[@branch] --ide none
```

> **Avoid HTTPS URLs** — DevPod clones using the URL you provide, so an HTTPS URL creates an HTTPS remote inside the container that will prompt for credentials on every `git fetch`/`push`.

**Step 2 — SSH into the container**

```bash
ssh <workspace-name>.devpod
```

The workspace name is the repo name lowercased:
```bash
devpod up git@github.com:org/MyRepo.git --ide none
ssh myrepo.devpod
```

List all workspaces and their exact names:
```bash
devpod list
```

**Step 3 — Git SSH authentication**

The host SSH agent is forwarded automatically into the container via `SSH_AUTH_SOCK`. Ensure your key is loaded on the host before running `devpod up`:
```bash
ssh-add -l              # verify keys are loaded
ssh -T git@github.com   # test GitHub access from inside container
```

**Stop / delete a workspace**
```bash
devpod stop <workspace-name>
devpod delete <workspace-name>
```

**Troubleshooting**
- **Container not starting**: `sudo systemctl start docker`
- **Browser/GUI launches**: always include `--ide none`
- **SSH connection refused**: re-run `devpod up ... --ide none` to restart a stopped workspace
- **Git auth fails**: check keys are loaded — `ssh-add -l`

---

### Option B — Windows / macOS: VS Code + Dev Containers extension

**How it works:** VS Code connects to the container directly via the Dev Containers extension. Rancher Desktop provides the Docker engine. No SSH command needed — VS Code opens a full editor window inside the container.

**Step 1 — Start Rancher Desktop**

Open Rancher Desktop and ensure the container engine is set to **dockerd (moby)**:
`Preferences → Container Engine → dockerd (moby)`

**Step 2 — Open the repo in VS Code**

Clone the repo locally, open it in VS Code, then either:
- Click **"Reopen in Container"** in the notification that appears, or
- Press `F1` → **Dev Containers: Reopen in Container**

VS Code will build the image and reopen the editor inside the container.

To use a specific environment (`claude/` or `claude_sandbox/`), VS Code will prompt you to choose if multiple `.devcontainer` configurations are found. Alternatively use:

`F1` → **Dev Containers: Clone Repository in Container Volume** → paste the repo URL

**Step 3 — Git SSH authentication**

Ensure your SSH key is loaded in the system agent **before** opening the container:

- **macOS**: `ssh-add ~/.ssh/id_ed25519` (keychain keeps it across reboots)
- **Windows**: ensure OpenSSH agent is running, then:
  ```powershell
  Start-Service ssh-agent
  ssh-add "$env:USERPROFILE\.ssh\id_ed25519"
  ```

The Dev Containers extension forwards `SSH_AUTH_SOCK` from your machine into the container automatically.

**Troubleshooting**
- **"Docker not found"**: ensure Rancher Desktop is running and engine is set to `dockerd`
- **Git auth fails**: check key is loaded — `ssh-add -l` — and that `SSH_AUTH_SOCK` is set in your terminal
