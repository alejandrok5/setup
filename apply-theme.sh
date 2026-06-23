#!/usr/bin/env bash
#
# apply-theme.sh — apply a Catppuccin flavor across the i3 desktop
#                  (i3, zsh, starship, btop, polybar, dunst, rofi, GTK, nvim)
#                  and seed the tmux config (Rose Pine — flavor-independent).
#
# Usage:
#   ./apply-theme.sh [flavor] [component]
#
#   flavor:    latte | frappe | macchiato | mocha   (default: macchiato)
#   component: optional — re-theme just ONE target (i3 zsh starship btop polybar
#              dunst rofi yazi gtk nvim tmux) instead of all of them
#
# What it does:
#   - i3:  writes ~/.config/i3/colors.conf containing the chosen palette
#          PLUS the window color rules. They must live in ONE file because i3
#          only substitutes $variables within a single physical file (a nested
#          `include` leaves them unresolved). No bar {} block — polybar owns the
#          status bar (see polybar below).
#   - polybar: copies the chosen palette to ~/.config/polybar/colors.ini, which
#          the hand-maintained ~/.config/polybar/config.ini includes. Same split
#          as i3: config.ini = layout, colors.ini = palette.
#   - dunst: copies the chosen palette into ~/.config/dunst/dunstrc.d/
#          catppuccin.conf (loaded after the hand-maintained dunstrc, so its
#          colors win), then reloads the daemon with dunstctl. This themes the
#          notification popups (nm-applet "connected", blueman, volume/brightness
#          OSDs). Same layout/palette split as polybar.
#   - rofi: refreshes the vendored Catppuccin palettes + styling into
#          ~/.config/rofi and writes colors.rasi to @import the chosen flavor.
#          The launcher layout (config.rasi) is hand-maintained, left untouched.
#   - yazi: copies the chosen flavor's theme.toml (mauve accent) + its matching
#          tmTheme (code-preview syntax colors) into ~/.config/yazi.
#   - gtk: installs the prebuilt Catppuccin GTK theme zip if missing, then sets
#          gtk-theme / color-scheme / icon-theme (mauve accent) so GTK apps
#          (nm-applet, dialogs, Brave's file picker) match. See README "GTK apps".
#   - zsh: copies the chosen zsh-syntax-highlighting theme into ~/.zsh/ and
#          wires ~/.zshrc to source it BEFORE the plugin (the plugin is sourced
#          last, as it requires).
#   - starship: the prompt. SEEDS ~/.config/starship.toml from the vendored
#          official catppuccin-powerline preset only if absent (it's YOUR file
#          after that); on later runs rewrites only its `palette` line to the
#          flavor, like btop. Also wires ~/.zshrc: blanks ZSH_THEME and inits
#          starship after oh-my-zsh but before the syntax-highlighting block.
#          oh-my-zsh PLUGINS are untouched — starship only replaces the prompt.
#   - btop: copies the theme into ~/.config/btop/themes and points btop.conf's
#          color_theme at it.
#   - nvim: bootstraps the LazyVim starter if ~/.config/nvim is absent, then
#          SEEDS the vendored config (~/setup/nvim: keymaps/options/lsp/
#          formatting) only when the live file is absent or a pristine stub
#          (never clobbers your edits), installs the global ruby-lsp gem if
#          missing, and regenerates the owned colorscheme spec that selects
#          catppuccin/nvim and pins the flavour. lazy.nvim fetches the plugins
#          (incl. catppuccin) on next launch. Keymaps are ported from the old
#          NvChad config (leader = `\`); see README "Neovim".
#   - tmux: NOT Catppuccin — the config is themed Rose Pine (moon), ported as-is
#          from the old machine. Seeds ~/.tmux.conf from the vendored
#          ~/setup/tmux/tmux.conf only if ABSENT (it's YOUR file after that),
#          bootstraps TPM + the rose-pine plugin (+ resurrect/continuum/sensible)
#          so the theme and session-persistence work, and reloads a running
#          server. Independent of the flavor arg — switching Catppuccin flavors
#          leaves tmux untouched.
#
# Theme sources are the vendored Catppuccin repos next to this script (except
# nvim, whose theme is fetched by lazy.nvim, and tmux, themed Rose Pine via TPM).
# Re-running with a different flavor is safe and idempotent.

