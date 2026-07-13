#!/usr/bin/env bash
# =============================================================================
#  dotfiles/install.sh — Cross-platform terminal bootstrap
#  Supports: macOS (Apple Silicon + Intel), Ubuntu/Debian, Fedora/RHEL, Arch
#
#  Usage:
#    chmod +x install.sh && ./install.sh
#
#  Idempotent: safe to run multiple times. Already-installed tools are skipped.
# =============================================================================

set -euo pipefail

# ── CONSTANTS ─────────────────────────────────────────────────────────────────
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$DOTFILES_DIR/configs"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
OMZ_DIR="$HOME/.oh-my-zsh"
OMZ_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

# ── COLORS ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── LOGGING ───────────────────────────────────────────────────────────────────
log_step()  { echo -e "\n${BLUE}${BOLD}──▶ $*${RESET}"; }
log_ok()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
log_warn()  { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
log_error() { echo -e "  ${RED}✗${RESET}  $*" >&2; }
log_info()  { echo -e "  ${CYAN}→${RESET}  $*"; }
log_skip()  { echo -e "  ${YELLOW}↷${RESET}  $* (already installed, skipping)"; }

# ── HEADER ────────────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${BOLD}${CYAN}"
  cat <<'EOF'
  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
EOF
  echo -e "${RESET}"
  echo -e "  ${BOLD}Cross-platform terminal bootstrap — by sharzilnafis${RESET}"
  echo -e "  ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
  echo ""
}

# ── OS DETECTION ──────────────────────────────────────────────────────────────
detect_os() {
  OS=""
  ARCH=""
  PKG_MANAGER=""

  ARCH="$(uname -m)"

  case "$(uname -s)" in
    Darwin)
      OS="macos"
      if [[ "$ARCH" == "arm64" ]]; then
        OS_LABEL="macOS (Apple Silicon)"
      else
        OS_LABEL="macOS (Intel)"
      fi
      ;;
    Linux)
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        case "$ID" in
          ubuntu|debian|linuxmint|pop)
            OS="debian"
            OS_LABEL="Ubuntu/Debian"
            PKG_MANAGER="apt"
            ;;
          fedora|rhel|centos|rocky|almalinux)
            OS="fedora"
            OS_LABEL="Fedora/RHEL"
            PKG_MANAGER="dnf"
            ;;
          arch|manjaro|endeavouros)
            OS="arch"
            OS_LABEL="Arch Linux"
            PKG_MANAGER="pacman"
            ;;
          *)
            OS="linux"
            OS_LABEL="Linux ($ID)"
            PKG_MANAGER="apt"
            log_warn "Unknown Linux distro: $ID — falling back to apt"
            ;;
        esac
      else
        OS="linux"
        OS_LABEL="Linux (unknown)"
        log_warn "Cannot read /etc/os-release — assuming Debian-like"
        PKG_MANAGER="apt"
      fi
      ;;
    *)
      log_error "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac

  log_info "Detected OS : ${BOLD}$OS_LABEL${RESET}"
  log_info "Architecture: ${BOLD}$ARCH${RESET}"
}

# ── HELPERS ───────────────────────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

# Prompt yes/no, default yes
confirm() {
  local prompt="${1:-Continue?}"
  local default="${2:-y}"
  local yn
  if [[ "$default" == "y" ]]; then
    read -r -p "  ${CYAN}?${RESET}  $prompt [Y/n]: " yn
    yn="${yn:-y}"
  else
    read -r -p "  ${CYAN}?${RESET}  $prompt [y/N]: " yn
    yn="${yn:-n}"
  fi
  [[ "$yn" =~ ^[Yy]$ ]]
}

# Back up a file if it exists, then symlink or copy
backup_and_copy() {
  local src="$1"
  local dest="$2"

  if [[ -f "$dest" || -L "$dest" ]]; then
    mkdir -p "$BACKUP_DIR"
    local bak_name
    bak_name="$(basename "$dest").bak"
    cp -P "$dest" "$BACKUP_DIR/$bak_name" 2>/dev/null || true
    log_info "Backed up $dest → $BACKUP_DIR/$bak_name"
  fi

  cp "$src" "$dest"
  log_ok "Installed $(basename "$dest") → $dest"
}

# Install a brew package if not already installed
brew_install() {
  local pkg="$1"
  if brew list --formula "$pkg" &>/dev/null 2>&1; then
    log_skip "brew: $pkg"
  else
    log_info "brew install $pkg …"
    brew install "$pkg"
    log_ok "Installed: $pkg"
  fi
}

