# setup

Personal desktop setup for **Debian + i3 (Xorg)** — a one-command bootstrap of the
whole environment (window manager, terminal, shell, editor, bars, themes) onto a
fresh box, plus a re-runnable Catppuccin theming engine. Two scripts:

- **[`install.sh`](#install-fresh-debian-box)** bootstraps a *fresh Debian box*:
  installs the apt packages and the non-apt bits (Meslo Nerd Font, oh-my-zsh,
  starship, mise+ruby, yazi, …), copies the hand-maintained layout (i3 config +
  scripts, polybar, rofi, alacritty, picom, the home dotfiles) into place, then
  runs `apply-theme.sh`.
- **[`apply-theme.sh`](#usage)** is the theming engine — it applies a
  [Catppuccin](https://github.com/catppuccin)
flavor to **i3**, **zsh-syntax-highlighting**, **Starship** (shell prompt),
**btop**, **polybar** (status bar), **dunst** (notification popups),
**rofi** (app launcher), **yazi** (file manager), **GTK** (nm-applet / dialogs),
and **Neovim (LazyVim)** from one command. It also seeds a ported **tmux** config
(themed [Rosé Pine](https://github.com/rose-pine/tmux), moon — independent of the
Catppuccin flavor).

## Install (fresh Debian box)

```bash
git clone https://github.com/alejandrok5/setup.git ~/setup
cd ~/setup
./install.sh                 # or: ./install.sh mocha  (latte | frappe | macchiato | mocha)
```

`install.sh` is idempotent and safe to re-run; it backs up anything it overwrites
to `.bak`, and treats the optional/network steps (ueberzugpp, i3lock-color,
Spotify) as non-fatal. It needs `sudo` for the apt/system steps and will prompt
for it. After it finishes, **log out and back into the i3 session** so the new
shell, `~/.xprofile` env vars, and group changes take effect.

It deliberately leaves a few **machine-specific** things for you to set by hand:

- **Monitor profiles** — autorandr profiles are EDID-matched to specific displays
  and don't transfer. Re-save from inside i3: `autorandr --save mobile`
  (see [External monitors](#external-monitors)).
- **HiDPI / resolution** — `~/.xprofile` pins this laptop's panel (eDP @ 2880×1800,
  `Xft.dpi=120` = 1.25×). Adjust the mode/DPI for your display
  (see [Display (HiDPI)](#display-hidpi)).
- **Accounts / secrets** — nothing here carries credentials; sign into Spotify,
  Wi-Fi, Bluetooth, etc. yourself.

Re-theme anytime with [`apply-theme.sh`](#usage) (below).

## Layout

```
setup/
├── install.sh                  # fresh-Debian bootstrap: packages + non-apt + dotfiles + theme
├── apply-theme.sh              # apply a Catppuccin flavor across the desktop (see Usage)
├── setup.txt                   # apt package list + manual-install notes (install.sh automates this)
├── README.md                   # this file
├── yazi-cheatsheet.md          # key bindings for the yazi file manager
├── displays-cheatsheet.md      # multi-monitor: hotplug / rotation / lid keys & commands
│
│   #  ── hand-maintained LAYOUT — copied into ~/.config + ~ by install.sh ──
├── i3/
│   ├── config                  # the i3 config (keybinds, autostart, window rules)
│   ├── scripts/                # lock.sh osd.sh touchpad.sh wallpaper.sh spotify.sh + py helpers
│   ├── wallpaper.jpg           # desktop background (feh --bg-fill)
│   ├── lock-image.png / lock-avatar.png   # spinning-avatar lock assets (i3lock-color)
│   └── themes/                 # vendored https://github.com/catppuccin/i3 palettes (apply-theme.sh)
├── polybar/
│   ├── config.ini  launch.sh   # bar layout + per-monitor launcher
│   ├── scripts/                # bluetooth.sh, powermenu.sh
│   └── themes/catppuccin-*.ini # palette sources (apply-theme.sh)
├── rofi/
│   ├── config.rasi             # launcher layout/behavior
│   └── catppuccin-*.rasi       # vendored catppuccin/rofi palettes + styling (apply-theme.sh)
├── alacritty/                  # alacritty.toml + catppuccin-{frappe,macchiato,mocha}.toml
├── picom/                      # picom.conf + shaders/ (lock.glsl spinning-orb lock shader)
├── home/                       # ~ dotfiles: .zshrc .xprofile .Xresources .profile .gitconfig
├── xdg-desktop-portal/         # portals.conf (force GTK file chooser for Brave/Chromium)
│
│   #  ── THEME sources — read by apply-theme.sh ──
├── zsh-syntax-highlighting/    # vendored https://github.com/catppuccin/zsh-syntax-highlighting
├── starship/                   # vendored official starship catppuccin-powerline preset (4 palettes)
├── btop/                       # vendored https://github.com/catppuccin/btop themes
├── dunst/                      # dunstrc layout template + catppuccin-*.conf palettes (drop-ins)
├── yazi/                       # vendored catppuccin/yazi themes (mauve) + tmThemes (catppuccin/bat)
├── gtk/                        # prebuilt Catppuccin GTK theme zips (upstream repo archived)
│
│   #  ── seed-once configs — bootstrapped by apply-theme.sh, then yours ──
├── nvim/                       # vendored LazyVim layer (options/keymaps/lsp/formatting)
├── tmux/                       # tmux.conf — Rosé Pine (moon), flavor-independent
│
│   #  ── system / hardware ──
├── xorg/                       # 90-natural-scrolling.conf (BT mouse → /etc/X11/xorg.conf.d)
└── displays/                   # multi-monitor: install.sh, postswitch, rotate.sh, i3-rotate-mode.conf
```

The `i3/`, `zsh-syntax-highlighting/`, `btop/`, `polybar/`, `dunst/`, `rofi/`,
`yazi/`, and `gtk/` directories hold the palette/theme **sources** (upstream
Catppuccin repos, or prebuilt zips for GTK); `apply-theme.sh` reads from them, so
they are the source of truth for the colors. The hand-maintained **layout** files
(the i3 `config` + `scripts/`, polybar `config.ini`/`launch.sh`, rofi `config.rasi`,
alacritty, picom, and the `home/` dotfiles) are vendored here too and copied into
`~/.config`/`~` by `install.sh` — but `apply-theme.sh` still only ever *themes*
them, never overwrites them (it writes the generated palette files alongside:
`colors.conf`, `colors.ini`, `theme.toml`, …). **dunst is the one exception:**
its layout (`dunstrc`) is a standard one, so it's vendored as a *template* in
`dunst/dunstrc` and installed to `~/.config/dunst/` only when absent — never
overwriting a customized one, so the same "don't clobber the layout" rule holds.
**Neovim follows the same "seed, don't own" rule as tmux.** The distro is
[LazyVim](https://www.lazyvim.org); the script **bootstraps** it (clones the
starter) if `~/.config/nvim` is absent, then **seeds** the vendored config in
`nvim/` (keymaps, options, the LSP + formatting specs) — only when the live file
is missing or still a pristine LazyVim stub, so your edits are never clobbered.
The colorscheme spec is the one **owned** file (regenerated each run, like i3's
`colors.conf`); [catppuccin/nvim](https://github.com/catppuccin/nvim) itself is
fetched by `lazy.nvim` on first launch. Keymaps are ported from an old NvChad
setup (leader = `\`) — see **[Neovim](#neovim-lazyvim)** below.
**Starship follows the same "theme it, don't own it" rule as polybar/rofi/dunst.**
Your living config is `~/.config/starship.toml` — hand-maintained, never clobbered.
The kit's `starship/catppuccin-powerline.toml` (a vendored copy of the official
[catppuccin-powerline](https://starship.rs/presets/catppuccin-powerline) preset,
which already embeds all four palettes) is only a **first-run seed**, installed
when `~/.config/starship.toml` is absent — exactly like dunst's `dunstrc` template.
On every later run the script touches **only the `palette =` line** in place
(btop-style), so switching flavor keeps all your prompt edits.

**tmux is the one non-Catppuccin component.** Its config is themed
[Rosé Pine](https://github.com/rose-pine/tmux) (moon), ported as-is from an older
machine, so there's no flavor to switch — `apply-theme.sh` ignores the flavor arg
for tmux. `tmux/tmux.conf` is a **first-run seed**: copied to `~/.tmux.conf` only
when that's absent (same "don't clobber" rule), never overwriting a living config.
The script also bootstraps [TPM](https://github.com/tmux-plugins/tpm) plus the
rose-pine / resurrect / continuum / sensible plugins into `~/.tmux/plugins` (via
`git clone`, idempotent, skipped when present or offline) so the theme **and**
session-persistence work on a fresh box, then reloads any running server.

> **Selecting text:** mouse mode is on (so the wheel scrolls tmux's scrollback
> and panes stay clickable/resizable). To select the native way — like before
> tmux — **hold `Shift` while dragging**: Alacritty bypasses tmux's mouse grab,
> so the selection goes to PRIMARY (middle-click pastes) and `Ctrl+Shift+C` /
> `Ctrl+Shift+V` copy/paste the clipboard as usual.

## Usage

```bash
./apply-theme.sh [flavor] [component]   # flavor:    latte | frappe | macchiato | mocha (default: macchiato)
                                        # component: optional — re-theme just ONE target instead of all
                                        #            (i3 zsh starship btop polybar dunst rofi yazi gtk nvim tmux)
```

Examples:

```bash
./apply-theme.sh mocha                 # switch everything to Mocha
./apply-theme.sh                       # re-apply Macchiato (the default)
./apply-theme.sh macchiato starship    # repaint ONLY the prompt — no i3 restart, no other apps touched
```

Re-running is safe and idempotent — switch flavors as often as you like. The
optional second argument is handy for iterating on one target (e.g. the prompt)
without reloading i3/polybar/dunst.

### What it changes

| Target | File | Action |
| --- | --- | --- |
| i3 | `~/.config/i3/colors.conf` | regenerated: palette **+** window/bar color rules (auto-generated, backup at `.bak`) |
| i3 | running session | `i3-msg restart` if i3 is up and the config validates |
| zsh | `~/.zsh/catppuccin_<flavor>-zsh-syntax-highlighting.zsh` | copied in |
| zsh | `~/.zshrc` | a managed block (between `>>> catppuccin … >>>` markers) sources the theme then the plugin (backup at `.bak`) |
| starship | `~/.config/starship.toml` | **seeded** from the vendored `catppuccin-powerline` preset only if absent; if it already exists, **only** the `palette =` line is rewritten in place to `catppuccin_<flavor>` (btop-style), leaving your layout/edits intact (backup at `.bak`). Hand-maintained — yours to edit |
| starship | `~/.zshrc` | blanks `ZSH_THEME` and adds a managed block (between `>>> starship prompt >>>` markers) that runs `eval "$(starship init zsh)"` — after oh-my-zsh, before the syntax-highlighting block (backup at `.bak`) |
| btop | `~/.config/btop/themes/catppuccin_<flavor>.theme` | copied in |
| btop | `~/.config/btop/btop.conf` | `color_theme` line set to `catppuccin_<flavor>` (backup at `.bak`) |
| polybar | `~/.config/polybar/colors.ini` | copied from `polybar/themes/catppuccin-<flavor>.ini`; live-reloads running bars over IPC. Layout (`config.ini`) untouched |
| dunst | `~/.config/dunst/dunstrc.d/catppuccin.conf` | copied from `dunst/themes/catppuccin-<flavor>.conf`; live-reloads the daemon with `dunstctl reload` (backup at `.bak`). Layout (`dunstrc`) installed from the vendored template only if absent, else untouched |
| rofi | `~/.config/rofi/colors.rasi` | written to `@import "catppuccin-<flavor>"`; vendored palettes + `catppuccin-default.rasi` refreshed into the config dir. Layout (`config.rasi`) untouched |
| yazi | `~/.config/yazi/theme.toml` + `Catppuccin-<flavor>.tmTheme` | copies the flavor's theme (mauve accent) + its tmTheme (code-preview syntax colors). Reopen yazi to see it |
| GTK | `~/.config/gtk-3.0/settings.ini`, gsettings, GTK4 css | installs the prebuilt theme zip if missing, then sets gtk-theme / color-scheme / icon-theme (mauve accent, Papirus-Dark icons) |
| nvim | `~/.config/nvim` | **bootstrapped**: clones the LazyVim starter here if absent (needs git), so a fresh box is one-command |
| nvim | `lua/config/{options,keymaps}.lua`, `lua/plugins/{lsp,formatting}.lua` | **seeded** from `nvim/` only if absent or a pristine LazyVim stub (comments-only) — never clobbers files you've put real code in. Carries leader = `\`, the ported NvChad keymaps, and the Ruby/LSP + formatter specs |
| nvim | global `ruby-lsp` gem | `gem install ruby-lsp` if missing (non-fatal) so the Ruby LSP attaches |
| nvim | `~/.config/nvim/lua/plugins/colorscheme.lua` | regenerated (owned): LazyVim spec that adds `catppuccin/nvim`, pins `flavour`, sets it as the colorscheme, and enables `transparent_background` (backup at `.bak`) |
| tmux | `~/.tmux.conf` | **seeded** from the vendored `tmux/tmux.conf` (Rosé Pine, moon) only if absent, with a 3-line provenance header; if it already exists, **left untouched** (so no `.bak`). Ignores the flavor arg — yours to edit |
| tmux | `~/.tmux/plugins/*` | bootstraps TPM + rose-pine + resurrect/continuum/sensible via `git clone` (idempotent; skipped if present or offline). Reloads a running server with `tmux source-file` |

After a zsh change (including the Starship prompt), run `exec zsh` (or open a new
shell) to see it. After a btop
change, restart btop. After an nvim change, restart Neovim (lazy.nvim installs
and recompiles catppuccin on launch). polybar and dunst live-reload themselves
(`dunstctl reload`); rofi re-reads its config on the next launch; restart GTK apps
(incl. nm-applet / Brave) to pick up the new theme.

## How it's wired (and the gotchas)

Two non-obvious things this script exists to get right:

1. **i3 palette and rules must live in the *same* file.**
   i3 only substitutes `$variables` within a single physical file. The intuitive
   split — a palette file `include`d from `colors.conf` — leaves every `$base`,
   `$lavender`, etc. **unresolved**, and i3 silently falls back to its default
   grey. So `apply-theme.sh` writes the chosen palette *and* the `client.*` /
   `bar {}` rules into `colors.conf` together.

   Your main `~/.config/i3/config` must contain:
   ```
   include ~/.config/i3/colors.conf
   ```
   and must **not** have its own `bar {}` block — the themed bar (with
   `status_command i3status`) is defined inside `colors.conf`, so a second
   `bar {}` would give you two bars. The script warns if it finds either issue.

2. **zsh: theme before plugin, plugin last.**
   The Catppuccin theme sets `ZSH_HIGHLIGHT_STYLES`, so it must be sourced
   *before* `zsh-syntax-highlighting.zsh`, and the plugin must be the last thing
   sourced in `.zshrc`. The managed block at the end of `.zshrc` enforces both.

3. **btop: theme name in `btop.conf`, file in the themes dir.**
   btop's `color_theme` takes the theme's *name without the `.theme` extension*
   (e.g. `catppuccin_macchiato`), resolved from `~/.config/btop/themes` (then the
   system themes dir). So the script copies the `.theme` file into that dir *and*
   rewrites the `color_theme = "…"` line in `btop.conf`. If `btop.conf` doesn't
   exist yet, a one-line file with just `color_theme` is enough — btop fills in
   defaults for every other key on next launch (and will expand the file). btop
   reads its theme only at startup, so restart it to see a change.

4. **nvim: bootstrap + seed + an owned theme spec.**
   On a fresh box (`~/.config/nvim` absent) the script clones the LazyVim starter
   first, so it's truly one-command. It then **seeds** the vendored config files
   from `nvim/` using a stub test: a file is replaced only if it's absent or has
   no non-comment code (the LazyVim starter ships `config/options.lua` and
   `config/keymaps.lua` as comments-only stubs — those get replaced; once you add
   real code they're left alone forever). The theme itself is the one **owned**
   file — `lua/plugins/colorscheme.lua`, rewritten each run with two specs: one
   adds `catppuccin/nvim` and pins `opts.flavour`, the other sets `LazyVim`'s
   `colorscheme = "catppuccin"`. Both must be present — pinning the flavour
   without selecting catppuccin as the colorscheme leaves LazyVim on its default
   theme. catppuccin compiles/caches its theme, so the new flavour shows after
   the next `nvim` launch, not live in a running session.

5. **dunst: colors in a drop-in that overrides the layout.**
   dunst reads `~/.config/dunst/dunstrc` first, then every
   `~/.config/dunst/dunstrc.d/*.conf` in alphabetical order, with later keys
   winning. So `apply-theme.sh` drops the palette into
   `dunstrc.d/catppuccin.conf` (background/foreground/frame_color per urgency)
   and leaves the hand-tuned `dunstrc` for layout only — the drop-in's colors
   override anything in the layout. This is what keeps the same layout/palette
   split as polybar without dunst supporting `include`. The catch: don't set
   colors in `dunstrc`, or they'll fight the drop-in (the drop-in wins, but it's
   confusing). `dunstctl reload` re-reads both, so re-theming is live.

6. **starship: the prompt, not the plugins — ordering and `PATH` both matter.**
   Starship replaces only the *prompt*, so the script sets `ZSH_THEME=""` (oh-my-zsh
   stops drawing one) and leaves `plugins=(…)` alone — every oh-my-zsh plugin,
   completion and keybinding keeps working. The init has to land **after**
   `source $ZSH/oh-my-zsh.sh` (so Starship wins the prompt) but **before** the
   zsh-syntax-highlighting block (which must still be sourced last), so the managed
   block is inserted right after the oh-my-zsh line. One subtlety: Starship installs
   to `~/.local/bin`, which this `.zshrc` only adds to `PATH` *further down* — so the
   block prepends that dir itself when `starship` isn't already on `PATH`. Without
   that, `command -v starship` would fail at init time and the prompt would silently
   never load. The default look is the official
   [catppuccin-powerline](https://starship.rs/presets/catppuccin-powerline) preset
   (OS icon → user → directory → git → languages → time). It's only a **seed**: the
   script writes `~/.config/starship.toml` from the vendored preset *once* (when the
   file is absent), then never owns it again — on later runs it rewrites only the
   `palette =` line to the active flavor, so your edits to the living config survive.
   The vendored seed is the pristine preset, so it's trivial to re-sync with upstream
   (`starship preset catppuccin-powerline -o starship/catppuccin-powerline.toml`) and
   to bootstrap a fresh machine.

## Requirements

- `i3` (the `i3` and `i3-msg` binaries) for the i3 part.
- The `zsh-syntax-highlighting` plugin at
  `/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh`
  (Debian/Ubuntu: `sudo apt-get install zsh-syntax-highlighting`).
- `btop` for the btop part (Debian/Ubuntu: `sudo apt-get install btop`). No
  config has to pre-exist — the script creates `~/.config/btop/` as needed.
- `dunst` (ships `dunstctl`) for the notifications part (Debian/Ubuntu:
  `sudo apt-get install dunst`; needs dunst ≥ 1.7 for `dunstrc.d` drop-ins). No
  config has to pre-exist — the script installs the vendored layout template and
  creates `~/.config/dunst/` as needed.
- **Neovim ≥ 0.11** and **git** for the nvim part. The script **bootstraps**
  [LazyVim](https://www.lazyvim.org) itself (clones the starter into
  `~/.config/nvim` if absent), then seeds the vendored config and fetches plugins
  via `lazy.nvim` on the next launch — so no manual LazyVim install is needed
  (offline, it skips the clone with a hint). For the **Ruby LSP**: a Ruby
  toolchain (this setup uses [mise](https://mise.jdx.dev)) so `gem` is on PATH —
  the script then `gem install ruby-lsp` if it's missing. Ruby projects that use
  the `pg` gem also need the PostgreSQL client headers to build it:
  `sudo apt-get install libpq-dev build-essential` (see `setup.txt`). Without
  those, ruby-lsp still starts but its per-project bundle won't build.
- **Starship** for the prompt — install the binary once, no sudo:
  `curl -fsSL https://starship.rs/install.sh | sh -s -- -b ~/.local/bin -y`. The
  script still writes `~/.config/starship.toml` and wires `.zshrc` if it's missing,
  but warns, since the prompt can't load until the binary exists. Needs a Nerd Font
  in the terminal for the powerline glyphs and icons (see **Fonts** — already met).
- **tmux** (Debian/Ubuntu: `sudo apt-get install tmux`) and **git** (to clone the
  plugins). No config has to pre-exist — the script seeds `~/.tmux.conf` and clones
  TPM + rose-pine into `~/.tmux/plugins`. The Rosé Pine status line uses the same
  Nerd Font glyphs (see **Fonts**); the mouse copy-to-clipboard binding uses
  `xclip` (`sudo apt-get install xclip`). Offline, plugin clones are skipped with a
  hint to finish later with `prefix` (`C-a`) `+ I`.

The script skips a target and prints a warning if its prerequisites are missing,
rather than failing the whole run.

## Fonts

The terminal and window-manager font is **Meslo Nerd Font** (the patched
Nerd Fonts build of Meslo LG, with Powerline/icon glyphs). The `.ttf` files
live in `~/.local/share/fonts/` (from the
[Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) release); run
`fc-cache -f` after adding fonts and confirm with `fc-list | grep -i meslo`.

This is **not** wired into `apply-theme.sh` — it's a one-time, by-hand config in
two places:

| Target | File | Setting |
| --- | --- | --- |
| Alacritty | `~/.config/alacritty/alacritty.toml` | `[font]` family `MesloLGS Nerd Font Mono`, size 12 (Regular/Bold/Italic/Bold-Italic) |
| i3 | `~/.config/i3/config` | `font pango:MesloLGS Nerd Font 12` (window titles + bar) |

Two deliberate variant choices:

- **Alacritty → `Mono`.** The fixed-width `MesloLGS Nerd Font Mono` is the right
  pick for a terminal grid.
- **i3 → standard (non-Mono).** i3's `font` drives UI chrome (title bars and the
  i3bar via pango), so the proportional `MesloLGS Nerd Font` reads better there
  while still carrying the Nerd Font glyphs i3status/the bar may emit.

Alacritty hot-reloads its config; for i3, reload with `$mod+Shift+R` or
`i3-msg restart`.

> Note: `~/.config/alacritty/alacritty.toml` also pulls its Catppuccin colors via
> `general.import` of a `catppuccin-<flavor>.toml` file — that part is edited by
> hand too and is independent of `apply-theme.sh`.

## Display (HiDPI)

Under the i3 (Xorg) session the panel (`eDP-1`) runs at **2880×1800** — *not* the
4608×2880 that XWayland reports inside GNOME (don't trust that number for the i3
setup; check with `xrandr` from within i3). GNOME drives this same 2880×1800 mode
at **scale 1.25** (→ **2304×1440** logical, per `~/.config/monitors.xml`). i3 does
no scaling on its own, so without this everything is small.

To match GNOME we target **1.25× scaling**. Because 1.25 is *fractional*, X11's
integer `GDK_SCALE` (only 1×, 2×, …) can't express it — `GDK_SCALE=2` overshoots
and makes UIs huge. Instead we scale through **font DPI** (`Xft.dpi = 96 × 1.25 =
120`), which Xft/GTK/Qt/Chromium all honor fractionally. Like the fonts, this is
**not** part of `apply-theme.sh` — it's by-hand config in three files:

| File | Purpose |
| --- | --- |
| `~/.Xresources` | `Xft.dpi: 120` (96×1.25), Xft antialias/hint settings, `Xcursor.size: 30` |
| `~/.xprofile` | sourced by GDM for the Xorg session: sets the 2880×1800 mode, `xrdb -merge`es `.Xresources`, and exports `QT_AUTO_SCREEN_SCALE_FACTOR=1`, `XCURSOR_SIZE=30`, `_JAVA_OPTIONS` uiScale=1.25. **No `GDK_SCALE`** (integer-only; would overshoot) |
| `~/.config/i3/config` | `exec_always` lines re-running `xrandr --mode 2880x1800` + `xrdb -merge` as a backup in case the DM doesn't source `~/.xprofile` (idempotent) |

Notes / gotchas:

- **Don't use `GDK_SCALE` here.** It only does integer scaling, so 1.25× isn't
  possible with it — it jumps straight to 2× and oversizes GTK/Chromium UIs.
  Fractional scaling on X11 goes through `Xft.dpi` instead. The tradeoff: GTK
  *fonts* (and most em-based geometry) scale, but pixel-based icons stay 1× and
  look slightly small versus GNOME/Wayland's true fractional scaling.
- **`~/.xprofile` is GDM-specific-ish.** GDM/LightDM/SDDM source it for *Xorg*
  sessions. If you switch display managers and scaling stops applying, that's the
  first thing to check (the i3 `exec_always` block still handles resolution + DPI,
  just not the env vars).
- **Legacy X11 apps** that ignore `Xft.dpi` will still render small — the known
  tradeoff of X11 HiDPI vs. GNOME/Wayland.
- **Chromium/Electron apps (Brave, VS Code, …)** auto-detect scale and can
  overshoot. Pin them explicitly — the i3 Brave binding launches with
  `--force-device-scale-factor=1.25`. Apply the same flag to other
  Chromium/Electron launchers if they come up the wrong size.

Apply without a reboot: `xrdb -merge ~/.Xresources` then `i3-msg restart`. The
env vars only take effect on a fresh session (log out and back into i3).

### External monitors

Multi-monitor — hotplug, rotation, positioning, and clamshell — under i3/Xorg.
[`autorandr`](https://github.com/phillipberndt/autorandr) handles EDID-matched
profiles; `xrandr`/`arandr` handle one-offs; an i3 **rotate mode** handles
rotation. Quick key/command reference:
**[`displays-cheatsheet.md`](displays-cheatsheet.md)**. The source-of-truth files
and a rebuild script live in **`~/setup/displays/`** — reinstall any time with:

```bash
~/setup/displays/install.sh        # idempotent; sudo for the system fallbacks
```

**Output names (amdgpu):** `eDP` (laptop), `DisplayPort-0`, `DisplayPort-1`,
`HDMI-A-0`. The `eDP` 2880×1800 mode is set by `~/.xprofile`, independent of
autorandr.

**Hotplug.** autorandr's packaged udev rule starts `autorandr.service` on any DRM
change; the lid is watched by `autorandr-lid-listener.service` (libinput switch
events). Both auto-apply the saved profile whose EDIDs match the connected
outputs. The stock units fall back to `--default default` — a profile that
**doesn't exist**, so an unsaved monitor stayed blank. `displays/install.sh` drops
in systemd overrides changing the fallback to the built-in **`horizontal`**
(extend left-to-right), so *any* new monitor lights up even with no saved
profile. The i3 config also runs `autorandr --change` at startup and on
**`$mod+p`** (manual re-detect), falling back to the `mobile` profile.

**Profiles** — save once, from inside the i3/Xorg session (*not* GNOME, which
reports different output names). Arrange first, then snapshot:

```bash
autorandr --save mobile                          # laptop only
arandr  ->  drag/arrange  ->  autorandr --save dual-extend
```

Saved profiles auto-apply on hotplug by EDID match **and take priority over the
`horizontal` fallback**, so a saved combo works even without the system override.
Profiles live in `~/.config/autorandr/`. Names used here: `mobile`, `extend-1`,
`dual-extend`, `dock-1`/`dock-2` (clamshell).

**Rotation** — i3 **rotate mode** on **`$mod+o`** (then `↑`=normal, `↓`=inverted,
`←`/`→`=portrait). It calls `~/.config/i3/scripts/rotate.sh`, which rotates the
first external and **re-tiles every active output** in one `xrandr` call. The
re-tile matters: rotating one monitor changes its width, and naively
repositioning only that one can push a *third* monitor outside the framebuffer so
it collapses onto another's coordinates — i.e. the two screens **mirror**.
Re-laying out all of them avoids that. CLI for a specific output:
`rotate.sh DisplayPort-1 left`. The rotate-mode block isn't applied automatically
— hand-paste it into `~/.config/i3/config` from `displays/i3-rotate-mode.conf`
(`install.sh` warns if it's missing).

**Lid / clamshell.** With an external connected, closing the lid turns `eDP`
**off** and keeps the externals (autorandr marks the internal panel as
disconnected while the lid is shut, so `horizontal` drops it); opening the lid
brings it back. Undocked, lid-close **suspends** — logind defaults
(`HandleLidSwitch=suspend`, `HandleLidSwitchDocked=ignore`) already do the right
thing, so `logind.conf` is untouched. Needs the lid-listener override (installed
by `install.sh`).

**Wallpaper + bars on every switch.** `~/.config/autorandr/postswitch` re-runs
`wallpaper.sh` and `polybar/launch.sh` after every change (hotplug, lid, rotate),
since both are placed per-output. Two fixes keep that clean:

- **picom `use-damage = false`** (`~/.config/picom.conf`). The glx backend's
  partial repaints miscompute the damaged region on a *rotated* output, leaving
  the wallpaper **cut/stale**; full-frame repaints fix it. `install.sh` adds the
  line if absent (libconfig errors on a duplicate key, so it never doubles it).
- **polybar `launch.sh` flock.** Now that `postswitch` fires `launch.sh` on
  rotation/hotplug/lid, two runs can overlap and each spawn a full set of bars →
  **duplicate bars**. A `flock` serializes them (`install.sh` warns if missing).

Caveats:

- **DPI is global on X11.** An external inherits the laptop's `Xft.dpi=120`
  (1.25×); there's no per-monitor DPI. A ~96-DPI external looks oversized; a
  4K/HiDPI external matches well. Cleanest mixed-DPI docked layout: external as
  primary, or lid closed (clamshell) so there's no conflict.
- **Clamshell profiles must be saved with the lid shut.** autorandr drops `eDP`
  from the fingerprint when closed, so a `dock-*` saved lid-open won't match a
  real lid-close. Pause the watcher while saving:
  `sudo systemctl stop autorandr-lid-listener` → shut lid →
  `autorandr --save dock-1` → `… start …`.
- **Save from i3, not GNOME** — profiles capture session-specific output names.

## Media keys (volume / brightness / media)

Makes the laptop's `XF86` media keys behave like GNOME — volume, mic-mute,
brightness, and play/pause/next/prev — with an on-screen progress bar (OSD).
Like the fonts and DPI, this is **by-hand** config, not part of `apply-theme.sh`.

A single helper, `~/.config/i3/scripts/osd.sh`, runs the action and then shows a
GNOME-style OSD by sending a `dunst` notification with a progress-bar value
(`notify-send -h int:value:<pct>`, replacing in place via a stable id + stack
tag). The i3 `config` binds each `XF86` key to `osd.sh <action>`:

| Key(s) | Action | Tool |
| --- | --- | --- |
| `XF86AudioRaiseVolume` / `LowerVolume` | ±5%, capped at 100%, auto-unmute on raise | `wpctl` |
| `XF86AudioMute` | toggle sink mute | `wpctl` |
| `XF86AudioMicMute` | toggle source mute | `wpctl` |
| `XF86MonBrightnessUp` / `Down` | ±5% backlight (`amdgpu_bl0`) | `brightnessctl` |
| `XF86AudioPlay` / `Pause` / `Next` / `Prev` / `Stop` | media transport | `playerctl` |

Notes / gotchas:

- **PipeWire, not PulseAudio.** This machine runs PipeWire, so volume goes
  through `wpctl` (WirePlumber). The stock i3 config ships `pactl` bindings —
  those silently no-op here because `pactl` isn't installed. `wpctl` ships with
  `wireplumber` (already pulled in by PipeWire).
- **`brightnessctl` needs its udev rule for non-root writes.**
  `/sys/class/backlight/amdgpu_bl0/brightness` is root-owned; the
  `brightnessctl` package installs a udev rule granting the `video` group write
  access (the user is already in `video`). The rule applies on next login, or
  reload it now with
  `sudo udevadm control --reload-rules && sudo udevadm trigger`.
- **OSD is optional and never fatal.** `osd.sh` skips the notification if
  `notify-send` is missing, so volume/brightness still change even without the
  popup. The OSD needs `libnotify-bin` (the `notify-send` binary) plus a running
  notification daemon — here `dunst`.
- Volume steps are **5%** (GNOME-like); raising past 100% (over-amplification) is
  intentionally capped via `wpctl set-volume -l 1.0`.

Apply after editing: reload i3 with `$mod+Shift+r` (or `i3-msg restart`).

## Touchpad

macOS-trackpad-like libinput settings, applied by
`~/.config/i3/scripts/touchpad.sh` (run from i3 via `exec_always`, like
`osd.sh`). The script matches every device whose name contains `touchpad`, so
it survives xinput device-id changes and works across more than one touchpad:

| Setting | libinput property | Value | Effect |
| --- | --- | --- | --- |
| Natural (inverted) scroll | `Natural Scrolling Enabled` | `1` | content follows fingers |
| Tap-to-click | `Tapping Enabled` | `1` | 1-finger tap = left, **2-finger tap = right**, 3 = middle |
| Click method | `Click Method Enabled` | `0 1` (clickfinger) | **2-finger physical press = right**, 3 = middle |

The i3 config runs it on every (re)start:

```
exec_always --no-startup-id ~/.config/i3/scripts/touchpad.sh
```

Notes / gotchas:

- **Two ways to right-click, both two-finger.** Tapping gives `2-finger tap =
  right` via libinput's default button map (`lrm`); clickfinger gives `2-finger
  press = right`. Both are enabled so it works whether you tap or press.
- **clickfinger replaces button-areas.** With clickfinger on, the
  bottom-right-*corner* press is no longer a right-click — two fingers is. If
  you'd rather keep corner-click, drop the `Click Method Enabled` line from
  `touchpad.sh` (tapping still gives you two-finger-tap right-click).
- **No xorg.conf.d / no sudo.** This is done per-session via `xinput` rather
  than a `/etc/X11/xorg.conf.d/` snippet, so it needs no root and lives entirely
  in the i3 config. It applies inside the i3 session only (not the login
  greeter), which is all that's needed here.
- **Apply now without re-login:** `~/.config/i3/scripts/touchpad.sh` (or reload
  i3 with `$mod+Shift+r`).

## Mouse (natural scroll)

The Bluetooth mouse (Logitech MX Master 3S) gets the same natural (inverted)
scrolling as the touchpad — but via X, not the touchpad script. A BT mouse
connects *after* login and can disconnect/reconnect mid-session, so a
`exec_always` script (which only runs at i3 start) would miss it. Instead an
**Xorg InputClass** enables natural scrolling on every pointer the moment X adds
it, so reconnects are covered automatically:

```
# ~/setup/xorg/90-natural-scrolling.conf  →  MatchIsPointer "on" + NaturalScrolling
sudo install -Dm644 ~/setup/xorg/90-natural-scrolling.conf \
     /etc/X11/xorg.conf.d/90-natural-scrolling.conf
```

- Numbered `90-` so it's read after the distro default `40-libinput.conf` and wins.
- `MatchIsPointer "on"` targets mice (the touchpad already has it from
  `touchpad.sh`; setting it again is harmless).
- **Takes effect** on the next device connect or X restart (log out / back in).
  To set it for the current session without that, run:
  `xinput set-prop "Logitech MX Master 3S For Mac" "libinput Natural Scrolling Enabled" 1`.

## Wallpaper

The desktop background is set by `~/.config/i3/scripts/wallpaper.sh` (run from i3
via `exec_always`, like `osd.sh` / `touchpad.sh`). It runs `feh --bg-fill` on the
image at `~/.config/i3/wallpaper.jpg`:

```
exec_always --no-startup-id ~/.config/i3/scripts/wallpaper.sh
```

- **Requires `feh`:** `sudo apt install feh`. The script no-ops with a warning if
  feh (or the image) is missing, so it never breaks i3 startup.
- **`--bg-fill`** scales the image to cover the whole screen (cropping overflow),
  so it stays correct across resolution changes when you dock/undock.
- **To change the wallpaper:** replace `~/.config/i3/wallpaper.jpg` (any format feh
  reads works; the script's path ends in `.jpg` but feh keys off content, not
  extension). Then re-run the script or reload i3 with `$mod+Shift+r`.
- **Apply now without re-login:** `~/.config/i3/scripts/wallpaper.sh`.

## Lock screen (i3lock)

`~/.config/i3/scripts/lock.sh` locks with a **blurred, dimmed copy of the
wallpaper** (Catppuccin-tinted), instead of plain i3lock's white screen. Plain
i3lock can only show a solid colour or a PNG, so the script pre-renders
`wallpaper.jpg` → a blurred PNG cached at `~/.cache/i3lock-bg.png`, then runs
`i3lock -n -i` on it.

Wired into both lock paths:

```
# suspend / xss-lock
exec --no-startup-id xss-lock --transfer-sleep-lock -- ~/.config/i3/scripts/lock.sh
# pre-warm the cache at startup so the first lock is instant
exec --no-startup-id ~/.config/i3/scripts/lock.sh --prepare
```

The polybar powermenu's **Lock** entry also calls `lock.sh`.

- **Needs ImageMagick for the blur:** `sudo apt install imagemagick`, then build
  the cache once: `~/.config/i3/scripts/lock.sh --prepare`. **Without it the
  script still locks** — it falls back to a solid Catppuccin base (`#24273a`),
  so the lock never breaks.
- **Cache is self-healing.** Rebuilt only when the cache is missing, the
  wallpaper is newer, or the screen resolution changed (dock/undock) — detected
  via `xdpyinfo`. Normal locks reuse the cache and are instant.
- **Tuning** (in `lock.sh`): `-blur 0x10` = blur strength; `-colorize 35%` =
  how far it dims toward the base colour. Delete `~/.cache/i3lock-bg.png` (or
  run `--prepare`) after changing the wallpaper or these values.

## Transparency (compositor)

Alacritty's transparency is set in `~/.config/alacritty/alacritty.toml`
(`[window] opacity = 0.8`), **but on X11 that does nothing without a running
compositor** — the terminal can't blend with the wallpaper on its own. `picom`
provides that:

```
sudo apt install picom
```

i3 autostarts it (`exec`, not `exec_always`, so an in-place restart doesn't
spawn a second instance):

```
exec --no-startup-id picom --config ~/.config/picom.conf
```

`~/.config/picom.conf` is intentionally minimal — `glx` backend, vsync on,
**shadows and fades off** — so it only enables transparency and stays clean
against i3's gaps. To tune the terminal's see-through level, change `opacity`
in `alacritty.toml` (1.0 = opaque, 0.0 = invisible).

- **Start it now without re-login** (the `exec` line only runs at initial i3
  start): `picom --config ~/.config/picom.conf &`.

**btop** rides on the same compositor. With `theme_background = false` in
`~/.config/btop/btop.conf`, btop skips painting its own background, so the
transparent terminal (and the wallpaper) shows through. `apply-theme.sh`
sets this automatically alongside the btop color theme, so it survives a
flavour change. Note btop's options menu can toggle it back on (and it has
`save_config_on_exit = true`); re-run `apply-theme.sh` or flip the line to
restore transparency.

**nvim** (and **yazi**) ride on it too. The catppuccin nvim spec sets
`transparent_background = true` (written by `apply-theme.sh`), so nvim's editor
background drops out and the terminal's opacity shows through. yazi is themed
but draws its own panel backgrounds; it inherits the terminal opacity behind
them. Restart nvim after a re-theme — lazy.nvim recompiles catppuccin on launch.

## Status bar (polybar)

The status bar is **polybar**, not i3bar. It lives in `~/.config/polybar/`:

- **`config.ini`** — the bar **layout** (modules, fonts, position). Hand-maintained.
- **`colors.ini`** — the Catppuccin **palette**, `include`d by `config.ini`. This is
  the *only* polybar file `apply-theme.sh` touches: it copies the chosen flavour
  from `~/setup/polybar/themes/catppuccin-<flavour>.ini`. Same split as i3
  (`config` = layout, `colors.conf` = palette).
- **`launch.sh`** — kills any running bars, resolves the CPU temp sensor, then
  starts one `main` bar per connected monitor. i3 runs it via `exec_always`
  (safe across in-place restarts because it kills first):

  ```
  exec_always --no-startup-id ~/.config/polybar/launch.sh
  ```
- **`scripts/bluetooth.sh`** — Bluetooth status + click-to-toggle (`bluetoothctl`).
- **`scripts/powermenu.sh`** — rofi power menu (lock / suspend / logout / reboot /
  shutdown). No sudo: power actions go through `systemd-logind`.

Modules: i3 workspaces · window title · clock (center) · CPU · memory · CPU temp ·
volume · wifi (SSID+signal) · IP · Bluetooth · battery · **system tray** · powermenu.

**Gotchas / requirements:**
- **Replaces i3bar.** `apply-theme.sh` no longer emits a `bar {}` block into
  `colors.conf`; the i3 status bar is gone and `i3status` is unused.
- **CPU temp sensor:** hwmon numbers (`hwmon6`, …) shuffle across reboots, so
  `launch.sh` finds **k10temp** (the AMD CPU sensor) *by name* and passes its
  path to polybar via `POLYBAR_CPU_TEMP_PATH`. acpitz is skipped (reads bogus
  values on this machine). Tctl on Ryzen can read with an offset — the number is
  the sensor's, not a bug.
- **System tray is empty until a tray app runs.** `nm-applet` is **not installed**
  (`exec nm-applet` in the i3 config is currently a silent no-op). To get the
  network icon in the tray: `sudo apt install network-manager-gnome`. The polybar
  `wifi` module already shows SSID/signal without it.
- **Icons need a Nerd Font** (you have MesloLGS Nerd Font); `config.ini` uses it
  for both text and glyphs.
- **Re-theme:** `~/setup/apply-theme.sh <flavour>` rewrites `colors.ini` and
  live-reloads the bar over IPC (`polybar-msg cmd restart`).
- **Start it now without re-login:** `~/.config/polybar/launch.sh`.

## Notifications (dunst)

Desktop notification popups — the **"device connected"** toast from
`blueman`/`nm-applet`, the volume/brightness **OSD** (see "Media keys"), and any
`notify-send` — are drawn by **dunst**. They're themed Catppuccin so they match
the rest of the desktop instead of dunst's pale default. It lives in
`~/.config/dunst/`:

- **`dunstrc`** — the popup **layout** (geometry, font, timeouts, icons,
  behavior). Hand-maintained. Same split as polybar. A standard template is
  vendored at `~/setup/dunst/dunstrc`; `apply-theme.sh` installs it here **only
  if absent** and never overwrites your edits.
- **`dunstrc.d/catppuccin.conf`** — the Catppuccin **palette** (per-urgency
  background / foreground / frame color). The *only* dunst file
  `apply-theme.sh` writes: it copies the chosen flavour from
  `~/setup/dunst/themes/catppuccin-<flavour>.conf`. dunst loads `dunstrc` first
  then `dunstrc.d/*.conf` (later wins), so these colors override the layout.

The accent is **mauve** (matching i3 focus, the polybar workspace pill, rofi
selection, GTK, and yazi); **red** frames `urgency_critical`. Popups sit
top-right, offset down to clear the polybar.

**Gotchas / requirements:**
- **It was previously unthemed.** dunst ran with no config at all, so
  notifications used its compiled-in default look — the one thing the desktop
  never themed. This section is the fix.
- **Needs dunst ≥ 1.7** for the `dunstrc.d/` drop-in (this machine has 1.13).
  `notify-send` (from `libnotify-bin`) sends test notifications.
- **Don't put colors in `dunstrc`** — leave them to the drop-in, or the two
  fight (the drop-in wins, but it's confusing). Layout in `dunstrc`, colors in
  `dunstrc.d/`.
- **Re-theme:** `~/setup/apply-theme.sh <flavour>` rewrites
  `dunstrc.d/catppuccin.conf` and runs `dunstctl reload` — live, no restart.
- **Try it now:** `notify-send -u normal "Bluetooth" "WH-1000XM4 connected"`
  (add `-u critical` for the red frame).

## App launcher (rofi)

`$mod+d` opens **rofi** (replaces `dmenu_run`) as an icon'd application launcher.
It lives in `~/.config/rofi/`:

- **`config.rasi`** — launcher **layout + behavior** (modes, `show-icons`, icon
  theme, fonts, prompts). Hand-maintained. Same split as polybar.
- **`colors.rasi`** — one line, `@import "catppuccin-<flavour>"`. The *only* file
  `apply-theme.sh` writes; it selects the active Catppuccin palette.
- **`catppuccin-*.rasi`** — vendored from `~/setup/rofi/`: the four flavour
  **palettes** + `catppuccin-default.rasi` (the upstream **styling**, kept
  pristine). `apply-theme.sh` refreshes these into the config dir so `@import`
  resolves them by name.

`config.rasi` `@import`s the palette, then the styling, then overrides the
selection accent to **mauve** (upstream highlights in near-white) so it matches
the polybar workspace pill and the GTK theme.

Bound in the i3 config:

```
bindsym $mod+d exec --no-startup-id rofi -show drun
```

**Behavior:** `modes = "drun,window"` — `$mod+d` lists installed apps; **Tab**
switches to a window switcher. Icons come from `show-icons: true` +
`icon-theme: "Papirus-Dark"` (so the launcher needs the Papirus icon theme — see
"GTK apps" / `setup.txt`).

**Gotchas:**
- **rofi 2.0.0 renamed `modi` → `modes`** in `config.rasi`. Older rofi (1.7.x)
  wants `modi`; this machine has 2.0.0.
- **Re-theme:** `~/setup/apply-theme.sh <flavour>` rewrites `colors.rasi`. rofi
  reads its config fresh on every launch, so there's nothing to reload.
- The Catppuccin theme files come from the upstream `catppuccin/rofi` repo,
  vendored under `~/setup/rofi/` (no network needed at apply time).

## Spotify (`$mod+s`)

`$mod+s` opens **Spotify on workspace 10 and starts playback**, via
`~/.config/i3/scripts/spotify.sh`. (It replaces the old `layout stacking`
binding — tabbed/toggle-split layouts are still on `$mod+w` / `$mod+e`.)

Two pieces in the i3 config:

```
assign [class="Spotify"] number 10            # pin Spotify's window to ws10
bindsym $mod+s exec --no-startup-id ~/.config/i3/scripts/spotify.sh
```

The script switches to ws10, launches Spotify if it isn't already running
(otherwise just focuses it), waits for its **MPRIS** interface to register, then
sends `playerctl --player=spotify play`. Needs `playerctl` (already installed for
the media keys — see "Media keys").

**Gotcha — cold-start autoplay is best-effort.** Right after a fresh launch
Spotify has no play context loaded, so `playerctl play` can be a no-op. The
script waits for the player and retries, which covers most cases, but the very
first launch after a reboot may open without playing — press `$mod+s` again (now
that it's running) to start it.

## File manager (yazi)

**yazi** is the terminal file manager (replaces ranger), chosen for its fast,
async image previews. Key bindings reference: **[`yazi-cheatsheet.md`](yazi-cheatsheet.md)**.

- **Install (no sudo).** Not in Debian repos; the prebuilt binary lives in
  `~/.local/bin/` (`yazi` + `ya`):
  ```
  curl -fsSL -o /tmp/yazi.zip \
    https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
  unzip -j /tmp/yazi.zip '*/yazi' '*/ya' -d ~/.local/bin
  ```
- **Opens files in nvim.** yazi's default opener runs `$EDITOR`; `~/.zshrc`
  exports `EDITOR=nvim` (and `VISUAL`). That's the whole fix for the old
  "ranger opened nano" problem — `update-alternatives` still points `editor` at
  nano, but `$EDITOR` wins for yazi/ranger/git.
- **`y` wrapper.** `~/.zshrc` defines `y()` — runs yazi and `cd`s into the last
  directory on quit (`q`). Plain `yazi` also works.
- **`$mod+y`** opens yazi in a fresh Alacritty window (`bindsym $mod+y exec
  alacritty -e yazi` in the i3 config). Works because `~/.local/bin` is on i3's
  PATH via `~/.profile`.

**Theme.** Catppuccin (mauve accent), applied by `apply-theme.sh` along with
everything else — it copies the flavor's `theme.toml` and its
`Catppuccin-<flavor>.tmTheme` (syntax colors for code previews) into
`~/.config/yazi/`. Sources vendored in `~/setup/yazi/` (from
[catppuccin/yazi](https://github.com/catppuccin/yazi) +
[catppuccin/bat](https://github.com/catppuccin/bat)). Reopen yazi to see a change.

**Image preview in Alacritty — needs Überzug++.** Alacritty has no native
graphics protocol, so on X11 yazi overlays images via **`ueberzugpp`** (the C++
rewrite — *not* the older python `ueberzug` that's in apt; yazi only speaks to
ueberzugpp). It isn't packaged in Debian, so install the maintainer's `.deb`
(needs root):

```
curl -fsSL -o /tmp/ueberzugpp.deb \
  "https://download.opensuse.org/repositories/home:/justkidding/Debian_Unstable/amd64/ueberzugpp_2.9.10_amd64.deb"
sudo apt install /tmp/ueberzugpp.deb
```

yazi auto-detects it — no config needed. Until it's installed, previews show file
info but no image. Optional richer previews:
`sudo apt install ffmpegthumbnailer poppler-utils imagemagick chafa` (video
thumbnails · PDF · more image formats/SVG · `chafa` ASCII fallback). Already
present: `7z`, `jq`, `fd`, `rg`.

## GTK apps (nm-applet, dialogs, file pickers)

GTK programs — `nm-applet`'s menu, `pavucontrol`, file open/save dialogs — have
their own theme, independent of i3/polybar. They're set to **Catppuccin
`<flavour>`-mauve** via prebuilt themes (the upstream `catppuccin/gtk` repo is
archived, so its v1.0.3 release zips are **vendored** in `~/setup/gtk/themes/` —
no build, no sudo).

`apply-theme.sh` (`apply_gtk`) installs the chosen flavour into
`~/.local/share/themes` and activates it three ways, because under i3 there's no
settings daemon:

- **`~/.config/gtk-3.0/settings.ini`** (authoritative for GTK3) — `gtk-theme-name`,
  `gtk-icon-theme-name`, dark/light preference. *Auto-generated; don't hand-edit.*
- **`gsettings`** `org.gnome.desktop.interface` (gtk-theme / icon-theme / color-scheme).
- **`~/.config/gtk-4.0/gtk.css`** symlinked to the theme, for GTK4/libadwaita apps.

**Icons:** Papirus (`Papirus-Dark`), installed locally in `~/.local/share/icons`
(cloned from PapirusDevelopmentTeam, no sudo), with folders recoloured to
**violet** (closest stock match to Catppuccin mauve) via `papirus-folders`.

**Brave / Chromium file dialogs — the gotcha:** Chromium routes file dialogs
through `xdg-desktop-portal`. With `xdg-desktop-portal-gnome` installed, the
portal's file chooser is **libadwaita-based and ignores the GTK theme**, so Save
dialogs looked unthemed. Fix in `~/.config/xdg-desktop-portal/portals.conf`:

```
[preferred]
default=gtk
org.freedesktop.impl.portal.FileChooser=gtk
```

This forces the **GTK** file chooser (which honours the Catppuccin GTK3 theme).
Apply with `systemctl --user restart xdg-desktop-portal`, then **restart Brave**
(GTK apps read their theme at launch).

**Gotchas:**
- **Restart GTK apps** (nm-applet, brave, pavucontrol) after a theme change —
  they only read the theme at startup. `apply_gtk` can't do this for you.
- **latte** is the only light flavour; `apply_gtk` switches the scheme to
  `prefer-light` for it and `prefer-dark` for the rest.
- **Re-theme:** `~/setup/apply-theme.sh <flavour>` swaps the GTK theme, icon
  preference, and GTK4 link along with everything else.

## Neovim (LazyVim)

The editor is **[LazyVim](https://www.lazyvim.org)**, themed Catppuccin (the
flavour tracks `apply-theme.sh`; background is transparent so the terminal shows
through). Beyond the theme, the kit vendors a small config layer in `~/setup/nvim/`
and **seeds** it into `~/.config/nvim/` — only when a file is absent or still a
pristine LazyVim stub, never overwriting your edits (same rule as tmux):

| Seeded file | What it carries |
| --- | --- |
| `lua/config/options.lua` | **leader = `\`** (and localleader `\`), set early so every mapping picks it up |
| `lua/config/keymaps.lua` | keymaps ported from an old **NvChad v2.5** setup (see below) |
| `lua/plugins/lsp.lua` | LSP servers: `ruby_lsp`, `html`, `cssls`, `lua_ls`, plus `lspcontainers.nvim` |
| `lua/plugins/formatting.lua` | conform formatters: `stylua` / `rubocop` / `erb_formatter` / `prettier`, and Mason tools |

The colorscheme spec (`lua/plugins/colorscheme.lua`) is the only **owned** file —
regenerated each run; everything else is yours after the first seed.

**Keybindings (ported from NvChad, leader = `\`).** Most of the old muscle memory
was NvChad's *defaults*, recreated on LazyVim's equivalents:

| Key | Action | Notes |
| --- | --- | --- |
| `;` | command mode (`:`) | replaces `;` repeat-find |
| `jk` (insert) | escape | |
| `<C-n>` | file explorer toggle | NvimTree → **Snacks explorer** |
| `<leader>ff` `fw` `fb` `fo` `fz` `fa` | files / grep / buffers / recent / lines / all | Telescope → **Snacks picker** |
| `<Tab>` / `<S-Tab>` | next / prev buffer | bufferline; shadows `<C-i>` jump-forward |
| `<leader>x` | close buffer | `Snacks.bufdelete` (shadows the `<leader>x` trouble group) |
| `<A-i>` / `<A-h>` / `<A-v>` | float / horizontal / vertical terminal | nvchad.term → **Snacks terminal** |
| `<leader>/` | toggle comment · `<leader>fm` format · `<leader>gb` git blame | |

Group-prefix keys (`<leader>b`, `<leader>q`, `<leader>x`) run the NvChad action but
their LazyVim sub-menus stay reachable after the which-key timeout. Dropped (no
equivalent): NvChad's theme picker — the theme is fixed Catppuccin.

**Ruby tooling.** `ruby_lsp` runs the **globally-installed** `ruby-lsp` gem (the
script installs it if missing), not a `bundle exec` wrapper — it auto-composes a
project's bundle when a `Gemfile` is present and falls back to the file's dir
otherwise (correct for nvim 0.11's native LSP). Two real-world gotchas:

- **First open in a project is slow once** — ruby-lsp runs `bundle install` for
  its composed bundle (cached afterward into `.ruby-lsp/`).
- **The `pg` gem needs system headers.** In a Rails app, ruby-lsp's bundle build
  fails (`libpq-fe.h not found`) until `sudo apt-get install libpq-dev
  build-essential`, then `bundle install` in the project. This blocks the app's
  own bundle too, not just the LSP.

`lspcontainers.nvim` is vendored but **inert** (installed and `setup{}`, attached
to no server — exactly as in the old config); wire a server's `cmd` through
`require("lspcontainers").command("<server>")` to actually run it in Docker.

**Fresh machine:** `apply-theme.sh` clones LazyVim, seeds the above, installs
`ruby-lsp`, and pins the theme; first `nvim` launch installs all plugins. Restart
nvim after a re-theme (catppuccin recompiles on launch).

## Claude Code (launcher + PATH note)

**`$mod+c`** opens Claude Code in a fresh Alacritty window with permission
prompts skipped:

```
set $claude_dir $HOME
bindsym $mod+c exec --no-startup-id alacritty --working-directory $claude_dir -e claude --dangerously-skip-permissions
```

- **`$claude_dir`** is where it opens (Alacritty's `--working-directory`).
  Defaults to `$HOME`; point it at a project once cloned, e.g.
  `set $claude_dir $HOME/code/myrepo`, then reload i3 (`$mod+Shift+r`).
- **`--dangerously-skip-permissions`** runs without per-action prompts — fine for
  trusted local work; be deliberate about what you feed it.
- Works because `claude` lives in `~/.local/bin`, which is on i3's PATH via
  `~/.profile`.

**PATH note (zsh):** Claude Code installs to `~/.local/bin/claude` (a symlink into
`~/.local/share/claude/versions/`). Its installer adds the PATH export to
`~/.bashrc`, which **zsh never reads** — so on this zsh setup `~/.zshrc` needs:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Then `source ~/.zshrc` (or open a new shell) and verify with `claude --version`.

## Reverting

Each run writes a `.bak` next to any file it overwrites:

```bash
cp ~/.config/i3/colors.conf.bak ~/.config/i3/colors.conf
cp ~/.zshrc.bak ~/.zshrc
cp ~/.config/btop/btop.conf.bak ~/.config/btop/btop.conf
```

Restoring `~/.zshrc.bak` also removes the Starship wiring and un-blanks `ZSH_THEME`
(oh-my-zsh draws the prompt again); to drop the prompt entirely, delete
`~/.config/starship.toml` as well.

`~/.tmux.conf` is seeded once and never rewritten, so it has no `.bak`. To undo
it: `rm ~/.tmux.conf` (and `rm -rf ~/.tmux/plugins` to drop the cloned plugins);
re-running `./apply-theme.sh <flavor> tmux` re-seeds both from the kit.

The seeded nvim config files (`lua/config/{options,keymaps}.lua`,
`lua/plugins/{lsp,formatting}.lua`) are likewise seeded-once, no `.bak`. To
re-seed one from the kit, delete it (or empty it to comments) and re-run
`./apply-theme.sh <flavor> nvim`. Only `lua/plugins/colorscheme.lua` is
regenerated each run (with a `.bak`).
