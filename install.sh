#!/usr/bin/env bash
#
# install.sh — bootstrap this entire i3 desktop on a fresh Debian box.
#
#   ./install.sh [flavor]      # flavor: latte | frappe | macchiato | mocha
#                              #         (default: macchiato) — passed to apply-theme.sh
#
# What it does, in order:
#   1.  apt packages            (the base WM + tools — needs sudo)
#   2.  Meslo Nerd Font         (downloaded; terminal/WM/icon font)
#   3.  oh-my-zsh               (the .zshrc this kit ships expects it)
#   4.  starship                (the prompt — installed to ~/.local/bin)
#   5.  mise + ruby             (runtime manager; .zshrc activates it; ruby for ruby-lsp)
#   6.  yazi + ya               (terminal file manager — prebuilt to ~/.local/bin)
#   7.  ueberzugpp              (OPTIONAL — image previews in Alacritty; .deb)
#   8.  Papirus icons + folders (icon theme used by rofi/GTK)
#   9.  i3lock-color            (OPTIONAL — the spinning-avatar lock; built from source)
#   10. Spotify                 (OPTIONAL — $mod+s; apt repo)
#   11. place the dotfiles      (COPY/SEED the hand-maintained layout into ~ and ~/.config)
#   12. xorg natural-scroll     (OPTIONAL — BT-mouse natural scroll; /etc/X11/... — sudo)
#   13. displays/install.sh     (hotplug/lid/rotate fallbacks)
#   14. apply-theme.sh          (themes everything + seeds tmux/nvim/dunst/starship)
#   15. default shell -> zsh    (chsh)
#
# This is the LAYOUT half of the kit; apply-theme.sh is the COLOR half. install.sh
# lays down the hand-maintained files (i3 config + scripts, polybar, rofi, alacritty,
# picom, the home dotfiles), then hands off to apply-theme.sh to generate the themed
# files (colors.conf, colors.ini, theme.toml, …) and seed tmux/nvim.
#
# Safe to re-run: every step is idempotent, every existing file is backed up to
# .bak before being overwritten, and the OPTIONAL/network steps are non-fatal —
# a failure there warns and keeps going rather than aborting the whole install.

set -uo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAVOR="${1:-macchiato}"
case "$FLAVOR" in latte|frappe|macchiato|mocha) ;; *)
  echo "error: unknown flavor '$FLAVOR' (latte | frappe | macchiato | mocha)" >&2; exit 1 ;;
esac

