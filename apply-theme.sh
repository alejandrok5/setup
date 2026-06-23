#!/usr/bin/env bash
#
# apply-theme.sh (server branch) — apply a Catppuccin flavor across the CONSOLE
#                  stack (zsh, starship, btop, yazi, lazygit, lazydocker, nvim)
#                  and seed the tmux config (Rose Pine — flavor-independent).
#
# This is the headless / Ubuntu-Server variant: no i3/polybar/rofi/dunst/gtk —
# only terminal/TUI tools that work over SSH. See install-server.sh + README.
#
# Usage:
#   ./apply-theme.sh [flavor] [component]
#
#   flavor:    latte | frappe | macchiato | mocha   (default: macchiato)
#   component: optional — re-theme just ONE target (zsh starship btop yazi
#              lazygit lazydocker nvim tmux) instead of all of them
#
# lazygit/lazydocker have no upstream Catppuccin repo to vendor, so their colors
# are generated here from an embedded palette (mauve accent, matching the rest).
# Their ~/.config/<tool>/config.yml is OWNED by this script (regenerated each run,
# .bak kept) — like i3's colors.conf on the desktop branch.

set -euo pipefail

# --- locate ourselves / sources -------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_THEMES_DIR="$SCRIPT_DIR/zsh-syntax-highlighting/themes"
BTOP_THEMES_DIR="$SCRIPT_DIR/btop/themes"
YAZI_SRC_DIR="$SCRIPT_DIR/yazi"            # vendored Catppuccin yazi themes + tmThemes
STARSHIP_SRC="$SCRIPT_DIR/starship/catppuccin-powerline.toml" # vendored official starship preset
TMUX_SRC="$SCRIPT_DIR/tmux/tmux.conf"     # vendored tmux config (Rose Pine; seeded if absent)
NVIM_SRC_DIR="$SCRIPT_DIR/nvim"           # vendored LazyVim config (seeded if absent)

# --- args ------------------------------------------------------------------
FLAVOR="${1:-macchiato}"
case "$FLAVOR" in
  latte|frappe|macchiato|mocha) ;;
  *)
    echo "error: unknown flavor '$FLAVOR' (expected: latte | frappe | macchiato | mocha)" >&2
    exit 1
    ;;
esac
ONLY="${2:-}"

# --- destinations ----------------------------------------------------------
ZSH_DIR="$HOME/.zsh"
ZSHRC="$HOME/.zshrc"
ZSH_PLUGIN="/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
ZSH_MARK_BEGIN="# >>> catppuccin zsh-syntax-highlighting >>>"
ZSH_MARK_END="# <<< catppuccin zsh-syntax-highlighting <<<"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
STARSHIP_MARK_BEGIN="# >>> starship prompt >>>"
STARSHIP_MARK_END="# <<< starship prompt <<<"
TMUX_CONFIG="$HOME/.tmux.conf"
TMUX_PLUGIN_DIR="$HOME/.tmux/plugins"
BTOP_DIR="$HOME/.config/btop"
BTOP_THEME_DEST="$BTOP_DIR/themes"
BTOP_CONF="$BTOP_DIR/btop.conf"
NVIM_DIR="$HOME/.config/nvim"
NVIM_PLUGIN_DIR="$NVIM_DIR/lua/plugins"
NVIM_COLORSCHEME="$NVIM_PLUGIN_DIR/colorscheme.lua"
YAZI_DIR="$HOME/.config/yazi"
YAZI_ACCENT="mauve"

backup() { [ -f "$1" ] && cp -f "$1" "$1.bak" || true; }  # no-op (success) if absent