# Install a brew cask if not already installed
brew_cask_install() {
  local cask="$1"
  if brew list --cask "$cask" &>/dev/null 2>&1; then
    log_skip "brew cask: $cask"
  else
    log_info "brew install --cask $cask …"
    brew install --cask "$cask"
    log_ok "Installed cask: $cask"
  fi
}

# Clone a git repo only if the target directory doesn't exist
git_clone_if_missing() {
  local repo="$1"
  local dest="$2"
  local label="${3:-$repo}"
  if [[ -d "$dest" ]]; then
    log_skip "$label"
  else
    log_info "Cloning $label …"
    git clone --depth=1 "$repo" "$dest"
    log_ok "Cloned: $label"
  fi
}

# ── 1. SYSTEM PACKAGES ────────────────────────────────────────────────────────
install_system_packages() {
  log_step "System packages"

  if [[ "$OS" == "macos" ]]; then
    # Ensure Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
      log_info "Installing Xcode Command Line Tools …"
      xcode-select --install || true
      log_warn "Re-run this script after Xcode CLT installation completes."
      exit 0
    else
      log_skip "Xcode Command Line Tools"
    fi

  elif [[ "$OS" == "debian" ]]; then
    log_info "Updating apt package lists …"
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
      curl wget git zsh build-essential procps file \
      ca-certificates gnupg lsb-release
    log_ok "Core system packages installed"

  elif [[ "$OS" == "fedora" ]]; then
    log_info "Installing core packages via dnf …"
    sudo dnf install -y -q \
      curl wget git zsh gcc gcc-c++ make procps-ng \
      ca-certificates gnupg2
    log_ok "Core system packages installed"

  elif [[ "$OS" == "arch" ]]; then
    log_info "Syncing pacman and installing core packages …"
    sudo pacman -Sy --noconfirm --needed \
      curl wget git zsh base-devel procps-ng ca-certificates
    log_ok "Core system packages installed"
  fi
}

# ── 2. HOMEBREW ───────────────────────────────────────────────────────────────
install_homebrew() {
  log_step "Homebrew"

  if command_exists brew; then
    log_skip "Homebrew"
    return
  fi

  log_info "Installing Homebrew …"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Activate brew in current session
  if [[ "$OS" == "macos" ]]; then
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  elif [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  log_ok "Homebrew installed"
}

# ── 3. ZSH ────────────────────────────────────────────────────────────────────
install_zsh() {
  log_step "Zsh"

  if command_exists zsh; then
    log_skip "zsh ($(zsh --version | head -1))"
  else
    log_info "Installing zsh …"
    case "$PKG_MANAGER" in
      apt)    sudo apt-get install -y zsh ;;
      dnf)    sudo dnf install -y zsh ;;
      pacman) sudo pacman -S --noconfirm zsh ;;
    esac
    log_ok "zsh installed"
  fi

  # Set zsh as default shell
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "$SHELL" == "$zsh_path" ]]; then
    log_skip "Default shell (already zsh)"
  else
    log_info "Setting zsh as default shell …"
    # Ensure zsh is in /etc/shells
    if ! grep -qF "$zsh_path" /etc/shells; then
      echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
      log_info "Added $zsh_path to /etc/shells"
    fi
    chsh -s "$zsh_path"
    log_ok "Default shell set to zsh (takes effect on next login)"
  fi
}

# ── 4. OH-MY-ZSH ─────────────────────────────────────────────────────────────
install_oh_my_zsh() {
  log_step "Oh-My-Zsh"

  if [[ -d "$OMZ_DIR" ]]; then
    log_skip "Oh-My-Zsh"
    return
  fi

  log_info "Installing Oh-My-Zsh (unattended) …"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  log_ok "Oh-My-Zsh installed at $OMZ_DIR"
}

# ── 5. POWERLEVEL10K ─────────────────────────────────────────────────────────
install_powerlevel10k() {
  log_step "Powerlevel10k theme"

  git_clone_if_missing \
    "https://github.com/romkatv/powerlevel10k.git" \
    "${OMZ_CUSTOM}/themes/powerlevel10k" \
    "powerlevel10k"
}