# --- pretty output --------------------------------------------------------
log()  { printf '\n\033[1;35m>> %s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
warn() { printf '   \033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
backup() { [ -e "$1" ] && cp -f "$1" "$1.bak" 2>/dev/null || true; }

# --- sudo handling: this script runs the privileged bits itself via $SUDO ---
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if have sudo; then SUDO="sudo"; else
    warn "not root and no sudo found — the apt/system steps will be skipped."
  fi
fi

export PATH="$HOME/.local/bin:$PATH"   # so freshly-installed user binaries are visible
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/fonts" "$HOME/.config"

if ! grep -qiE 'debian|ubuntu' /etc/os-release 2>/dev/null; then
  warn "this doesn't look like Debian/Ubuntu — apt steps may fail. Continuing anyway."
fi

# ==========================================================================
# 1. apt packages
# ==========================================================================
APT_PACKAGES=(
  # bootstrap helpers
  curl wget unzip git ca-certificates gnupg fontconfig
  # base desktop: WM, X, system monitor
  i3 xorg btop
  # media keys / OSD / notifications
  brightnessctl playerctl libnotify-bin dunst wireplumber
  # wallpaper, lock, compositor
  feh i3lock imagemagick picom
  # external monitors
  autorandr arandr
  # status bar + launcher
  polybar rofi
  # tray applets + audio + bluetooth
  network-manager-gnome blueman pavucontrol bluez
  # shell
  zsh zsh-syntax-highlighting
  # GTK portal (Brave/Chromium file dialogs)
  xdg-desktop-portal-gtk
  # tmux + clipboard
  tmux xclip
  # ruby-lsp native gem build deps (pg etc.)
  libpq-dev build-essential
  # icon theme (rofi/GTK)
  papirus-icon-theme
  # yazi optional richer previews
  ffmpegthumbnailer poppler-utils chafa fd-find ripgrep jq p7zip-full
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
# 2. Meslo Nerd Font
# ==========================================================================
log "Installing Meslo Nerd Font"
if fc-list 2>/dev/null | grep -qi 'MesloLGS Nerd Font'; then
  info "Meslo Nerd Font already present"
elif have wget && have unzip; then
  tmp="$(mktemp -d)"
  if wget -qO "$tmp/Meslo.zip" \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip; then
    unzip -oq "$tmp/Meslo.zip" -d "$HOME/.local/share/fonts/Meslo"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    info "installed Meslo Nerd Font -> ~/.local/share/fonts/Meslo"
  else
    warn "could not download Meslo.zip (offline?) — install the Nerd Font by hand"
  fi
  rm -rf "$tmp"
else
  warn "need wget + unzip for the font download"
fi

# ==========================================================================
# 3. oh-my-zsh  (the shipped .zshrc sources $ZSH/oh-my-zsh.sh)
# ==========================================================================
log "Installing oh-my-zsh"
if [ -d "$HOME/.oh-my-zsh" ]; then
  info "oh-my-zsh already present"
elif have curl; then
  # --keep-zshrc: do NOT clobber the .zshrc we place in step 11.
  # RUNZSH=no / CHSH=no: don't drop us into zsh or change the shell here.
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended --keep-zshrc \
    && info "oh-my-zsh installed" \
    || warn "oh-my-zsh install failed (offline?) — install it before first zsh login"
else
  warn "need curl for oh-my-zsh"
fi

# ==========================================================================
# 4. starship  (the prompt)
# ==========================================================================
log "Installing starship"
if have starship; then
  info "starship already present: $(command -v starship)"
elif have curl; then
  curl -fsSL https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin" -y \
    && info "starship installed -> ~/.local/bin/starship" \
    || warn "starship install failed (offline?) — install it for the prompt"
else
  warn "need curl for starship"
fi

# ==========================================================================
# 5. mise + ruby   (.zshrc runs `mise activate zsh`; ruby powers ruby-lsp)
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
# 6. yazi + ya   (terminal file manager — not in Debian repos)
# ==========================================================================
log "Installing yazi"
if have yazi; then
  info "yazi already present: $(command -v yazi)"
elif have curl && have unzip; then
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/yazi.zip" \
      https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip; then
    unzip -j -oq "$tmp/yazi.zip" '*/yazi' '*/ya' -d "$HOME/.local/bin"
    chmod +x "$HOME/.local/bin/yazi" "$HOME/.local/bin/ya" 2>/dev/null || true
    info "installed yazi + ya -> ~/.local/bin"
  else
    warn "could not download yazi (offline?) — install it by hand"
  fi
  rm -rf "$tmp"
else
  warn "need curl + unzip for yazi"
fi

# ==========================================================================
# 7. ueberzugpp  (OPTIONAL — yazi image previews in Alacritty)
# ==========================================================================
log "Installing ueberzugpp (optional — Alacritty image previews)"
if have ueberzugpp || have ueberzug; then
  info "ueberzugpp already present"
elif [ -n "$SUDO" ] && have curl; then
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/ueberzugpp.deb" \
      "https://download.opensuse.org/repositories/home:/justkidding/Debian_Unstable/amd64/ueberzugpp_2.9.10_amd64.deb"; then
    $SUDO apt-get install -y "$tmp/ueberzugpp.deb" \
      && info "ueberzugpp installed" \
      || warn "ueberzugpp .deb failed to install — previews show file info only"
  else
    warn "could not download ueberzugpp .deb — image previews will be text-only"
  fi
  rm -rf "$tmp"
else
  info "skipped (needs sudo + curl); yazi still works without image previews"
fi

# ==========================================================================
# 8. Papirus folder recolor  (icons are apt; recolor folders to violet/mauve)
# ==========================================================================
log "Recoloring Papirus folders (mauve/violet — optional)"
if have papirus-folders; then
  $SUDO papirus-folders -C violet --theme Papirus-Dark >/dev/null 2>&1 \
    && info "Papirus folders set to violet" || warn "papirus-folders run failed (non-fatal)"
elif have git && [ -n "$SUDO" ]; then
  tmp="$(mktemp -d)"
  if git clone --depth 1 -q https://github.com/PapirusDevelopmentTeam/papirus-folders "$tmp/pf"; then
    $SUDO install -m755 "$tmp/pf/papirus-folders" /usr/bin/papirus-folders 2>/dev/null || true
    $SUDO papirus-folders -C violet --theme Papirus-Dark >/dev/null 2>&1 \
      && info "installed papirus-folders + set violet" || warn "papirus-folders failed (non-fatal)"
  else
    warn "could not clone papirus-folders (non-fatal — folders stay default blue)"
  fi
  rm -rf "$tmp"
else
  info "skipped (needs git + sudo); icons still work, folders just stay default color"
fi

# ==========================================================================
# 9. i3lock-color  (OPTIONAL — the spinning-avatar lock screen)
# ==========================================================================
# lock.sh prefers ~/.local/bin/i3lock-color and falls back to plain i3lock (apt).
# i3lock-color is NOT in Debian, so build it from source. Heavy (build deps) and
# non-fatal — skip with INSTALL_I3LOCK_COLOR=0 to keep the plain-i3lock fallback.
log "Installing i3lock-color (optional — spinning-avatar lock)"
if have i3lock-color || [ -x "$HOME/.local/bin/i3lock-color" ]; then
  info "i3lock-color already present"
elif [ "${INSTALL_I3LOCK_COLOR:-1}" = 0 ]; then
  info "skipped (INSTALL_I3LOCK_COLOR=0) — lock.sh falls back to plain i3lock"
elif [ -n "$SUDO" ] && have git; then
  I3LC_DEPS=(autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev
             libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev
             libxcb-randr0-dev libxcb-image0-dev libxcb-util0-dev libxcb-xrm-dev libxkbcommon-dev
             libxkbcommon-x11-dev libjpeg-dev)
  if $SUDO apt-get install -y --no-install-recommends "${I3LC_DEPS[@]}"; then
    tmp="$(mktemp -d)"
    if git clone --depth 1 -q https://github.com/Raymo111/i3lock-color "$tmp/i3lc"; then
      ( cd "$tmp/i3lc" && ./build.sh >/dev/null 2>&1 \
          && install -m755 build/i3lock "$HOME/.local/bin/i3lock-color" ) \
        && info "built i3lock-color -> ~/.local/bin/i3lock-color" \
        || warn "i3lock-color build failed — lock.sh falls back to plain i3lock"
    else
      warn "could not clone i3lock-color (non-fatal — plain i3lock fallback)"
    fi
    rm -rf "$tmp"
  else
    warn "i3lock-color build deps failed to install — using plain i3lock"
  fi
else
  info "skipped (needs git + sudo) — lock.sh falls back to plain i3lock"
fi

# ==========================================================================
# 10. Spotify  (OPTIONAL — $mod+s)
# ==========================================================================
log "Installing Spotify (optional)"
if have spotify; then
  info "spotify already present"
elif [ "${INSTALL_SPOTIFY:-1}" = 0 ]; then
  info "skipped (INSTALL_SPOTIFY=0)"
elif [ -n "$SUDO" ] && have curl; then
  if curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg \
       | $SUDO gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg 2>/dev/null; then
    echo "deb https://repository.spotify.com stable non-free" \
      | $SUDO tee /etc/apt/sources.list.d/spotify.list >/dev/null
    $SUDO apt-get update -y >/dev/null 2>&1
    $SUDO apt-get install -y spotify-client \
      && info "spotify-client installed" || warn "spotify install failed (non-fatal)"
  else
    warn "could not add Spotify repo key (non-fatal)"
  fi
else
  info "skipped (needs sudo + curl)"
fi

# ==========================================================================
# 11. Place the dotfiles  (COPY/SEED — the hand-maintained layout)
# ==========================================================================
log "Placing config files into ~ and ~/.config"

# put <src-in-repo> <dest>  [executable]
put() {
  local src="$SETUP_DIR/$1" dest="$2"
  if [ ! -e "$src" ]; then warn "missing in repo: $1"; return; fi
  mkdir -p "$(dirname "$dest")"
  backup "$dest"
  cp -f "$src" "$dest"
  [ "${3:-}" = x ] && chmod +x "$dest"
  info "$1 -> ${dest/#$HOME/\~}"
}

# i3: layout + scripts + images  (rotate.sh comes from displays/install.sh)
put i3/config                       "$HOME/.config/i3/config"
for s in lock.sh osd.sh touchpad.sh wallpaper.sh spotify.sh make-lock-image.py ppm2png.py; do
  put "i3/scripts/$s"               "$HOME/.config/i3/scripts/$s" x
done
put i3/wallpaper.jpg                "$HOME/.config/i3/wallpaper.jpg"
put i3/lock-avatar.png              "$HOME/.config/i3/lock-avatar.png"
put i3/lock-image.png              "$HOME/.config/i3/lock-image.png"

# polybar: layout + launch + scripts  (colors.ini comes from apply-theme.sh)
put polybar/config.ini              "$HOME/.config/polybar/config.ini"
put polybar/launch.sh               "$HOME/.config/polybar/launch.sh" x
put polybar/scripts/bluetooth.sh    "$HOME/.config/polybar/scripts/bluetooth.sh" x
put polybar/scripts/powermenu.sh    "$HOME/.config/polybar/scripts/powermenu.sh" x

# rofi: layout only  (palettes + colors.rasi come from apply-theme.sh)
put rofi/config.rasi                "$HOME/.config/rofi/config.rasi"

# alacritty: terminal config + flavor imports
put alacritty/alacritty.toml        "$HOME/.config/alacritty/alacritty.toml"
for f in frappe macchiato mocha; do
  put "alacritty/catppuccin-$f.toml" "$HOME/.config/alacritty/catppuccin-$f.toml"
done

# picom: config + shaders.  picom can't expand $HOME, so substitute the real path.
put picom/picom.conf                "$HOME/.config/picom.conf"
sed -i "s|\$HOME|$HOME|g" "$HOME/.config/picom.conf"
put picom/shaders/lock.glsl         "$HOME/.config/picom/shaders/lock.glsl"
put picom/shaders/OldCRT.glsl       "$HOME/.config/picom/shaders/OldCRT.glsl"

# xdg portal: force GTK file chooser for Brave/Chromium
put xdg-desktop-portal/portals.conf "$HOME/.config/xdg-desktop-portal/portals.conf"

# Brave .desktop override: shadows the packaged launcher to add VA-API hardware
# video decode (--enable-features=VaapiVideoDecodeLinuxGL). The i3 $mod+b bind
# carries the same flag; this covers menu/rofi launches. Lives in ~/.local so an
# `apt upgrade` of brave-browser can't clobber it.
put applications/brave-browser.desktop "$HOME/.local/share/applications/brave-browser.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# home dotfiles
put home/.zshrc                     "$HOME/.zshrc"
put home/.xprofile                  "$HOME/.xprofile"
put home/.Xresources                "$HOME/.Xresources"
put home/.profile                   "$HOME/.profile"
put home/.gitconfig                 "$HOME/.gitconfig"

# ==========================================================================
# 12. Xorg natural-scroll snippet  (OPTIONAL — BT mouse natural scroll; sudo)
# ==========================================================================
log "Installing Xorg natural-scroll snippet (optional)"
if [ -n "$SUDO" ]; then
  $SUDO install -Dm644 "$SETUP_DIR/xorg/90-natural-scrolling.conf" \
    /etc/X11/xorg.conf.d/90-natural-scrolling.conf \
    && info "installed /etc/X11/xorg.conf.d/90-natural-scrolling.conf" \
    || warn "could not install xorg snippet (non-fatal)"
else
  info "skipped (needs sudo): install xorg/90-natural-scrolling.conf to /etc/X11/xorg.conf.d/"
fi

# ==========================================================================
# 13. displays: hotplug / lid / rotate fallbacks
# ==========================================================================
log "Running displays/install.sh (autorandr hotplug/lid/rotate)"
if [ -x "$SETUP_DIR/displays/install.sh" ]; then
  "$SETUP_DIR/displays/install.sh" || warn "displays/install.sh reported an issue (non-fatal)"
else
  warn "displays/install.sh not found/executable"
fi

# ==========================================================================
# 14. Theme everything (+ seed tmux/nvim/dunst/starship)
# ==========================================================================
log "Theming everything with apply-theme.sh ($FLAVOR)"
"$SETUP_DIR/apply-theme.sh" "$FLAVOR" || warn "apply-theme.sh reported an issue — see output above"

# Pre-build the lock background cache so the first lock is instant.
[ -x "$HOME/.config/i3/scripts/lock.sh" ] && "$HOME/.config/i3/scripts/lock.sh" --prepare 2>/dev/null || true

# ==========================================================================
# 15. Default login shell -> zsh
# ==========================================================================
# Do this as ROOT (via the sudo we already have) so it's NON-interactive. A plain
# `chsh` run as you prompts for your password and gets skipped on an unattended
# run, leaving /etc/passwd on /bin/bash — so every new terminal starts bash and
# you'd have to `exec zsh` by hand. Run as root, chsh/usermod set it silently.
log "Setting zsh as the default login shell"
ZSH_BIN="$(command -v zsh || true)"
TARGET_USER="$(id -un)"
CURRENT_SHELL="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7)"
if [ -z "$ZSH_BIN" ]; then
  warn "zsh not found — skipping the default-shell change"
elif [ "$CURRENT_SHELL" = "$ZSH_BIN" ]; then
  info "zsh is already your login shell"
else
  # Make sure zsh is a permitted login shell, then set it.
  grep -qxF "$ZSH_BIN" /etc/shells 2>/dev/null \
    || echo "$ZSH_BIN" | $SUDO tee -a /etc/shells >/dev/null 2>&1 || true
  if { [ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ]; } \
     && { $SUDO chsh -s "$ZSH_BIN" "$TARGET_USER" 2>/dev/null \
          || $SUDO usermod -s "$ZSH_BIN" "$TARGET_USER" 2>/dev/null; }; then
    info "login shell set to $ZSH_BIN (log out/in to take effect)"
  else
    warn "could not set it automatically — run yourself:  chsh -s $ZSH_BIN"
  fi
fi

# ==========================================================================
# Done
# ==========================================================================
cat <<EOF

$(printf '\033[1;32m✓ install complete (flavor: %s)\033[0m' "$FLAVOR")

Next steps:
  • Log out and back into the i3 session (env vars from ~/.xprofile, the new
    shell, and group changes only apply on a fresh session).
  • Inside i3, re-save your monitor profiles — they're EDID-specific to each
    machine and don't transfer:  autorandr --save mobile  (see README "External monitors").
  • ~/.xprofile pins eDP @ 2880x1800 and Xft.dpi=120 (1.25x HiDPI) for THIS
    laptop — adjust the mode/DPI for your panel (see README "Display (HiDPI)").
  • Some bits need a re-login or a running session: brightnessctl udev group,
    the tray applets (nm-applet/blueman), and PipeWire/wireplumber.
  • Switch flavor anytime:  ./apply-theme.sh mocha

See README.md for the per-component details and gotchas.
EOF