# Embedded Catppuccin palette (only the slots lazygit/lazydocker need).
_ctp_palette() {
  case "$1" in
    latte)
      ctp_base="#eff1f5"; ctp_text="#4c4f69"; ctp_subtext0="#6c6f85"
      ctp_surface0="#ccd0da"; ctp_surface1="#bcc0cc"
      ctp_blue="#1e66f5"; ctp_red="#d20f39"; ctp_yellow="#df8e1d"
      ctp_mauve="#8839ef"; ctp_lavender="#7287fd" ;;
    frappe)
      ctp_base="#303446"; ctp_text="#c6d0f5"; ctp_subtext0="#a5adce"
      ctp_surface0="#414559"; ctp_surface1="#51576d"
      ctp_blue="#8caaee"; ctp_red="#e78284"; ctp_yellow="#e5c890"
      ctp_mauve="#ca9ee6"; ctp_lavender="#babbf1" ;;
    macchiato)
      ctp_base="#24273a"; ctp_text="#cad3f5"; ctp_subtext0="#a5adcb"
      ctp_surface0="#363a4f"; ctp_surface1="#494d64"
      ctp_blue="#8aadf4"; ctp_red="#ed8796"; ctp_yellow="#eed49f"
      ctp_mauve="#c6a0f6"; ctp_lavender="#b7bdf8" ;;
    mocha)
      ctp_base="#1e1e2e"; ctp_text="#cdd6f4"; ctp_subtext0="#a6adc8"
      ctp_surface0="#313244"; ctp_surface1="#45475a"
      ctp_blue="#89b4fa"; ctp_red="#f38ba8"; ctp_yellow="#f9e2af"
      ctp_mauve="#cba6f7"; ctp_lavender="#b4befe" ;;
  esac
}

if [ -n "$ONLY" ]; then
  echo ">> Applying Catppuccin '$FLAVOR' to: $ONLY"
else
  echo ">> Applying Catppuccin '$FLAVOR' to zsh, starship, btop, yazi, lazygit, lazydocker, nvim (plus tmux — Rose Pine, flavor-independent)"
fi

# ==========================================================================
# zsh-syntax-highlighting
# ==========================================================================
apply_zsh() {
  local theme_name="catppuccin_${FLAVOR}-zsh-syntax-highlighting.zsh"
  local src="$ZSH_THEMES_DIR/$theme_name"
  if [ ! -f "$src" ]; then
    echo "   [zsh] skip: theme not found at $src" >&2
    return
  fi

  mkdir -p "$ZSH_DIR"
  cp -f "$src" "$ZSH_DIR/$theme_name"
  echo "   [zsh] installed $ZSH_DIR/$theme_name"

  if [ ! -f "$ZSH_PLUGIN" ]; then
    echo "   [zsh] WARNING: plugin not found at $ZSH_PLUGIN" >&2
    echo "         install it, e.g.: sudo apt-get install zsh-syntax-highlighting" >&2
  fi

  touch "$ZSHRC"
  backup "$ZSHRC"

  # Drop any previous managed block, then append a fresh one at the end so the
  # plugin remains the last thing sourced.
  local tmp
  tmp="$(mktemp)"
  awk -v b="$ZSH_MARK_BEGIN" -v e="$ZSH_MARK_END" '
    $0 == b {skip=1} skip==0 {print} $0 == e {skip=0}
  ' "$ZSHRC" > "$tmp"
  awk 'NF{p=NR} {a[NR]=$0} END{for(i=1;i<=p;i++) print a[i]}' "$tmp" > "$ZSHRC"
  {
    echo
    echo "$ZSH_MARK_BEGIN"
    echo "# Managed by ~/setup/apply-theme.sh — re-run the script to change flavor."
    echo "# The Catppuccin theme must be sourced BEFORE the plugin, and the plugin"
    echo "# must be the LAST thing sourced in .zshrc."
    echo "source ~/.zsh/$theme_name"
    echo "source $ZSH_PLUGIN"
    echo "$ZSH_MARK_END"
  } >> "$ZSHRC"
  rm -f "$tmp"
  echo "   [zsh] wired $ZSHRC (run 'exec zsh' to apply in this shell)"
}