set -euo pipefail

# --- locate ourselves / sources -------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
I3_THEMES_DIR="$SCRIPT_DIR/i3/themes"
ZSH_THEMES_DIR="$SCRIPT_DIR/zsh-syntax-highlighting/themes"
BTOP_THEMES_DIR="$SCRIPT_DIR/btop/themes"
POLYBAR_THEMES_DIR="$SCRIPT_DIR/polybar/themes"
DUNST_THEMES_DIR="$SCRIPT_DIR/dunst/themes" # vendored Catppuccin dunst palettes
DUNST_LAYOUT_SRC="$SCRIPT_DIR/dunst/dunstrc" # vendored layout template (installed if absent)
ROFI_SRC_DIR="$SCRIPT_DIR/rofi"            # vendored Catppuccin palettes + styling
YAZI_SRC_DIR="$SCRIPT_DIR/yazi"            # vendored Catppuccin yazi themes + tmThemes
STARSHIP_SRC="$SCRIPT_DIR/starship/catppuccin-powerline.toml" # vendored official starship preset
TMUX_SRC="$SCRIPT_DIR/tmux/tmux.conf"     # vendored tmux config (Rose Pine; seeded if absent)
NVIM_SRC_DIR="$SCRIPT_DIR/nvim"           # vendored LazyVim config (keymaps/options/lsp/formatting; seeded if absent)

# --- args ------------------------------------------------------------------
FLAVOR="${1:-macchiato}"
case "$FLAVOR" in
  latte|frappe|macchiato|mocha) ;;
  *)
    echo "error: unknown flavor '$FLAVOR' (expected: latte | frappe | macchiato | mocha)" >&2
    exit 1
    ;;
esac

# Optional 2nd arg: re-theme a single component instead of everything, e.g.
#   ./apply-theme.sh macchiato starship
# Handy to repaint the prompt without restarting i3/polybar/etc. Must name one of
# the apply_* targets below (i3, zsh, starship, btop, polybar, dunst, rofi, yazi,
# gtk, nvim, tmux).
ONLY="${2:-}"

# --- destinations ----------------------------------------------------------
I3_DIR="$HOME/.config/i3"
I3_COLORS="$I3_DIR/colors.conf"
I3_CONFIG="$I3_DIR/config"
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
POLYBAR_DIR="$HOME/.config/polybar"
POLYBAR_COLORS="$POLYBAR_DIR/colors.ini"
DUNST_DIR="$HOME/.config/dunst"
DUNST_COLORS="$DUNST_DIR/dunstrc.d/catppuccin.conf"
ROFI_DIR="$HOME/.config/rofi"
ROFI_COLORS="$ROFI_DIR/colors.rasi"
YAZI_DIR="$HOME/.config/yazi"
YAZI_ACCENT="mauve"                      # accent for the Catppuccin yazi theme
GTK_ACCENT="mauve"                       # accent for the Catppuccin GTK theme
GTK_THEMES_SRC="$SCRIPT_DIR/gtk/themes"  # vendored prebuilt theme zips
GTK_THEMES_DEST="$HOME/.local/share/themes"

backup() { [ -f "$1" ] && cp -f "$1" "$1.bak" || true; }  # no-op (success) if absent

if [ -n "$ONLY" ]; then
  echo ">> Applying Catppuccin '$FLAVOR' to: $ONLY"
else
  echo ">> Applying Catppuccin '$FLAVOR' to i3, zsh-syntax-highlighting, starship, btop, nvim, polybar, dunst, rofi, yazi and GTK (plus tmux — Rose Pine, flavor-independent)"
