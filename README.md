# setup — macos branch (Apple Silicon / Intel)

The **macOS** variant of my [i3 desktop setup](https://github.com/alejandrok5/setup/tree/main).
There's no i3 on macOS, so the desktop layer is **AeroSpace** (an open-source,
i3-like tiling WM); everything else macOS does natively (compositing, notifications,
display scaling, media keys) is dropped, and the whole **themed terminal/TUI stack
ports over** — Catppuccin everywhere (mauve accent), tmux on Rosé Pine.

> This is the `macos` branch. See also `main` (i3 desktop) and `server`
> (headless Ubuntu).

## Install

```bash
git clone -b macos https://github.com/alejandrok5/setup.git ~/setup
cd ~/setup
./install-macos.sh                 # or: ./install-macos.sh mocha
```

`install-macos.sh` installs Homebrew (if absent), runs `brew bundle`, places the
dotfiles, themes everything, and starts AeroSpace + borders. Idempotent and
re-runnable.

**Safe on a Mac you already use.** Before changing anything, step 0 snapshots
every file it touches into a timestamped `~/.setup-backup-<date>/` and writes a
`rollback.sh` there — so you get the full themed result, fully reversible. Undo
everything (restore your originals, remove what it created) with:

```bash
~/.setup-backup-<date>/rollback.sh
```

Rollback restores configs only; it leaves the installed Homebrew packages in place.

**Required manual step** (no script can do it): grant **AeroSpace** Accessibility
access — *System Settings → Privacy & Security → Accessibility → enable AeroSpace*.
It prompts on first launch; tiling does nothing until you allow it.

## The stack

| Layer | Choice |
| --- | --- |
| Tiling WM | **AeroSpace** (i3-like, TOML, Option = `$mod`, no SIP disable) |
| Bar | **native menu bar + Stats** (FOSS system monitor) |
| Accent | **JankyBorders** — mauve focused-window outline (the i3 focus border) |
| Terminal | **Alacritty** (Catppuccin, ports from Linux) |
| Launcher | **Spotlight** (`cmd-space`, native) |
| Shell | zsh + oh-my-zsh + **starship** + zsh-syntax-highlighting |
| Multiplexer | **tmux** (Rosé Pine, TPM + resurrect/continuum) |
| Editor | **Neovim / LazyVim** (Catppuccin) |
| TUIs | **btop · yazi · lazygit · lazydocker** (all Catppuccin, mauve) |
| Runtimes | **mise** + ruby (for ruby-lsp) |
| Packages | **Homebrew `Brewfile`** (`brew bundle`) |

Everything installs via Homebrew (`Brewfile`); the WM/bar/terminal go in as casks,
the rest as formulae.

## AeroSpace keys (mod = Option/alt)

| Key | Action |
| --- | --- |
| `alt-enter` | new Alacritty window |
| `cmd-space` | app launcher (native Spotlight) |
| `alt-1`…`alt-0` | workspaces 1–10 · `alt-shift-N` move window there |
| `alt-h/j/k/l` | focus · `alt-shift-h/j/k/l` move |
| `alt-/` `alt-,` | layout tiles / accordion |
| `alt-f` | fullscreen · `alt-shift-space` float |
| `alt-shift-q` | close window (or native `cmd-w`/`cmd-q`) |
| `alt-r` | resize mode (`h/j/k/l`, `enter`/`esc` to exit) |
| `alt-tab` | last workspace · `alt-shift-c` reload config |

Spotify is pinned to workspace 10 (`on-window-detected`), like the i3 `assign`.
Edit `~/.config/aerospace/aerospace.toml` to taste.

> **Alt overlap:** AeroSpace grabs Option globally, so terminal apps that use Alt
> chords (e.g. LazyVim's `<A-h/j/k/l>` terminal toggles) are shadowed. Remap one
> side if it bites.

## Theming / flavor

```bash
./apply-theme.sh [flavor] [component]
#   flavor:    latte | frappe | macchiato | mocha   (default: macchiato)
#   component: zsh | starship | btop | yazi | lazygit | lazydocker | borders | nvim | tmux
```

`apply-theme.sh` themes the terminal-side stack and **generates** the
`lazygit`/`lazydocker`/`borders` configs from an embedded Catppuccin palette
(mauve accent) — those three `config` files are **owned** by the script
(regenerated each run, `.bak` kept). AeroSpace itself has no colors; the menu bar
follows macOS appearance. After a zsh change run `exec zsh`; restart btop/yazi/
lazygit; restart nvim (lazy.nvim recompiles catppuccin). `borders` live-reloads.

tmux is Rosé Pine and **flavor-independent** — seeded once to `~/.tmux.conf`
(with the clipboard binding swapped from `xclip` to **`pbcopy`** for macOS), then
left alone.

## Notes / requirements

- **Nerd Font:** installed via Homebrew (`font-meslo-lg-nerd-font`) and used by
  Alacritty for the glyphs in starship/tmux/lazygit.
- **lazydocker** needs a Docker runtime you provide — **colima** (FOSS),
  Docker Desktop, or OrbStack. It connects once a daemon exists.
- **Homebrew on PATH:** `install-macos.sh` adds `eval "$(brew shellenv)"` to
  `~/.zprofile` (Apple Silicon's `/opt/homebrew/bin` isn't on PATH by default),
  so new zsh sessions find starship/mise/etc.
- **yazi image previews** need a graphics-protocol terminal; Alacritty has none,
  so previews show file info (`chafa` gives an ASCII fallback). Switch to
  Ghostty/kitty/WezTerm if you want inline images.
- **Dropped — macOS native:** compositor/transparency, notifications (dunst),
  GTK, display scaling/autorandr, media keys, touchpad, wallpaper, lock, xorg.
- **Optional toggles** (System Settings): natural scrolling, Dark mode.

## Reverting

**Undo the whole install** — restore the configs it replaced and remove the ones
it created — with the generated rollback script:

```bash
~/.setup-backup-<date>/rollback.sh
```

That timestamped folder is the pre-install snapshot `install-macos.sh` takes in
step 0. Rollback restores configs only; it leaves Homebrew packages and the cloned
tmux/nvim plugins in place.

For a single re-theme, `apply-theme.sh` also drops a `.bak` next to each file it
rewrites (`~/.config/lazygit/config.yml.bak`, `~/.config/borders/bordersrc.bak`, …),
so you can revert one component without the full rollback.