# ==========================================================================
# starship (the prompt — replaces ZSH_THEME, NOT the oh-my-zsh plugins)
# ==========================================================================
apply_starship() {
  if ! command -v starship >/dev/null 2>&1; then
    echo "   [starship] WARNING: starship not on PATH — install it first:" >&2
    echo "              curl -fsSL https://starship.rs/install.sh | sh -s -- -b ~/.local/bin -y" >&2
  fi

  mkdir -p "$(dirname "$STARSHIP_CONFIG")"
  backup "$STARSHIP_CONFIG"

  if [ ! -f "$STARSHIP_SRC" ]; then
    echo "   [starship] skip: vendored seed not found at $STARSHIP_SRC" >&2
    return
  fi
  if [ ! -f "$STARSHIP_CONFIG" ]; then
    {
      echo "# Your Starship prompt — seeded from ~/setup/starship/catppuccin-powerline.toml."
      echo "# Edit freely; 'apply-theme.sh <flavor>' only rewrites the 'palette =' line below."
      sed -E "s|^palette = .*|palette = \"catppuccin_$FLAVOR\"|" "$STARSHIP_SRC"
    } > "$STARSHIP_CONFIG"
    echo "   [starship] seeded $STARSHIP_CONFIG (palette = catppuccin_$FLAVOR) — it's yours now"
  elif grep -qE '^palette = ' "$STARSHIP_CONFIG"; then
    sed -i -E "s|^palette = .*|palette = \"catppuccin_$FLAVOR\"|" "$STARSHIP_CONFIG"
    echo "   [starship] set palette = catppuccin_$FLAVOR in $STARSHIP_CONFIG (your layout untouched)"
  else
    echo "   [starship] note: no 'palette =' line in $STARSHIP_CONFIG — flavor not applied." >&2
    echo "              add one, or delete the file and re-run to re-seed from the preset." >&2
  fi

  # --- wire .zshrc ----------------------------------------------------------
  touch "$ZSHRC"
  backup "$ZSHRC"
  sed -i -E 's|^ZSH_THEME=.*|ZSH_THEME=""  # Starship owns the prompt (see block below)|' "$ZSHRC"
  local tmp
  tmp="$(mktemp)"
  awk -v b="$STARSHIP_MARK_BEGIN" -v e="$STARSHIP_MARK_END" '
    $0 == b {skip=1; next}
    $0 == e {skip=0; next}
    skip {next}
    {print}
    $0 == "source $ZSH/oh-my-zsh.sh" {
      print ""
      print b
      print "# Managed by ~/setup/apply-theme.sh — Starship owns the prompt."
      print "# Loaded AFTER oh-my-zsh so it wins the prompt, but BEFORE the"
      print "# zsh-syntax-highlighting block, which must stay sourced last."
      print "# Make sure ~/.local/bin (default starship install dir) is reachable"
      print "# here — the main PATH export may come later in this file."
      print "command -v starship >/dev/null 2>&1 || export PATH=\"$HOME/.local/bin:$PATH\""
      print "command -v starship >/dev/null 2>&1 && eval \"$(starship init zsh)\""
      print e
    }
  ' "$ZSHRC" > "$tmp" && mv "$tmp" "$ZSHRC"

  if ! grep -qF "$STARSHIP_MARK_BEGIN" "$ZSHRC"; then
    echo "   [starship] WARNING: could not find 'source \$ZSH/oh-my-zsh.sh' in $ZSHRC;" >&2
    echo "              add this line yourself (before the syntax-highlighting block):" >&2
    echo '              eval "$(starship init zsh)"' >&2
  fi
  echo "   [starship] wired $ZSHRC (run 'exec zsh' to apply in this shell)"
}