fi

# ==========================================================================
# i3
# ==========================================================================
apply_i3() {
  local palette="$I3_THEMES_DIR/catppuccin-$FLAVOR"
  if [ ! -f "$palette" ]; then
    echo "   [i3]  skip: palette not found at $palette" >&2
    return
  fi

  mkdir -p "$I3_DIR"
  backup "$I3_COLORS"

  {
    echo "# AUTO-GENERATED by ~/setup/apply-theme.sh — do not edit by hand."
    echo "# Flavor: catppuccin-$FLAVOR"
    echo "# Palette and rules are kept in ONE file on purpose: i3 only resolves"
    echo "# \$variables within a single physical file (a nested include leaves"
    echo "# them unset and the bar renders grey)."
    echo
    cat "$palette"
    echo
    cat <<'RULES'

# target                 title     bg    text   indicator  border
client.focused           $lavender $base $text  $rosewater $lavender
client.focused_inactive  $overlay0 $base $text  $rosewater $overlay0
client.unfocused         $overlay0 $base $text  $rosewater $overlay0
client.urgent            $peach    $base $peach $overlay0  $peach
client.placeholder       $overlay0 $base $text  $overlay0  $overlay0
client.background        $base

# No bar {} block here on purpose: polybar owns the status bar now (launched
# from i3 via ~/.config/polybar/launch.sh). polybar still uses this Catppuccin
# palette via ~/.config/polybar/colors.ini — see apply_polybar() below.
RULES
  } > "$I3_COLORS"
  echo "   [i3]  wrote $I3_COLORS"

  # Make sure the main config includes colors.conf and has no rival bar block.
  if [ -f "$I3_CONFIG" ]; then
    if ! grep -qE '^[[:space:]]*include[[:space:]].*colors\.conf' "$I3_CONFIG"; then
      echo "   [i3]  WARNING: $I3_CONFIG does not 'include ~/.config/i3/colors.conf'." >&2
      echo "         Add that line or the theme will not load." >&2
    fi
    if grep -qE '^[[:space:]]*bar[[:space:]]*\{' "$I3_CONFIG"; then
      echo "   [i3]  WARNING: a 'bar {}' block exists in $I3_CONFIG — you'll get TWO bars." >&2
      echo "         Remove it; the themed bar is defined in colors.conf." >&2
    fi
  else
    echo "   [i3]  WARNING: $I3_CONFIG not found." >&2
  fi

  # Validate, then reload if i3 is running.
  if command -v i3 >/dev/null 2>&1 && i3 -C -c "$I3_CONFIG" >/dev/null 2>&1; then
    if command -v i3-msg >/dev/null 2>&1 && i3-msg -t get_version >/dev/null 2>&1; then
      i3-msg restart >/dev/null 2>&1 && echo "   [i3]  restarted i3 in place"
    else
      echo "   [i3]  config valid (i3 not running; restart when you start it)"
    fi
  else
    echo "   [i3]  note: could not validate config (is i3 installed?)" >&2
  fi
}

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
  # Trim trailing blank lines, then add our block.
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

  # ~/.config/starship.toml is YOUR living config — the script does NOT own it
  # (same deal as the polybar/rofi layouts). Two cases, mirroring dunst + btop:
  #   * absent  → seed it once from the vendored official preset, palette set to
  #               this flavor. After that the file is yours to edit.
  #   * present → leave every customization alone and rewrite ONLY the `palette`
  #               line in place (btop-style), so switching flavor keeps your edits.
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
  # 1) Stop oh-my-zsh from drawing a prompt — Starship owns it now. ONLY the
  #    theme is blanked; OMZ plugins/completions/keybinds are untouched.
  sed -i -E 's|^ZSH_THEME=.*|ZSH_THEME=""  # Starship owns the prompt (see block below)|' "$ZSHRC"
  # 2) (Re)insert the Starship init right after oh-my-zsh.sh is sourced: late
  #    enough to win the prompt, early enough to stay BEFORE the
  #    zsh-syntax-highlighting block (which must remain the last thing sourced).
  #    Any previous copy is stripped first, so this is idempotent.
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
  local theme_name="catppuccin_${FLAVOR}"   # btop stores color_theme without the extension
  local src="$BTOP_THEMES_DIR/$theme_file"
  if [ ! -f "$src" ]; then
    echo "   [btop] skip: theme not found at $src" >&2
    return
  fi

  mkdir -p "$BTOP_THEME_DEST"
  cp -f "$src" "$BTOP_THEME_DEST/$theme_file"
  echo "   [btop] installed $BTOP_THEME_DEST/$theme_file"

  # btop.conf references the theme by name (no extension/path); btop resolves it
  # from ~/.config/btop/themes (then the system themes dir). Create a minimal
  # conf if absent (btop merges its own defaults for every key we omit);
  # otherwise rewrite the existing color_theme line in place.
  touch "$BTOP_CONF"
  backup "$BTOP_CONF"
  if grep -qE '^[[:space:]]*color_theme[[:space:]]*=' "$BTOP_CONF"; then
    sed -i -E "s|^[[:space:]]*color_theme[[:space:]]*=.*|color_theme = \"$theme_name\"|" "$BTOP_CONF"
  else
    printf 'color_theme = "%s"\n' "$theme_name" >> "$BTOP_CONF"
  fi
  echo "   [btop] set color_theme = \"$theme_name\" in $BTOP_CONF"

  # Transparency: theme_background = false makes btop skip its own background so
  # the (transparent) terminal shows through — see the i3 compositor (picom)
  # setup. Same idempotent pattern as color_theme above.
  if grep -qE '^[[:space:]]*theme_background[[:space:]]*=' "$BTOP_CONF"; then
    sed -i -E "s|^[[:space:]]*theme_background[[:space:]]*=.*|theme_background = false|" "$BTOP_CONF"
  else
    printf 'theme_background = false\n' >> "$BTOP_CONF"
  fi
  echo "   [btop] set theme_background = false (transparent; needs a compositor)"
  echo "   [btop] (restart btop to see it)"
}

