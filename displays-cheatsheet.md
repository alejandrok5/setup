# displays cheatsheet

Multi-monitor under i3/Xorg: [`autorandr`](https://github.com/phillipberndt/autorandr)
profiles (EDID-matched, auto-applied on hotplug/lid) + `xrandr` for one-offs + an
i3 **rotate mode**. Full design notes: README "External monitors". Rebuild it all
with `~/setup/displays/install.sh`.

> Output names on this machine (amdgpu): `eDP` (laptop), `DisplayPort-0`,
> `DisplayPort-1`, `HDMI-A-0`. Check live names with `xrandr --query`.

## Rotate a monitor — `$mod+o` mode
| Key | Action |
| --- | --- |
| `$mod+o` | enter **rotate mode** |
| `↑` | upright (normal) |
| `↓` | upside-down (inverted) |
| `←` | portrait (rotate left) |
| `→` | portrait (rotate right) |
| `Return` / `Esc` | exit rotate mode (no change) |

Rotates the **first external** ("auto"); re-tiles *all* monitors left-to-right so
none overlap (no mirroring), and the wallpaper + bars follow. To rotate a
**specific** output instead, from a terminal:

```bash
~/.config/i3/scripts/rotate.sh DisplayPort-1 left      # output + normal|left|right|inverted
```

## Apply / re-detect layouts
| Key / command | Action |
| --- | --- |
| `$mod+p` | re-run `autorandr --change` (apply best-matching profile) |
| `autorandr` | list saved profiles (the matching one shows `(detected)`) |
| `autorandr --change` | apply the best match for the connected monitors |
| `autorandr <name>` | force a specific profile |

Hotplug, docking and lid events run `autorandr --change` automatically (systemd +
udev hook). If nothing matches, the fallback `--default horizontal` extends
whatever is connected.

## Save a layout (profile)
Arrange first (drag in **`arandr`**, or `xrandr` flags below), then snapshot:

```bash
autorandr --save <name>
```

Profiles match by the EDIDs of the connected outputs, so each combo auto-applies
on hotplug afterwards. Names used here:

| Name | Setup |
| --- | --- |
| `mobile` | laptop only (lid open) |
| `extend-1` | laptop + 1 external |
| `dual-extend` | laptop + 2 externals |
| `dock-1` / `dock-2` | **clamshell** (lid closed) — *save with the lid actually shut* |

> Clamshell: autorandr drops `eDP` from the fingerprint when the lid is closed, so
> a `dock-*` profile must be saved *with the lid down* or it collides with the
> matching lid-open `extend-*`. Pause the watcher while saving:
> `sudo systemctl stop autorandr-lid-listener` → shut lid → `autorandr --save dock-1`
> → `sudo systemctl start autorandr-lid-listener`.

## xrandr one-liners
| Command | Does |
| --- | --- |
| `xrandr --query` | list outputs, modes, positions, rotation |
| `xrandr --output X --primary` | set primary (where polybar + primary workspaces live) |
| `xrandr --output X --auto` | enable at native resolution |
| `xrandr --output X --off` | disable an output |
| `xrandr --output X --rotate left\|right\|normal\|inverted` | rotate |
| `xrandr --output X --right-of Y` | position (`--left-of` / `--above` / `--below` / `--pos WxH`) |

## What happens automatically
| Event | Behavior |
| --- | --- |
| Plug a **saved** combo | its profile auto-applies |
| Plug an **unsaved** monitor | auto-extends right (`--default horizontal`) |
| Unplug everything | `mobile` (laptop only) |
| Close lid **while docked** | `eDP` off, externals stay on |
| Close lid **undocked** | suspend (logind default) |
| Open lid | `eDP` returns |

Every switch re-applies the wallpaper + polybar via `~/.config/autorandr/postswitch`.

## Rebuild
```bash
~/setup/displays/install.sh        # idempotent; sudo for the system fallbacks
```
Installs the postswitch hook, `rotate.sh`, the picom `use-damage = false` fix, and
the autorandr hotplug + lid fallbacks; checks the i3 rotate binding + polybar lock.