# ==========================================================================
# btop
# ==========================================================================
apply_btop() {
  local theme_file="catppuccin_${FLAVOR}.theme"
  local theme_name="catppuccin_${FLAVOR}"
  local src="$BTOP_THEMES_DIR/$theme_file"
  if [ ! -f "$src" ]; then
    echo "   [btop] skip: theme not found at $src" >&2
    return
  fi

  mkdir -p "$BTOP_THEME_DEST"
  cp -f "$src" "$BTOP_THEME_DEST/$theme_file"
  echo "   [btop] installed $BTOP_THEME_DEST/$theme_file"

  touch "$BTOP_CONF"
  backup "$BTOP_CONF"
  if grep -qE '^[[:space:]]*color_theme[[:space:]]*=' "$BTOP_CONF"; then
    sed -i -E "s|^[[:space:]]*color_theme[[:space:]]*=.*|color_theme = \"$theme_name\"|" "$BTOP_CONF"
  else
    printf 'color_theme = "%s"\n' "$theme_name" >> "$BTOP_CONF"
  fi
  echo "   [btop] set color_theme = \"$theme_name\" in $BTOP_CONF"
  # On a headless box there's usually no compositor, so keep btop's own background
  # (theme_background = true is btop's default — we leave it alone here).
  echo "   [btop] (restart btop to see it)"
}

# ==========================================================================
# yazi (terminal file manager)
# ==========================================================================
apply_yazi() {
  local theme="$YAZI_SRC_DIR/themes/catppuccin-$FLAVOR-$YAZI_ACCENT.toml"
  local tm="$YAZI_SRC_DIR/tmtheme/Catppuccin-$FLAVOR.tmTheme"
  if [ ! -f "$theme" ]; then
    echo "   [yazi] skip: theme not found at $theme" >&2
    return
  fi

  mkdir -p "$YAZI_DIR"
  backup "$YAZI_DIR/theme.toml"
  cp -f "$theme" "$YAZI_DIR/theme.toml"
  cp -f "$tm" "$YAZI_DIR/Catppuccin-$FLAVOR.tmTheme"
  echo "   [yazi] wrote $YAZI_DIR/theme.toml (flavor = $FLAVOR, accent = $YAZI_ACCENT)"
  # yazi loads its theme on launch — reopen yazi to see the change.
}

# ==========================================================================
# lazygit  (OWNED config.yml — theme generated from the embedded palette)
# ==========================================================================
apply_lazygit() {
  command -v lazygit >/dev/null 2>&1 \
    || echo "   [lazygit] note: lazygit not on PATH yet — theme written for when it is" >&2
  _ctp_palette "$FLAVOR"
  local dir="$HOME/.config/lazygit" conf="$HOME/.config/lazygit/config.yml"
  mkdir -p "$dir"
  backup "$conf"
  cat > "$conf" <<EOF
# AUTO-GENERATED by ~/setup/apply-theme.sh — Catppuccin $FLAVOR (mauve accent).
# OWNED file: regenerated every run (.bak kept). To change layout/keybinds, edit
# the template in apply-theme.sh (apply_lazygit) rather than this file.
gui:
  nerdFontsVersion: "3"
  theme:
    activeBorderColor:
      - "$ctp_mauve"
      - bold
    inactiveBorderColor:
      - "$ctp_subtext0"
    searchingActiveBorderColor:
      - "$ctp_yellow"
    optionsTextColor:
      - "$ctp_blue"
    selectedLineBgColor:
      - "$ctp_surface0"
    cherryPickedCommitBgColor:
      - "$ctp_surface1"
    cherryPickedCommitFgColor:
      - "$ctp_blue"
    unstagedChangesColor:
      - "$ctp_red"
    defaultFgColor:
      - "$ctp_text"
EOF
  echo "   [lazygit] wrote $conf (flavor = $FLAVOR)"
}