# ==========================================================================
# polybar
# ==========================================================================
apply_polybar() {
  # polybar's config.ini (the bar LAYOUT) is hand-maintained and includes
  # ~/.config/polybar/colors.ini (the PALETTE). We only manage the palette here
  # — copy the chosen flavor into colors.ini. Same split as i3 (config /
  # colors.conf). The layout is left untouched, so re-theming never disturbs it.
  local src="$POLYBAR_THEMES_DIR/catppuccin-$FLAVOR.ini"
  if [ ! -f "$src" ]; then
    echo "   [polybar] skip: palette not found at $src" >&2
    return
  fi
  if [ ! -d "$POLYBAR_DIR" ]; then
    echo "   [polybar] skip: $POLYBAR_DIR not found (no polybar config installed)" >&2
    return
  fi

  backup "$POLYBAR_COLORS"
  cp -f "$src" "$POLYBAR_COLORS"
  echo "   [polybar] wrote $POLYBAR_COLORS (flavor = $FLAVOR)"

  # Reload running bars in place if any (config.ini has enable-ipc = true).
  if command -v polybar-msg >/dev/null 2>&1 && pgrep -x polybar >/dev/null 2>&1; then
    polybar-msg cmd restart >/dev/null 2>&1 && echo "   [polybar] reloaded running bars"
  else
    echo "   [polybar] (start it with ~/.config/polybar/launch.sh)"
  fi
}