# ── 6. ZSH PLUGINS ───────────────────────────────────────────────────────────
install_zsh_plugins() {
  log_step "Zsh plugins"

  git_clone_if_missing \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "${OMZ_CUSTOM}/plugins/zsh-autosuggestions" \
    "zsh-autosuggestions"

  git_clone_if_missing \
    "https://github.com/zdharma-continuum/fast-syntax-highlighting" \
    "${OMZ_CUSTOM}/plugins/fast-syntax-highlighting" \
    "fast-syntax-highlighting"

  git_clone_if_missing \
    "https://github.com/marlonrichert/zsh-autocomplete" \
    "${OMZ_CUSTOM}/plugins/zsh-autocomplete" \
    "zsh-autocomplete"
}

# ── 7. BREW CLI TOOLS ─────────────────────────────────────────────────────────
install_brew_tools() {
  log_step "Homebrew CLI tools"

  local tools=(
    bat          # Better cat
    eza          # Better ls
    fzf          # Fuzzy finder
    starship     # Cross-shell prompt (optional alternative to p10k)
    atuin        # Shell history with search
    zoxide       # Smarter cd
    ripgrep      # Better grep
    tmux         # Terminal multiplexer
    git          # Version control
    git-lfs      # Git large file storage
    pstree       # Process tree viewer
    mtr          # Network diagnostic tool
  )

  for tool in "${tools[@]}"; do
    brew_install "$tool"
  done
}

# ── 8. POSTGRESQL (OPTIONAL) ─────────────────────────────────────────────────
install_postgresql() {
  log_step "PostgreSQL@17 (optional)"

  if brew list --formula postgresql@17 &>/dev/null 2>&1; then
    log_skip "postgresql@17"
    return
  fi

  if confirm "Install PostgreSQL@17 via Homebrew?" "n"; then
    log_info "Installing postgresql@17 …"
    brew install postgresql@17
    log_ok "PostgreSQL@17 installed"
    log_info "To start: brew services start postgresql@17"
  else
    log_info "Skipping PostgreSQL@17"
  fi
}

# ── 9. NERD FONT ─────────────────────────────────────────────────────────────
install_nerd_font() {
  log_step "Nerd Font (MesloLGS NF)"

  if [[ "$OS" == "macos" ]]; then
    # Check if already installed
    if fc-list 2>/dev/null | grep -qi "MesloLGS" || \
       ls ~/Library/Fonts/MesloLGS* &>/dev/null 2>&1; then
      log_skip "MesloLGS NF (already in ~/Library/Fonts)"
      return
    fi

    log_info "Installing font-meslo-lg-nerd-font via Homebrew …"
    brew tap homebrew/cask-fonts 2>/dev/null || true
    brew_cask_install "font-meslo-lg-nerd-font"

  elif [[ "$OS" == "debian" || "$OS" == "fedora" || "$OS" == "arch" ]]; then
    local font_dir="$HOME/.local/share/fonts"
    if ls "$font_dir"/MesloLGS* &>/dev/null 2>&1; then
      log_skip "MesloLGS NF (already in $font_dir)"
      return
    fi

    log_info "Downloading MesloLGS Nerd Font to $font_dir …"
    mkdir -p "$font_dir"

    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local fonts=(
      "MesloLGS%20NF%20Regular.ttf"
      "MesloLGS%20NF%20Bold.ttf"
      "MesloLGS%20NF%20Italic.ttf"
      "MesloLGS%20NF%20Bold%20Italic.ttf"
    )

    for font in "${fonts[@]}"; do
      local fname="${font//%20/ }"
      if [[ ! -f "$font_dir/$fname" ]]; then
        curl -fsSL "$base_url/$font" -o "$font_dir/$fname"
      fi
    done

    fc-cache -f "$font_dir"
    log_ok "MesloLGS Nerd Font installed and font cache refreshed"
  fi
}

# ── 10. VOLTA (NODE VERSION MANAGER) ─────────────────────────────────────────
install_volta() {
  log_step "Volta (Node version manager)"

  if command_exists volta || [[ -d "$HOME/.volta/bin" ]]; then
    log_skip "Volta"
    return
  fi

  log_info "Installing Volta …"
  curl -fsSL https://get.volta.sh | bash -s -- --skip-setup
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
  log_ok "Volta installed"
}

