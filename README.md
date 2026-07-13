# 🖥️ dotfiles

> Cross-platform terminal setup — one command to a beautiful, productive shell.

**Supports:** macOS (Apple Silicon + Intel) · Ubuntu/Debian · Fedora/RHEL · Arch Linux

---

## ✨ What this installs

| Category | Tools |
|---|---|
| **Shell** | zsh + Oh-My-Zsh + Powerlevel10k |
| **Zsh plugins** | zsh-autosuggestions, fast-syntax-highlighting, zsh-autocomplete |
| **File tools** | `bat` (cat), `eza` (ls), `ripgrep` (grep), `fzf` (fuzzy finder) |
| **Dev tools** | `git`, `git-lfs`, `tmux`, `atuin`, `zoxide`, `starship` |
| **Network** | `pstree`, `mtr` |
| **Node** | Volta (version manager) + pnpm |
| **Font** | MesloLGS Nerd Font |
| **Optional** | PostgreSQL@17 |

---

## 🚀 Quick start

```bash
git clone https://github.com/sharzilnafis/dotfiles.git ~/repos/dotfiles
cd ~/repos/dotfiles
chmod +x install.sh
./install.sh
```

> **Idempotent** — safe to run multiple times. Already-installed tools are detected and skipped.

---

## 📁 Repository layout

```
dotfiles/
├── install.sh          ← Main bootstrap script
├── configs/
│   ├── zshenv          → ~/.zshenv   (all shells — Volta, Rust env)
│   ├── zprofile        → ~/.zprofile (login shells — Homebrew, local bin)
│   └── zshrc           → ~/.zshrc   (interactive shells — OMZ, plugins, aliases)
└── README.md
```

---

## 🔧 Shell config architecture

Understanding the loading order avoids common "why isn't X on my PATH?" issues:

```
Every zsh instance:
  └─ .zshenv         ← Always sourced (keep minimal!)

Login shells additionally:
  └─ .zprofile       ← After .zshenv (Homebrew init goes here)

Interactive shells additionally:
  └─ .zshrc          ← After .zprofile (OMZ, aliases, plugins)
```

### `.zshenv`
- Sourced for **every** zsh process (login, interactive, scripts, cron)
- Only contains: **Volta** PATH, **Rust** toolchain
- Intentionally minimal to avoid side effects in non-interactive scripts

### `.zprofile`
- Sourced for **login** shells (terminal open, SSH)
- Contains: **Homebrew** `shellenv`, `~/.local/bin` PATH
- Runs before `.zshrc`

### `.zshrc`
- Sourced for **interactive** shells only
- Contains: Oh-My-Zsh, Powerlevel10k, all plugins, aliases, PATH expansions

---

## 🎨 After installation

### 1. Set your terminal font

Change your terminal font to **MesloLGS NF** for Powerlevel10k icons:

- **iTerm2**: `Preferences → Profiles → Text → Font`
- **Terminal.app**: `Preferences → Profiles → Font`
- **VS Code**: add to `settings.json`:
  ```json
  "terminal.integrated.fontFamily": "MesloLGS NF"
  ```
- **Ghostty**: add to config:
  ```
  font-family = MesloLGS NF
  ```

### 2. Configure your prompt

```bash
p10k configure
```

Follow the wizard to choose your Powerlevel10k style.

### 3. Install Node

```bash
volta install node        # Install LTS
volta install node@20     # Or a specific version
```

### 4. Reload your shell

```bash
source ~/.zshrc
# or simply open a new terminal tab
```

---

## 🔁 Updating dotfiles

```bash
cd ~/repos/dotfiles
git pull
./install.sh   # Idempotent — re-runs safely
```

---

## 💾 Backups

Before overwriting any existing config files, the installer creates a timestamped backup:

```
~/.dotfiles_backup_YYYYMMDD_HHMMSS/
  ├── .zshenv.bak
  ├── .zprofile.bak
  └── .zshrc.bak
```

---

## 📦 Key aliases & functions

| Alias/Function | Behaviour |
|---|---|
| `reload` | `source ~/.zshrc` |
| `pip` / `pip3` | `python3 -m pip` |
| `python` | Uses `.venv` python if active, else `python3` |
| `cd <dir>` | Auto-activates `.venv` if found in target directory |

---

## 🐛 Troubleshooting

**Prompt icons look broken / show boxes**
→ Set your terminal font to **MesloLGS NF** (see above).

**`brew: command not found` after install**
→ The Homebrew `shellenv` is in `.zprofile` — open a new login shell tab.

**`volta: command not found`**
→ Volta is configured in `.zshenv`. Run `source ~/.zshenv` or open a new tab.

**P10k instant prompt warning about console output**
→ Move any `echo` or `print` statements in your `.zshrc` to after the OMZ source line.

**zsh-autocomplete is too aggressive**
→ Add to `.zshrc` after `source $ZSH/oh-my-zsh.sh`:
```zsh
zstyle ':autocomplete:*' min-input 2
```

---

## 📄 License

MIT — use freely, fork freely.