# ==========================================================================
# dunst (notification daemon — nm-applet/blueman/volume popups)
# ==========================================================================
apply_dunst() {
  # dunst's dunstrc (the popup LAYOUT) includes the palette via
  # dunstrc.d/catppuccin.conf (loaded after, so its colors win). We manage the
  # palette here — copy the chosen flavor into that drop-in. Same split as
  # polybar (config.ini / colors.ini).
  #
  # The layout itself is vendored as a template (dunst/dunstrc): we install it
  # only if ~/.config/dunst/dunstrc is ABSENT, and never overwrite a customized
  # one (same "never clobber the layout" rule as polybar/rofi). That keeps the
  # setup self-contained — a fresh machine gets themed notifications from one
  # run — while leaving your edits intact on re-theme.
  local src="$DUNST_THEMES_DIR/catppuccin-$FLAVOR.conf"
  if [ ! -f "$src" ]; then
    echo "   [dunst] skip: palette not found at $src" >&2
    return
  fi

  mkdir -p "$DUNST_DIR/dunstrc.d"

  # Bootstrap the layout from the vendored template if the user has none yet.
  if [ ! -f "$DUNST_DIR/dunstrc" ]; then
    if [ -f "$DUNST_LAYOUT_SRC" ]; then
      cp -f "$DUNST_LAYOUT_SRC" "$DUNST_DIR/dunstrc"
      echo "   [dunst] installed layout template -> $DUNST_DIR/dunstrc"
    else
      echo "   [dunst] skip: no layout at $DUNST_DIR/dunstrc and none vendored at $DUNST_LAYOUT_SRC" >&2
      return
    fi
  fi

  backup "$DUNST_COLORS"
  cp -f "$src" "$DUNST_COLORS"
  echo "   [dunst] wrote $DUNST_COLORS (flavor = $FLAVOR)"

  # Reload the running daemon in place (dunst re-reads dunstrc + dunstrc.d).
  if command -v dunstctl >/dev/null 2>&1 && pgrep -x dunst >/dev/null 2>&1; then
    dunstctl reload >/dev/null 2>&1 && echo "   [dunst] reloaded running daemon"
  else
    echo "   [dunst] (dbus-activated; new colors apply on the next notification)"
  fi
}

# ==========================================================================
# rofi (the $mod+d app launcher)
# ==========================================================================
apply_rofi() {
  # Same split as polybar: config.rasi (the LAUNCHER LAYOUT) is hand-maintained
  # and @imports colors.rasi (the PALETTE) + catppuccin-default.rasi (styling).
  # We refresh the vendored styling/palettes and write colors.rasi to point at
  # the chosen flavor. The hand-maintained config.rasi is left untouched.
  if [ ! -f "$ROFI_DIR/config.rasi" ]; then
    echo "   [rofi] skip: $ROFI_DIR/config.rasi not found (no rofi config installed)" >&2
    return
  fi
  if [ ! -d "$ROFI_SRC_DIR" ]; then
    echo "   [rofi] skip: vendored themes not found at $ROFI_SRC_DIR" >&2
    return
  fi

  # Refresh vendored palettes + the pristine Catppuccin styling into the config
  # dir so @import can resolve them by name (cheap, keeps them in sync).
  cp -f "$ROFI_SRC_DIR"/catppuccin-*.rasi "$ROFI_DIR"/

  backup "$ROFI_COLORS"
  printf '/* AUTO-GENERATED by apply-theme.sh — selects the Catppuccin flavor. */\n@import "catppuccin-%s"\n' "$FLAVOR" > "$ROFI_COLORS"
  echo "   [rofi] wrote $ROFI_COLORS (flavor = $FLAVOR)"
  # rofi reads its config fresh on every launch — nothing to reload.
}