# ==========================================================================
# lazydocker  (OWNED config.yml — theme generated from the embedded palette)
# ==========================================================================
apply_lazydocker() {
  command -v lazydocker >/dev/null 2>&1 \
    || echo "   [lazydocker] note: lazydocker not on PATH yet — theme written for when it is" >&2
  _ctp_palette "$FLAVOR"
  local dir="$HOME/.config/lazydocker" conf="$HOME/.config/lazydocker/config.yml"
  mkdir -p "$dir"
  backup "$conf"
  cat > "$conf" <<EOF
# AUTO-GENERATED by ~/setup/apply-theme.sh — Catppuccin $FLAVOR (mauve accent).
# OWNED file: regenerated every run (.bak kept).
gui:
  theme:
    activeBorderColor:
      - "$ctp_mauve"
      - bold
    inactiveBorderColor:
      - "$ctp_subtext0"
    selectedLineBgColor:
      - "$ctp_surface0"
    optionsTextColor:
      - "$ctp_blue"
EOF
  echo "   [lazydocker] wrote $conf (flavor = $FLAVOR)"
}

# ==========================================================================
# Neovim (LazyVim + catppuccin/nvim)
# ==========================================================================
apply_nvim() {
  # --- 1. bootstrap LazyVim if there's no nvim config at all ----------------
  if [ ! -d "$NVIM_DIR" ]; then
    if command -v git >/dev/null 2>&1; then
      if git clone --depth 1 -q https://github.com/LazyVim/starter "$NVIM_DIR" 2>/dev/null; then
        rm -rf "$NVIM_DIR/.git"
        echo "   [nvim] bootstrapped LazyVim starter -> $NVIM_DIR"
      else
        echo "   [nvim] skip: could not clone LazyVim starter (offline?) — install it, then re-run" >&2
        return
      fi
    else
      echo "   [nvim] skip: $NVIM_DIR not found and git missing (install LazyVim first)" >&2
      return
    fi
  fi

  # --- 2. seed our vendored config (absent or pristine-stub only) ------------
  _nvim_has_code() {
    awk '{ l=$0; sub(/^[[:space:]]+/,"",l); if (l=="") next; if (l ~ /^--/) next; c=1 }
         END { exit (c?0:1) }' "$1"
  }
  _nvim_seed() {
    local src="$NVIM_SRC_DIR/$1" dest="$NVIM_DIR/$1"
    if [ ! -f "$src" ]; then
      echo "   [nvim] skip seed: vendored $1 missing at $src" >&2
      return
    fi
    if [ -f "$dest" ] && _nvim_has_code "$dest"; then
      echo "   [nvim] $1 present (your edits) — left as-is"
      return
    fi
    mkdir -p "$(dirname "$dest")"
    {
      echo "-- Seeded from ~/setup/nvim/$1 by apply-theme.sh — edit freely;"
      echo "-- it won't be re-touched once this file has real (non-comment) code."
      cat "$src"
    } > "$dest"
    echo "   [nvim] seeded $dest"
  }
  _nvim_seed lua/config/options.lua
  _nvim_seed lua/config/keymaps.lua
  _nvim_seed lua/plugins/lsp.lua
  _nvim_seed lua/plugins/formatting.lua
  unset -f _nvim_has_code _nvim_seed

  # --- bootstrap the global ruby-lsp gem so the Ruby LSP attaches ------------
  if command -v ruby-lsp >/dev/null 2>&1; then
    echo "   [nvim] ruby-lsp present: $(command -v ruby-lsp)"
  elif command -v gem >/dev/null 2>&1; then
    if gem install ruby-lsp >/dev/null 2>&1; then
      echo "   [nvim] installed ruby-lsp gem"
    else
      echo "   [nvim] WARNING: 'gem install ruby-lsp' failed — install it manually for Ruby LSP" >&2
    fi
  else
    echo "   [nvim] note: no 'gem' on PATH — install Ruby (mise) + 'gem install ruby-lsp' for Ruby LSP" >&2
  fi

  # --- 3. theme: regenerate the owned colorscheme spec ----------------------
  mkdir -p "$NVIM_PLUGIN_DIR"
  backup "$NVIM_COLORSCHEME"

  cat > "$NVIM_COLORSCHEME" <<EOF
-- AUTO-GENERATED by ~/setup/apply-theme.sh — do not edit by hand.
-- Flavor: catppuccin-$FLAVOR
return {
  -- Install catppuccin and pin the flavour.
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "$FLAVOR",
    },
  },

  -- Make catppuccin LazyVim's active colorscheme.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
