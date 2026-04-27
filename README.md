# Devcontainer Configurations

Shared devcontainer definitions for Claude CLI + Python 3 development environments.
Other repos consume this repo as a **git submodule** at `.devcontainer/` — one source
of truth, no duplication.

## Environments

### Default — AI Dev

General-purpose development environment with unrestricted internet access.

- **Base**: python:3-bookworm (Debian 12)
- **Tools**: Claude Code CLI, Python 3 + pip + venv, GitHub CLI, Node.js/npm, Zellij, Git, fzf, jq, vim, cron
- **Network**: Full internet access — no firewall restrictions
- **Use when**: Everyday development, running Claude CLI, accessing any external APIs or resources

### claude_sandbox/

Restricted execution environment with outbound firewall for running untrusted or AI-generated code safely.

- **Base**: python:3-bookworm (Debian 12)
- **Tools**: Same as default, plus iptables/ipset for network control
- **Network**: Allowlist-only — permits GitHub, Anthropic API, npm, PyPI, VSCode marketplace, and host network; blocks everything else
- **Use when**: Running untrusted code, testing AI-generated scripts, or when outbound network isolation is required

---

## Host Setup

### Linux

DevPod runs on the Linux host, builds and starts the container, and gives you direct SSH access. No GUI required. Supports Ubuntu/Debian and RHEL/CentOS/Rocky/Alma/Fedora.

#### 1. Install tools

Use `source` so the SSH agent environment is applied to your current shell:

```bash
source scripts/setup.sh
```

#### 2. SSH key setup

Generate a new key (or skip if you already have one):
```bash
ssh-keygen -t ed25519 -C "your@email.com"
```
Or copy an existing key from another machine:
```bash
scp ~/.ssh/id_ed25519 user@host:~/.ssh/id_ed25519
ssh user@host "chmod 600 ~/.ssh/id_ed25519"
```

Add the public key to GitHub under **Settings → SSH and GPG keys → New SSH key**:
```bash
cat ~/.ssh/id_ed25519.pub
```

Set correct permissions (SSH refuses keys that are too open):
```bash
chmod 600 ~/.ssh/id_ed25519
```

Load the key into the agent (`setup.sh` must have been run first — it installs and starts the agent service):
```bash
ssh-add ~/.ssh/id_ed25519
```

The agent retains the key across reboots and forwards it into devcontainers automatically.

Verify:
```bash
ssh-add -l              # list loaded keys
ssh -T git@github.com   # test GitHub access
```

#### 3. Launch the devcontainer

Use an SSH URL so the repo remote inside the container uses SSH (required for git auth passthrough). Always pass `--ide none` to prevent DevPod from opening a browser:

```bash
devpod up git@github.com:<org>/<repo>.git[@branch] --ide none
```

> **Avoid HTTPS URLs** — DevPod clones using the URL you provide, so an HTTPS URL creates an HTTPS remote inside the container that will prompt for credentials on every `git fetch`/`push`.

SSH into the container:
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

Stop or delete a workspace:
```bash
devpod stop <workspace-name>
devpod delete <workspace-name>
```

#### Troubleshooting

- **Container not starting**: `sudo systemctl start docker`
- **Browser/GUI launches**: always include `--ide none`
- **SSH connection refused**: re-run `devpod up ... --ide none` to restart a stopped workspace
- **Git auth fails**: check keys are loaded — `ssh-add -l`

---

### Windows

VS Code connects to the container via the Dev Containers extension. Rancher Desktop provides the Docker engine (free, Apache 2.0).

#### 1. Install tools

```powershell
.\scripts\setup.ps1
```

Installs Rancher Desktop, VS Code, the Dev Containers extension via `winget`, and configures git.

#### 2. SSH key setup

Generate a new key (or skip if you already have one):
```powershell
ssh-keygen -t ed25519 -C "your@email.com"
```
`ssh-keygen` sets permissions automatically. If you copy an existing key instead, fix permissions with:
```powershell
icacls "$env:USERPROFILE\.ssh\id_ed25519" /inheritance:r /grant:r "${env:USERNAME}:R"
```

Add the public key to GitHub under **Settings → SSH and GPG keys → New SSH key**:
```powershell
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
```

