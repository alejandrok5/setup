#!/usr/bin/env bash
#
# install-server.sh — bootstrap the CONSOLE stack on a fresh Ubuntu Server box.
#
#   ./install-server.sh [flavor]      # latte | frappe | macchiato | mocha (default: macchiato)
#
# Headless sibling of the desktop install.sh: no i3/X11/GUI — just the themed
# terminal/TUI tools that work over SSH. In order:
#   1.  apt packages          (zsh, tmux, btop, build/dev deps — needs sudo)
#   2.  oh-my-zsh
#   3.  starship               (prompt -> ~/.local/bin)
#   4.  mise + ruby            (.zshrc activates mise; ruby for ruby-lsp)
#   5.  Neovim                 (recent build -> ~/.local; Ubuntu's apt nvim is too old for LazyVim)
#   6.  yazi + ya              (file manager -> ~/.local/bin; no image preview over SSH)
#   7.  lazygit                (-> ~/.local/bin)
#   8.  lazydocker             (-> ~/.local/bin)
#   9.  Docker Engine          (get.docker.com + adds you to the docker group — sudo)
#   10. place dotfiles         (~/.zshrc ~/.profile ~/.gitconfig)
#   11. apply-theme.sh         (themes zsh/starship/btop/yazi/lazygit/lazydocker/nvim + seeds tmux)
#   12. default shell -> zsh   (chsh)
#
# No Nerd Font is installed here: on a headless box the raw TTY uses kernel console
# fonts, and over SSH the glyphs are rendered by YOUR client terminal's font — so
# set your local terminal to a Nerd Font (e.g. MesloLGS Nerd Font Mono) instead.
#
# Large files are fetched with wget; the official install one-liners (oh-my-zsh,
# starship, mise, Docker) use their documented curl|sh form. Idempotent and safe
# to re-run; existing files are backed up to .bak; optional/network steps are
# non-fatal. Toggle Docker with: INSTALL_DOCKER=0 ./install-server.sh

set -uo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAVOR="${1:-macchiato}"
case "$FLAVOR" in latte|frappe|macchiato|mocha) ;; *)
  echo "error: unknown flavor '$FLAVOR' (latte | frappe | macchiato | mocha)" >&2; exit 1 ;;
esac