# ── 11. PNPM VIA VOLTA ───────────────────────────────────────────────────────
install_pnpm() {
  log_step "pnpm (via Volta)"

  # Reload Volta into current session
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"

  if command_exists pnpm; then
    log_skip "pnpm ($(pnpm --version))"
    return
  fi

  if command_exists volta; then
    log_info "Installing pnpm via Volta …"
    volta install pnpm
    log_ok "pnpm installed via Volta"
  else
    log_warn "Volta not found in PATH — skipping pnpm install"
    log_info "After restarting your shell, run: volta install pnpm"
  fi
}

# ── 12. DOTFILES ─────────────────────────────────────────────────────────────
install_dotfiles() {
  log_step "Dotfiles"

  local config_files=(
    "zshenv:.zshenv"
    "zprofile:.zprofile"
    "zshrc:.zshrc"
  )

  local any_existing=false
  for pair in "${config_files[@]}"; do
    local dest_name="${pair#*:}"
    if [[ -f "$HOME/$dest_name" || -L "$HOME/$dest_name" ]]; then
      any_existing=true
      break
    fi
  done

  if [[ "$any_existing" == true ]]; then
    log_warn "Existing dotfiles detected. They will be backed up to: $BACKUP_DIR"
    if ! confirm "Back up and overwrite existing dotfiles?"; then
      log_info "Skipping dotfiles installation"
      return
    fi
  fi

  for pair in "${config_files[@]}"; do
    local src_name="${pair%%:*}"
    local dest_name="${pair#*:}"
    local src="$CONFIGS_DIR/$src_name"
    local dest="$HOME/$dest_name"

    if [[ -f "$src" ]]; then
      backup_and_copy "$src" "$dest"
    else
      log_warn "Config not found: $src — skipping"
    fi
  done

  log_ok "Dotfiles installed"
  if [[ -d "$BACKUP_DIR" ]]; then
    log_info "Backups stored in: $BACKUP_DIR"
  fi
}

# ── 13. SUMMARY ───────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}┌─────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${GREEN}│                  ✓  SETUP COMPLETE                          │${RESET}"
  echo -e "${BOLD}${GREEN}└─────────────────────────────────────────────────────────────┘${RESET}"
  echo ""

  echo -e "${BOLD}Installed / verified:${RESET}"
  for tool in zsh brew git volta pnpm bat eza fzf ripgrep tmux atuin zoxide; do
    if command_exists "$tool"; then
      echo -e "  ${GREEN}✓${RESET} $tool"
    else
      echo -e "  ${YELLOW}–${RESET} $tool (not in current PATH — may need shell restart)"
    fi
  done

  echo ""
  echo -e "${BOLD}${CYAN}Next steps:${RESET}"
  echo -e "  ${CYAN}1.${RESET} ${BOLD}Restart your terminal${RESET} (or open a new tab)"
  echo -e "  ${CYAN}2.${RESET} Change your terminal font to ${BOLD}MesloLGS NF${RESET}"
  echo -e "     • iTerm2: Preferences → Profiles → Text → Font"
  echo -e "     • Terminal.app: Preferences → Profiles → Font"
  echo -e "     • VS Code: set ${BOLD}\"terminal.integrated.fontFamily\": \"MesloLGS NF\"${RESET}"
  echo -e "  ${CYAN}3.${RESET} Run ${BOLD}p10k configure${RESET} to customize your prompt"
  echo -e "  ${CYAN}4.${RESET} Install Node LTS: ${BOLD}volta install node${RESET}"
  echo -e "  ${CYAN}5.${RESET} Reload shell config: ${BOLD}source ~/.zshrc${RESET}"
  echo ""
  echo -e "${CYAN}Dotfiles repo: ${BOLD}$DOTFILES_DIR${RESET}"
  if [[ -d "$BACKUP_DIR" ]]; then
    echo -e "${CYAN}Backups:       ${BOLD}$BACKUP_DIR${RESET}"
  fi
  echo ""
}

# ── MAIN ─────────────────────────────────────────────────────────────────────
main() {
  print_banner
  detect_os

  echo ""
  log_info "Dotfiles source: $DOTFILES_DIR"
  echo ""

  if ! confirm "Begin installation?" "y"; then
    log_info "Aborted."
    exit 0
  fi

  install_system_packages
  install_homebrew
  install_zsh
  install_oh_my_zsh
  install_powerlevel10k
  install_zsh_plugins
  install_brew_tools
  install_postgresql
  install_nerd_font
  install_volta
  install_pnpm
  install_dotfiles

  print_summary
}

main "$@"