EOF
  echo "   [nvim] wrote $NVIM_COLORSCHEME (flavour = $FLAVOR)"
  echo "   [nvim] (restart nvim; lazy.nvim installs/recompiles catppuccin on launch)"
}

# ==========================================================================
# tmux  (Rose Pine — independent of the Catppuccin flavor)
# ==========================================================================
apply_tmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "   [tmux] WARNING: tmux not on PATH — install it first (e.g. apt-get install tmux)" >&2
  fi
  if [ ! -f "$TMUX_SRC" ]; then
    echo "   [tmux] skip: vendored config not found at $TMUX_SRC" >&2
    return
  fi

  if [ ! -f "$TMUX_CONFIG" ]; then
    {
      echo "# Your tmux config — seeded from ~/setup/tmux/tmux.conf (Rose Pine, moon)."
      echo "# Edit freely; apply-theme.sh never rewrites this file — the tmux theme is"
      echo "# Rose Pine and independent of the Catppuccin flavor arg."
      cat "$TMUX_SRC"
    } > "$TMUX_CONFIG"
    echo "   [tmux] seeded $TMUX_CONFIG (Rose Pine) — it's yours now"
  else
    echo "   [tmux] $TMUX_CONFIG present — left as-is (Rose Pine is flavor-independent)"
  fi

  if command -v git >/dev/null 2>&1; then
    mkdir -p "$TMUX_PLUGIN_DIR"
    local clone_failed=0
    _tmux_clone() {
      local dir="$TMUX_PLUGIN_DIR/$1"
      [ -d "$dir" ] && { echo "   [tmux] plugin present: $1"; return; }
      if git clone --depth 1 -q "$2" "$dir" 2>/dev/null; then
        echo "   [tmux] cloned $1"
      else
        echo "   [tmux] WARNING: could not clone $1 ($2) — offline? finish later with prefix + I" >&2
        clone_failed=1
      fi
    }
    _tmux_clone tpm            https://github.com/tmux-plugins/tpm
    _tmux_clone tmux-sensible  https://github.com/tmux-plugins/tmux-sensible
    _tmux_clone tmux-resurrect https://github.com/tmux-plugins/tmux-resurrect
    _tmux_clone tmux-continuum https://github.com/tmux-plugins/tmux-continuum
    _tmux_clone rose-pine-tmux https://github.com/rose-pine/tmux
    unset -f _tmux_clone
    [ "$clone_failed" = 1 ] && echo "   [tmux] some plugins missing — open tmux and press prefix(C-a) + I to finish" >&2
  else
    echo "   [tmux] note: git not found — install TPM + rose-pine manually to get the theme" >&2
  fi

  if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
    tmux source-file "$TMUX_CONFIG" >/dev/null 2>&1 \
      && echo "   [tmux] reloaded running server" \
      || echo "   [tmux] (reload inside tmux with prefix C-a then r)"
  else
    echo "   [tmux] (start tmux to see it; prefix is C-a, reload with C-a r)"
  fi
}

if [ -n "$ONLY" ]; then
  case "$ONLY" in
    zsh|starship|btop|yazi|lazygit|lazydocker|nvim|tmux) "apply_$ONLY" ;;
    *)
      echo "error: unknown component '$ONLY' (expected one of: zsh starship btop yazi lazygit lazydocker nvim tmux)" >&2
      exit 1
      ;;
  esac
else
  apply_zsh
  apply_starship
  apply_btop
  apply_yazi
  apply_lazygit
  apply_lazydocker
  apply_nvim
  apply_tmux
fi

echo ">> Done."
