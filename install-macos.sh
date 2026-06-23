#!/usr/bin/env bash
#
# install-macos.sh — bootstrap the macOS console + AeroSpace desktop.
#
#   ./install-macos.sh [flavor]    # latte | frappe | macchiato | mocha (default: macchiato)
#
# macOS sibling of the i3 install.sh. Everything goes through Homebrew; then it
# places the dotfiles, themes the console stack + mauve borders, and starts
# AeroSpace/borders. In order:
#   0. BACK UP existing config  (snapshot -> ~/.setup-backup-<timestamp>/ + rollback.sh)
#   1. Homebrew                 (installed if absent)
#   2. brew bundle              (Brewfile: aerospace, alacritty, stats, font, TUI stack)
#   3. ~/.zprofile brew PATH    (so zsh login shells see /opt/homebrew tools)
#   4. oh-my-zsh
#   5. mise + ruby
#   6. place dotfiles           (~/.zshrc ~/.gitconfig, aerospace.toml, alacritty config)
#   7. apply-theme.sh           (zsh/starship/btop/yazi/lazygit/lazydocker/borders/nvim + tmux)
#   8. start services           (borders; launch AeroSpace + Stats)
#   9. default login shell      (zsh — already the macOS default)
#
# SAFE ON A POPULATED MAC: step 0 snapshots everything this install touches into a
# timestamped backup dir BEFORE changing anything, and writes a rollback.sh there
# that restores your originals and removes whatever the install created. So you get
# the full themed result, fully reversible with one command. Re-runnable.
# The one thing it CANNOT do: grant AeroSpace the Accessibility permission — you
# click that once in System Settings.

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

[ "$(uname)" = Darwin ] || warn "this isn't macOS (uname=$(uname)) — use install.sh (desktop) or install-server.sh"