# ==========================================================================
# yazi (terminal file manager)
# ==========================================================================
apply_yazi() {
  # yazi's themes are complete theme.toml files (one per flavor+accent), each
  # pointing its `syntect_theme` at ~/.config/yazi/Catppuccin-<flavor>.tmTheme
  # for code-preview syntax colors. Copy the chosen flavor's theme to theme.toml
  # and drop in the matching tmTheme. Both vendored (catppuccin/yazi + bat).
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
# GTK (apps like nm-applet, pavucontrol, file dialogs)
# ==========================================================================
apply_gtk() {
  # Prebuilt Catppuccin GTK themes are vendored as zips (the upstream repo is
  # archived; no build needed). Install the chosen flavor if absent, then
  # activate it. Under i3 there's no settings daemon, so gtk-3.0/settings.ini is
  # authoritative; we also set gsettings and link the GTK4/libadwaita css.
  local theme="catppuccin-${FLAVOR}-${GTK_ACCENT}-standard+default"
  local dest="$GTK_THEMES_DEST/$theme"
  local zip="$GTK_THEMES_SRC/$theme.zip"

  if [ ! -d "$dest" ]; then
    if [ -f "$zip" ]; then
      mkdir -p "$GTK_THEMES_DEST"
      if command -v unzip >/dev/null 2>&1; then
        unzip -oq "$zip" -d "$GTK_THEMES_DEST"
      else
        python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$zip" "$GTK_THEMES_DEST"
      fi
      echo "   [gtk] installed $theme"
    else
      echo "   [gtk] skip: $theme not installed and no vendored zip at $zip" >&2
      return
    fi
  fi

  # latte is the only light flavor; the rest are dark.
  local prefer_dark=1 scheme='prefer-dark'
  [ "$FLAVOR" = latte ] && { prefer_dark=0; scheme='prefer-light'; }

  # Keep the existing icon theme (Papirus-Dark if installed, else whatever's set).
  local icon_theme="Adwaita"
  [ -d "$GTK_THEMES_DEST/../icons/Papirus-Dark" ] || [ -d "/usr/share/icons/Papirus-Dark" ] && icon_theme="Papirus-Dark"

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null || true
  fi

  mkdir -p "$HOME/.config/gtk-3.0"
  backup "$HOME/.config/gtk-3.0/settings.ini"
  cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
# AUTO-GENERATED by ~/setup/apply-theme.sh — Catppuccin $FLAVOR ($GTK_ACCENT accent).
# Under i3 there's no settings daemon, so GTK3 reads this file directly.
gtk-theme-name=$theme
gtk-application-prefer-dark-theme=$prefer_dark
gtk-icon-theme-name=$icon_theme
gtk-cursor-theme-name=Adwaita
EOF
  echo "   [gtk] set gtk-theme = $theme (icons: $icon_theme)"

  # GTK4 / libadwaita apps read ~/.config/gtk-4.0/gtk.css.
  if [ -d "$dest/gtk-4.0" ]; then
    mkdir -p "$HOME/.config/gtk-4.0"
    ln -sf "$dest/gtk-4.0/gtk.css"      "$HOME/.config/gtk-4.0/gtk.css"
    ln -sf "$dest/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
    ln -sf "$dest/gtk-4.0/assets"       "$HOME/.config/gtk-4.0/assets"
  fi
  echo "   [gtk] (restart GTK apps — incl. nm-applet/brave — to pick it up)"
}

# ==========================================================================
# Neovim (LazyVim + catppuccin/nvim)
# ==========================================================================
apply_nvim() {
  # Three layers, like tmux (bootstrap + seed + theme):
  #   1. BOOTSTRAP the LazyVim starter into ~/.config/nvim if absent (so a fresh
  #      box is one-command). Skipped (with a hint) when git is missing.
  #   2. SEED our vendored config — keymaps/options/lsp/formatting from
  #      ~/setup/nvim — only when the live file is ABSENT or still the pristine
  #      LazyVim stub (a comments-only options.lua/keymaps.lua). Never clobbers a
  #      file you've put real code in (same "seed, don't own" rule as tmux).
  #   3. THEME: regenerate plugins/colorscheme.lua selecting catppuccin + the
  #      flavour (this file IS owned — rewritten every run, like i3 colors.conf).
  # Also bootstraps the global `ruby-lsp` gem (non-fatal) so the Ruby LSP works.
  # NOTE: ruby-lsp also needs libpq-dev to build the `pg` gem in Rails projects —
  # that's an apt package (root), documented in setup.txt; not installable here.

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
  # _nvim_has_code: true when the file has a non-blank, non-`--`-comment line.
  _nvim_has_code() {
    awk '{ l=$0; sub(/^[[:space:]]+/,"",l); if (l=="") next; if (l ~ /^--/) next; c=1 }
         END { exit (c?0:1) }' "$1"
  }
  _nvim_seed() { # <relative-path under ~/setup/nvim and ~/.config/nvim>
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
      transparent_background = true,
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
  # tmux is the one exception to the Catppuccin rule: the config is themed
  # Rose Pine (moon), ported as-is from the old machine. There's no palette line
  # to rewrite for $FLAVOR — switching Catppuccin flavors leaves tmux alone.
  # Same "seed + bootstrap, never clobber" model as dunst's layout / gtk's zip:
  #   * seed ~/.tmux.conf from the vendored ~/setup/tmux/tmux.conf if ABSENT
  #     (after that it's yours; this never overwrites a living config)
  #   * bootstrap TPM + the rose-pine plugin (+ resurrect/continuum/sensible) so
  #     the theme and session-persistence work on a fresh box
  #   * reload a running tmux server in place
  if ! command -v tmux >/dev/null 2>&1; then
    echo "   [tmux] WARNING: tmux not on PATH — install it first (e.g. apt-get install tmux)" >&2
  fi
  if [ ! -f "$TMUX_SRC" ]; then
    echo "   [tmux] skip: vendored config not found at $TMUX_SRC" >&2
    return
  fi

  # --- seed the live config (never clobber an existing one) -----------------
  # No backup() here: this only ever writes when the file is ABSENT, so there's
  # never an existing config to overwrite (hence no .bak, unlike the others).
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

  # --- bootstrap the plugins so the theme renders ---------------------------
  # The config loads rose-pine via an explicit run-shell pointing at
  # ~/.tmux/plugins/rose-pine-tmux, and the rest via TPM (run '.../tpm/tpm').
  # TPM auto-sources any declared @plugin it finds on disk, so we just clone each
  # to the path the config/TPM expects. All idempotent + non-fatal: a fresh box
  # gets a working theme in one run; offline, it skips with a hint.
  if command -v git >/dev/null 2>&1; then
    mkdir -p "$TMUX_PLUGIN_DIR"
    local clone_failed=0
    _tmux_clone() { # <dir-name> <repo-url>
      local dir="$TMUX_PLUGIN_DIR/$1"
      [ -d "$dir" ] && { echo "   [tmux] plugin present: $1"; return; }
      if git clone --depth 1 -q "$2" "$dir" 2>/dev/null; then
        echo "   [tmux] cloned $1"
      else
        echo "   [tmux] WARNING: could not clone $1 ($2) — offline? finish later with prefix + I" >&2
        clone_failed=1
      fi
    }
    # rose-pine MUST land in rose-pine-tmux to match the config's run-shell path.
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

  # --- reload a running server ----------------------------------------------
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
    i3|zsh|starship|btop|polybar|dunst|rofi|yazi|gtk|nvim|tmux) "apply_$ONLY" ;;
    *)
      echo "error: unknown component '$ONLY' (expected one of: i3 zsh starship btop polybar dunst rofi yazi gtk nvim tmux)" >&2
      exit 1
      ;;
  esac
else
  apply_i3
  apply_zsh
  apply_starship
  apply_btop
  apply_polybar
  apply_dunst
  apply_rofi
  apply_yazi
  apply_gtk
  apply_nvim
  apply_tmux
fi

echo ">> Done."
