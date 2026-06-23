# setup — server branch (Ubuntu Server, console-only)

The **headless** variant of my [desktop setup](https://github.com/alejandrok5/setup/tree/main).
No window manager, no X11 — just the **themed terminal/TUI stack**, set up with one
command and made to look good over SSH. Catppuccin everywhere (mauve accent), with
tmux on Rosé Pine.

> This is the `server` branch. The full **i3 (Xorg) desktop** lives on
> [`main`](https://github.com/alejandrok5/setup/tree/main).

## Install

```bash
git clone -b server https://github.com/alejandrok5/setup.git ~/setup
cd ~/setup
./install-server.sh                 # or: ./install-server.sh mocha
```

`install-server.sh` is idempotent and safe to re-run; it backs up anything it
overwrites to `.bak`, and treats the network/optional steps as non-fatal. It needs
`sudo` for the apt + Docker steps and will prompt for it. After it finishes, open a
**new SSH session** (or `exec zsh`) so the new shell, mise, starship and
syntax-highlighting take effect.

Skip Docker if you don't want it:

```bash
INSTALL_DOCKER=0 ./install-server.sh
```

## What you get

| Tool | What | Theme |
| --- | --- | --- |
| **zsh** + oh-my-zsh | shell, `plugins=(git)` | — |
| **starship** | prompt (catppuccin-powerline preset) | Catppuccin `<flavor>` |
| **zsh-syntax-highlighting** | command coloring | Catppuccin `<flavor>` |
| **tmux** | TPM + resurrect/continuum (session persistence) | **Rosé Pine** (moon) |
| **Neovim / LazyVim** | editor (recent nvim, not apt's) | Catppuccin `<flavor>` |
| **btop** | system monitor | Catppuccin `<flavor>` |
| **yazi** | file manager (`y` cd-on-exit wrapper) | Catppuccin `<flavor>` (mauve) |
| **lazygit** | git TUI | Catppuccin `<flavor>` (mauve accent) |
| **lazydocker** | docker TUI | Catppuccin `<flavor>` (mauve accent) |
| **mise** + ruby | runtime manager; ruby for ruby-lsp | — |

Binaries that aren't in Ubuntu's repos (Neovim, yazi, lazygit, lazydocker, starship,
mise) install **into `~/.local/bin`** — no system-wide footprint, no sudo for those.

## Nerd Font (read this)

The prompt, tmux status line and lazygit/lazydocker icons use **Nerd Font glyphs**.
Over SSH those are rendered by **your client terminal's font**, not the server's — so
**set your local terminal to a Nerd Font** (e.g. *MesloLGS Nerd Font Mono*) for the
icons to show. `install-server.sh` deliberately installs **no** font on the box: the
raw TTY uses kernel console fonts and SSH uses your client's font, so a server-side
TTF wouldn't be rendered anyway.

## Flavor / re-theme

```bash
./apply-theme.sh [flavor] [component]
#   flavor:    latte | frappe | macchiato | mocha   (default: macchiato)
#   component: zsh | starship | btop | yazi | lazygit | lazydocker | nvim | tmux
```

Re-running is idempotent. Examples:

```bash
./apply-theme.sh mocha                 # everything -> Mocha
./apply-theme.sh macchiato lazygit     # repaint ONLY lazygit
```

After a zsh change run `exec zsh`; restart btop/yazi/lazygit/lazydocker to pick up
colors; restart nvim (lazy.nvim recompiles catppuccin on launch). tmux is Rosé Pine
and **flavor-independent** — `apply-theme.sh` seeds `~/.tmux.conf` once and clones
the plugins, but never re-themes it.

**lazygit / lazydocker theming:** these have no upstream Catppuccin repo to vendor,
so `apply-theme.sh` *generates* `~/.config/{lazygit,lazydocker}/config.yml` from an
embedded palette (mauve active borders to match the rest). Those two `config.yml`
files are **owned** by the script (regenerated each run, `.bak` kept) — to change
layout/keybinds, edit the template in `apply-theme.sh`, not the generated file.

## Quick keys

- **tmux** prefix is `C-a`; `C-a r` reload, `C-a I` install plugins. Mouse mode on
  (hold **Shift** to drag-select natively). Sessions persist across reboots
  (resurrect/continuum).
- **nvim** leader is `\` (ported NvChad-style keymaps); `<C-n>` file explorer,
  `<leader>ff` find files, `jk` to escape. First launch installs plugins.
- **yazi**: run `y` (cd's into the last dir on quit) or `yazi`. Image previews are
  off over SSH (no ueberzug); `chafa` gives an ASCII fallback. See
  [`yazi-cheatsheet.md`](yazi-cheatsheet.md).
- **lazygit** `lg`-style: launch `lazygit` in a repo. **lazydocker**: launch
  `lazydocker` (needs Docker; the installer sets it up + adds you to the `docker`
  group — log out/in for that to apply).

## Requirements / notes

- **Ubuntu/Debian, x86_64.** The prebuilt-binary URLs target `amd64`/`x86_64`; on
  arm64 swap the asset names in `install-server.sh`.
- **Recent Neovim** (≥ 0.11 for LazyVim) is installed to `~/.local` from the official
  release tarball, because Ubuntu's apt build is usually too old.
- **Clipboard over SSH:** there's no X clipboard on a headless box; use your
  terminal's copy (tmux copy-mode → terminal selection) or an OSC52-capable client.
- **Docker:** installed via `get.docker.com`; you're added to the `docker` group so
  `docker`/lazydocker work without sudo after a re-login.

## Reverting

Each run writes a `.bak` next to anything it overwrites (`~/.zshrc.bak`,
`~/.config/btop/btop.conf.bak`, `~/.config/lazygit/config.yml.bak`, …). `~/.tmux.conf`
is seeded once and never rewritten (no `.bak`); to undo it: `rm ~/.tmux.conf`
(and `rm -rf ~/.tmux/plugins`), then re-run `./apply-theme.sh <flavor> tmux`.