log()  { printf '\n\033[1;35m>> %s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
warn() { printf '   \033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
backup() { [ -e "$1" ] && cp -f "$1" "$1.bak" 2>/dev/null || true; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if have sudo; then SUDO="sudo"; else warn "not root and no sudo — system steps will be skipped."; fi
fi

export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME/.local/bin" "$HOME/.config"

if ! grep -qiE 'ubuntu|debian' /etc/os-release 2>/dev/null; then
  warn "this doesn't look like Ubuntu/Debian — apt steps may fail. Continuing anyway."
fi

ARCH="$(uname -m)"   # expect x86_64; warn otherwise (release asset names are amd64)
[ "$ARCH" = x86_64 ] || warn "arch is $ARCH, not x86_64 — the prebuilt binary URLs may not match."

# ==========================================================================
# 1. apt packages
# ==========================================================================
APT_PACKAGES=(
  curl wget git unzip ca-certificates gnupg build-essential
  zsh zsh-syntax-highlighting
  tmux btop
  libpq-dev                         # ruby-lsp native gem (pg) build header
  ffmpegthumbnailer poppler-utils chafa fd-find ripgrep jq p7zip-full   # yazi helpers
)
log "Installing apt packages (${#APT_PACKAGES[@]})"
if [ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ]; then
  $SUDO apt-get update -y \
    && $SUDO apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}" \
    && info "apt packages installed" \
    || warn "apt install hit an error — check output above; continuing"
else
  warn "skipping apt step (no root). Install manually: ${APT_PACKAGES[*]}"
fi

# ==========================================================================
# 2. oh-my-zsh
# ==========================================================================
log "Installing oh-my-zsh"
if [ -d "$HOME/.oh-my-zsh" ]; then
  info "oh-my-zsh already present"
elif have curl; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended --keep-zshrc \
    && info "oh-my-zsh installed" \
    || warn "oh-my-zsh install failed (offline?) — install it before first zsh login"
else
  warn "need curl for oh-my-zsh"
fi

# ==========================================================================
# 3. starship
# ==========================================================================
log "Installing starship"
if have starship; then
  info "starship already present: $(command -v starship)"
elif have curl; then
  curl -fsSL https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin" -y \
    && info "starship installed -> ~/.local/bin/starship" \
    || warn "starship install failed (offline?)"
else
  warn "need curl for starship"
fi

# ==========================================================================
# 4. mise + ruby
# ==========================================================================
log "Installing mise (runtime manager) + ruby"
if have mise; then
  info "mise already present: $(command -v mise)"
elif have curl; then
  curl -fsSL https://mise.run | sh \
    && info "mise installed -> ~/.local/bin/mise" \
    || warn "mise install failed (offline?) — .zshrc activates it, so install before first login"
fi
if have mise; then
  mise use -g ruby@latest >/dev/null 2>&1 \
    && info "mise: ruby@latest pinned globally (for ruby-lsp)" \
    || warn "could not install ruby via mise — do it later: mise use -g ruby@latest"
fi

# ==========================================================================
# 5. Neovim  (recent build to ~/.local — Ubuntu's apt nvim is too old for LazyVim)
# ==========================================================================
log "Installing Neovim (recent)"
if have nvim && nvim --version 2>/dev/null | head -1 | grep -qE 'v0\.(1[1-9]|[2-9][0-9])'; then
  info "recent nvim already present: $(nvim --version | head -1)"
elif have wget; then
  tmp="$(mktemp -d)"
  got=""
  for asset in nvim-linux-x86_64.tar.gz nvim-linux64.tar.gz; do
    if wget -qO "$tmp/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/$asset"; then
      got=1; break
    fi
  done
  if [ -n "$got" ]; then
    dir="$(tar -tzf "$tmp/nvim.tar.gz" 2>/dev/null | head -1 | cut -d/ -f1)"
    tar -C "$HOME/.local" -xzf "$tmp/nvim.tar.gz" \
      && ln -sf "$HOME/.local/$dir/bin/nvim" "$HOME/.local/bin/nvim" \
      && info "installed $("$HOME/.local/bin/nvim" --version | head -1) -> ~/.local/$dir" \
      || warn "could not unpack nvim"
  else
    warn "could not download nvim release — falling back to apt (may be too old for LazyVim)"
    [ -n "$SUDO" ] && $SUDO apt-get install -y neovim >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp"
else
  warn "need wget for the nvim download"
fi

# ==========================================================================
# 6. yazi + ya   (no image preview over SSH; chafa gives ASCII fallback)
# ==========================================================================
log "Installing yazi"
if have yazi; then
  info "yazi already present: $(command -v yazi)"
elif have wget && have unzip; then
  tmp="$(mktemp -d)"
  if wget -qO "$tmp/yazi.zip" \
      https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip; then
    unzip -j -oq "$tmp/yazi.zip" '*/yazi' '*/ya' -d "$HOME/.local/bin"
    chmod +x "$HOME/.local/bin/yazi" "$HOME/.local/bin/ya" 2>/dev/null || true
    info "installed yazi + ya -> ~/.local/bin"
  else
    warn "could not download yazi (offline?)"
  fi
  rm -rf "$tmp"
else
  warn "need wget + unzip for yazi"
fi

# ==========================================================================
# 7/8. lazygit + lazydocker   (prebuilt release binaries -> ~/.local/bin)
# ==========================================================================
install_lazy() { # <name> <repo> <binary-in-tarball>
  local name="$1" repo="$2" bin="$3"
  if have "$name"; then info "$name already present: $(command -v "$name")"; return; fi
  have wget || { warn "need wget for $name"; return; }
  local ver tmp
  ver="$(wget -qO- "https://api.github.com/repos/$repo/releases/latest" \
        | grep -Po '"tag_name":\s*"v?\K[^"]*' | head -1)"
  if [ -z "$ver" ]; then warn "could not resolve latest $name version (rate-limited/offline?)"; return; fi
  tmp="$(mktemp -d)"
  if wget -qO "$tmp/$name.tar.gz" \
      "https://github.com/$repo/releases/download/v${ver}/${name}_${ver}_Linux_x86_64.tar.gz"; then
    tar -xzf "$tmp/$name.tar.gz" -C "$tmp" "$bin" 2>/dev/null \
      && install -m755 "$tmp/$bin" "$HOME/.local/bin/$name" \
      && info "installed $name v$ver -> ~/.local/bin/$name" \
      || warn "could not unpack $name"
  else
    warn "could not download $name v$ver"
  fi
  rm -rf "$tmp"
}
log "Installing lazygit"
install_lazy lazygit jesseduffield/lazygit lazygit
log "Installing lazydocker"
install_lazy lazydocker jesseduffield/lazydocker lazydocker

# ==========================================================================
# 9. Docker Engine  (so lazydocker has something to talk to)
# ==========================================================================
log "Installing Docker Engine"
if have docker; then
  info "docker already present: $(docker --version 2>/dev/null)"
elif [ "${INSTALL_DOCKER:-1}" = 0 ]; then
  info "skipped (INSTALL_DOCKER=0)"
elif [ -n "$SUDO" ] && have curl; then
  tmp="$(mktemp -d)"
  if curl -fsSL https://get.docker.com -o "$tmp/get-docker.sh" && $SUDO sh "$tmp/get-docker.sh"; then
    $SUDO usermod -aG docker "$USER" 2>/dev/null \
      && info "added $USER to the docker group (log out/in for it to take effect)"
    info "docker installed: $(docker --version 2>/dev/null)"
  else
    warn "Docker install failed — install it yourself; lazydocker connects once Docker is up"
  fi
  rm -rf "$tmp"
else
  info "skipped (needs sudo + curl) — install Docker yourself for lazydocker"
fi

# ==========================================================================
# 10. Place the dotfiles  (console subset — no X11 files)
# ==========================================================================
log "Placing dotfiles into ~"
put() {
  local src="$SETUP_DIR/$1" dest="$2"
  if [ ! -e "$src" ]; then warn "missing in repo: $1"; return; fi
  mkdir -p "$(dirname "$dest")"
  backup "$dest"
  cp -f "$src" "$dest"
  info "$1 -> ${dest/#$HOME/\~}"
}
put home/.zshrc    "$HOME/.zshrc"
put home/.profile  "$HOME/.profile"
put home/.gitconfig "$HOME/.gitconfig"

# ==========================================================================
# 11. Theme everything (+ seed tmux/nvim)
# ==========================================================================
log "Theming the console stack with apply-theme.sh ($FLAVOR)"
"$SETUP_DIR/apply-theme.sh" "$FLAVOR" || warn "apply-theme.sh reported an issue — see output above"

# ==========================================================================
# 12. Default shell -> zsh
# ==========================================================================
log "Setting zsh as the default shell"
ZSH_BIN="$(command -v zsh || true)"
if [ -n "$ZSH_BIN" ] && [ "${SHELL:-}" != "$ZSH_BIN" ]; then
  chsh -s "$ZSH_BIN" 2>/dev/null \
    && info "default shell set to $ZSH_BIN (log out/in to take effect)" \
    || warn "chsh failed — run it yourself: chsh -s $ZSH_BIN"
else
  info "zsh already the default shell (or zsh not installed)"
fi

cat <<EOF

$(printf '\033[1;32m✓ server install complete (flavor: %s)\033[0m' "$FLAVOR")

Next steps:
  • Open a NEW SSH session (or 'exec zsh') so the new shell, mise, starship and
    the syntax-highlighting take effect.
  • In tmux, press prefix (C-a) + I once to finish installing the plugins (TPM).
  • Launch nvim once so lazy.nvim installs LazyVim + catppuccin.
  • If you installed Docker, log out/in so your 'docker' group membership applies
    (then 'docker ps' works without sudo and lazydocker connects).
  • Set YOUR SSH CLIENT's terminal to a Nerd Font — that's what renders the
    starship/tmux/lazygit glyphs over SSH.
  • Switch flavor anytime:  ./apply-theme.sh mocha

See README.md for the per-tool notes.
EOF