Start the OpenSSH agent service and load your key:
```powershell
Start-Service ssh-agent
ssh-add "$env:USERPROFILE\.ssh\id_ed25519"
```

To start the agent automatically on every boot:
```powershell
Set-Service ssh-agent -StartupType Automatic
```

Verify:
```powershell
ssh-add -l              # list loaded keys
ssh -T git@github.com   # test GitHub access
```

#### 3. Launch the devcontainer

Start Rancher Desktop and ensure the container engine is set to **dockerd (moby)**:
`Preferences → Container Engine → dockerd (moby)`

Clone the repo locally, open it in VS Code, then either:
- Click **"Reopen in Container"** in the notification that appears, or
- Press `F1` → **Dev Containers: Reopen in Container**

VS Code will build the image and reopen the editor inside the container.

The Dev Containers extension forwards the SSH agent from your machine into the container automatically.

#### Troubleshooting

- **"Docker not found"**: ensure Rancher Desktop is running and engine is set to `dockerd`
- **Git auth fails**: check key is loaded — `ssh-add -l`

---

### macOS

VS Code connects to the container via the Dev Containers extension. Rancher Desktop provides the Docker engine (free, Apache 2.0).

#### 1. Install tools

```bash
bash scripts/setup-mac.sh
```

Installs Rancher Desktop, VS Code, the Dev Containers extension via Homebrew, and configures git.

#### 2. SSH key setup

Generate a new key (or skip if you already have one):
```bash
ssh-keygen -t ed25519 -C "your@email.com"
```

Add the public key to GitHub under **Settings → SSH and GPG keys → New SSH key**:
```bash
cat ~/.ssh/id_ed25519.pub
```

Set correct permissions:
```bash
chmod 600 ~/.ssh/id_ed25519
```

Load the key — the macOS keychain keeps it loaded across reboots automatically:
```bash
ssh-add ~/.ssh/id_ed25519
```

Verify:
```bash
ssh-add -l              # list loaded keys
ssh -T git@github.com   # test GitHub access
```

#### 3. Launch the devcontainer

Start Rancher Desktop and ensure the container engine is set to **dockerd (moby)**:
`Preferences → Container Engine → dockerd (moby)`

Clone the repo locally, open it in VS Code, then either:
- Click **"Reopen in Container"** in the notification that appears, or
- Press `F1` → **Dev Containers: Reopen in Container**

VS Code will build the image and reopen the editor inside the container.

The Dev Containers extension forwards the SSH agent from your machine into the container automatically.

#### Troubleshooting

- **"Docker not found"**: ensure Rancher Desktop is running and engine is set to `dockerd`
- **Git auth fails**: check key is loaded — `ssh-add -l`

---

## Using this repo as a submodule

### Add to a repo (once)

```bash
git submodule add git@github.com:<org>/devcontainer.git .devcontainer
git commit -m "Add devcontainer as submodule"
```

### Clone a repo that already has the submodule

```bash
git clone --recurse-submodules git@github.com:<org>/<repo>.git
```

### Update devcontainer to latest

Run these on the **host** (not inside the devcontainer):

```bash
# In the devcontainer repo — pull latest, push
git pull && git push

# In the consumer repo — advance the submodule pointer, push
git submodule update --remote .devcontainer
git add .devcontainer && git commit -m "Update devcontainer to latest" && git push
```

Then rebuild the container to apply the changes:

**DevPod:**
```bash
devpod up git@github.com:<org>/<repo>.git --recreate --ide none
```

**VS Code:**
`F1` → **Dev Containers: Rebuild Container**

### VS Code behaviour

VS Code **always prompts** to choose a configuration when the `.devcontainer/` folder contains more than one `devcontainer.json` (root + `claude_sandbox/`).

- **Default env**: `F1` → **Dev Containers: Reopen in Container** → choose **AI Dev**
- **Sandbox env**: same, choose **AI Dev Sandbox**

### DevPod behaviour

DevPod automatically uses `.devcontainer/devcontainer.json` (the default env) without prompting.

- **Default env**: `devpod up git@github.com:<org>/<repo>.git --ide none`
- **Sandbox env**: add `--devcontainer-path .devcontainer/claude_sandbox/devcontainer.json`