# ==========================================================================
# 0. Back up existing config  (rollback point)
# ==========================================================================
# Every path the install can create or overwrite — snapshotted BEFORE anything
# changes, so rollback.sh can restore originals and delete install-created files.
SNAPSHOT_PATHS=(
  .zshrc .zprofile .gitconfig .tmux.conf .zsh
  .config/aerospace .config/alacritty .config/starship.toml
  .config/btop .config/yazi .config/lazygit .config/lazydocker
  .config/borders .config/nvim
)
BACKUP_DIR="$HOME/.setup-backup-$(date +%Y%m%d-%H%M%S)"
log "Backing up existing config -> ${BACKUP_DIR/#$HOME/~}"
mkdir -p "$BACKUP_DIR"
for rel in "${SNAPSHOT_PATHS[@]}"; do
  if [ -e "$HOME/$rel" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$HOME/$rel" "$BACKUP_DIR/$rel"
    info "saved $rel"
  fi
done

# Write a self-contained rollback script next to the snapshot.
cat > "$BACKUP_DIR/rollback.sh" <<ROLLBACK
#!/usr/bin/env bash
# rollback.sh — undo the macOS setup install: restore the configs it replaced and
# remove the ones it created. Does NOT uninstall Homebrew packages or remove the
# cloned tmux/nvim plugins (those are harmless and shared).
set -uo pipefail
BACKUP_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PATHS=( ${SNAPSHOT_PATHS[*]} )
echo ">> Rolling back from \$BACKUP_DIR"
command -v brew >/dev/null 2>&1 && brew services stop borders >/dev/null 2>&1 || true
osascript -e 'quit app "AeroSpace"' >/dev/null 2>&1 || true
osascript -e 'quit app "Stats"' >/dev/null 2>&1 || true
for rel in "\${PATHS[@]}"; do
  if [ -e "\$BACKUP_DIR/\$rel" ]; then
    mkdir -p "\$HOME/\$(dirname "\$rel")"
    rm -rf "\$HOME/\$rel"
    cp -a "\$BACKUP_DIR/\$rel" "\$HOME/\$rel"
    echo "   restored \$rel"
  elif [ -e "\$HOME/\$rel" ]; then
    rm -rf "\$HOME/\$rel"
    echo "   removed  \$rel (created by the install)"
  fi
done
echo ">> Rollback complete. Open a new shell. (Homebrew packages were left installed.)"
ROLLBACK
chmod +x "$BACKUP_DIR/rollback.sh"
info "rollback script -> ${BACKUP_DIR/#$HOME/~}/rollback.sh"

# ==========================================================================
# 1. Homebrew
# ==========================================================================
log "Homebrew"
if ! have brew; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || warn "Homebrew install failed (see above)"
fi
# Load brew into THIS shell (Apple Silicon: /opt/homebrew, Intel: /usr/local).
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
have brew && info "brew: $(brew --version | head -1)" || { warn "brew not on PATH — install Homebrew, then re-run"; }

# ==========================================================================
# 2. Packages (brew bundle)
# ==========================================================================
log "Installing packages (brew bundle)"
if have brew; then
  brew bundle --file="$SETUP_DIR/Brewfile" || warn "brew bundle reported errors — check above; continuing"
else
  warn "skipping brew bundle (no brew)"
fi

# ==========================================================================
# 3. Homebrew on PATH for login shells (~/.zprofile)
# ==========================================================================
# On Apple Silicon /opt/homebrew/bin isn't on the default PATH — without this,
# new zsh sessions won't find starship/mise/etc. Loaded before ~/.zshrc.
log "Wiring Homebrew into ~/.zprofile"
if have brew; then
  if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    printf '\n# Homebrew on PATH for login shells (added by install-macos.sh)\neval "$(%s shellenv)"\n' \
      "$(command -v brew)" >> "$HOME/.zprofile"
    info "added 'brew shellenv' to ~/.zprofile"
  else
    info "~/.zprofile already loads brew"
  fi
fi

# ==========================================================================
# 4. oh-my-zsh
# ==========================================================================
log "oh-my-zsh"
if [ -d "$HOME/.oh-my-zsh" ]; then
  info "already present"
elif have curl; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended --keep-zshrc \
    && info "installed" || warn "oh-my-zsh install failed (offline?)"
fi

# ==========================================================================
# 5. mise + ruby
# ==========================================================================
log "mise + ruby"
if have mise; then
  mise use -g ruby@latest >/dev/null 2>&1 \
    && info "ruby@latest pinned (for ruby-lsp)" \
    || warn "mise ruby failed — do it later: mise use -g ruby@latest"
else
  warn "mise not found (Brewfile installs it) — skipping ruby"
fi

# ==========================================================================
# 6. Place dotfiles  (originals already snapshotted in step 0)
# ==========================================================================
log "Placing dotfiles"
put() {
  local s="$SETUP_DIR/$1" d="$2"
  [ -e "$s" ] || { warn "missing in repo: $1"; return; }
  mkdir -p "$(dirname "$d")"; cp -f "$s" "$d"
  info "$1 -> ${d/#$HOME/~}"
}
put home/.zshrc              "$HOME/.zshrc"
put home/.gitconfig          "$HOME/.gitconfig"
put aerospace/aerospace.toml "$HOME/.config/aerospace/aerospace.toml"
put alacritty/alacritty.toml "$HOME/.config/alacritty/alacritty.toml"
for f in frappe macchiato mocha; do
  put "alacritty/catppuccin-$f.toml" "$HOME/.config/alacritty/catppuccin-$f.toml"
done

# ==========================================================================
# 7. Theme everything (+ seed tmux/nvim, generate lazygit/lazydocker/borders)
# ==========================================================================
log "Theming ($FLAVOR)"
"$SETUP_DIR/apply-theme.sh" "$FLAVOR" || warn "apply-theme.sh reported an issue — see above"

# ==========================================================================
# 8. Start services
# ==========================================================================
log "Starting borders + AeroSpace"
if have borders; then
  brew services start borders >/dev/null 2>&1 && info "borders service started" \
    || warn "couldn't start borders service (run 'borders &' yourself)"
fi
open -a AeroSpace 2>/dev/null && info "launched AeroSpace (grant Accessibility — see below)" \
  || warn "couldn't launch AeroSpace — open it from /Applications once"
open -a Stats 2>/dev/null || true

# ==========================================================================
# 9. Default login shell -> zsh  (macOS default is already zsh)
# ==========================================================================
log "Login shell"
CURRENT="$(dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}')"
case "$CURRENT" in
  */zsh) info "login shell is already zsh ($CURRENT)" ;;
  *)
    if have sudo && sudo chsh -s /bin/zsh "$(id -un)" 2>/dev/null; then
      info "login shell set to /bin/zsh"
    else
      warn "set it yourself:  chsh -s /bin/zsh"
    fi ;;
esac

cat <<EOF

$(printf '\033[1;32m✓ macOS install complete (flavor: %s)\033[0m' "$FLAVOR")

Your previous config was saved to:  ${BACKUP_DIR/#$HOME/~}
Undo EVERYTHING this did (restores your originals, removes what it created) with:
  ${BACKUP_DIR/#$HOME/~}/rollback.sh
(rollback leaves Homebrew packages installed.)

REQUIRED manual step (macOS won't let a script do this):
  • Grant AeroSpace Accessibility access — System Settings → Privacy & Security →
    Accessibility → enable AeroSpace (it prompts on first launch). Tiling does
    nothing until you do.

Then:
  • Open a NEW terminal (or 'exec zsh') so brew, mise, starship and the
    syntax-highlighting load.
  • AeroSpace mod = Option (alt): alt-enter terminal · alt-1..0 workspaces ·
    alt-h/j/k/l focus · alt-shift-… move · alt-r resize · alt-shift-q close.
    App launcher is Spotlight (cmd-space).
  • tmux: prefix (C-a) + I once to install plugins (TPM).
  • Launch nvim once so lazy.nvim installs LazyVim + catppuccin.
  • lazydocker needs a Docker runtime you provide (colima / Docker Desktop / OrbStack).
  • Optional macOS toggles: natural scrolling + Dark mode in System Settings.
  • Switch flavor anytime:  ./apply-theme.sh mocha

See README.md for details.
EOF
