# yazi cheatsheet

Default keymap for [yazi](https://yazi-rs.github.io/) (the terminal file manager
that replaced ranger). Launch with **`y`** (cd's into the last dir on quit) or
**`yazi`**. Inside yazi, press **`~`** any time for the full, authoritative help.

> Files open in **nvim** (via `$EDITOR`, set in `~/.zshrc`). Image previews need
> `ueberzugpp` — see README "File manager (yazi)".

## Copy · cut · paste · rename
| Key | Action |
| --- | --- |
| `y` | **yank (copy)** the file/selection |
| `x` | **cut** the file/selection |
| `p` | **paste** into the current directory |
| `P` | paste, **overwriting** existing files |
| `Y` / `X` | cancel a pending copy / cut |
| `r` | **rename** (cursor lands before the extension) |
| `a` | create a **file** (end the name with `/` to make a **directory**) |
| `d` | move to **trash** |
| `D` | **delete permanently** |

Typical flow: highlight a file → `y` → navigate to the destination → `p`.
For several files: select them first (below), then `y`/`x` → destination → `p`.

## Selecting multiple
| Key | Action |
| --- | --- |
| `Space` | toggle selection of the current file, move down |
| `v` | visual select mode (select as you move) |
| `V` | visual **un**select mode |
| `Ctrl-a` | select all |
| `Ctrl-r` | invert selection |
| `Esc` | clear selection / cancel |

## Navigation
| Key | Action |
| --- | --- |
| `j` / `k` | down / up (arrows work too) |
| `h` / `l` | parent dir / enter dir or open file |
| `gg` / `G` | jump to top / bottom |
| `Ctrl-u` / `Ctrl-d` | half page up / down |
| `gh` | go to home (`~`) |
| `.` | toggle hidden files |
| `Enter` / `o` | open (text files → nvim) |
| `O` | open with… (pick the program) |

## Find · filter · search
| Key | Action |
| --- | --- |
| `/` / `?` | find by name, forward / backward (`n` / `N` = next / prev match) |
| `f` | filter the current list as you type |
| `s` | search file **names** (fd) |
| `S` | search file **contents** (ripgrep) |
| `z` / `Z` | jump with zoxide / fzf *(if installed)* |

## Copy a path to the clipboard (`c` menu)
| Key | Action |
| --- | --- |
| `cc` | copy the full **path** |
| `cd` | copy the **directory** path |
| `cf` | copy the **filename** |
| `cn` | copy the filename **without extension** |

## Sorting (`,` menu)
| Key | Action |
| --- | --- |
| `,a` / `,A` | alphabetical / reversed |
| `,n` | natural (1,2,…,10 instead of 1,10,2) |
| `,m` | by modified time |
| `,s` | by size |
| `,e` | by extension |

## Tabs · tasks · quit
| Key | Action |
| --- | --- |
| `t` | new tab (at the current dir) |
| `1`–`9` | switch to tab N |
| `[` / `]` | previous / next tab |
| `w` | task manager (running copy/move/delete jobs) |
| `;` | run a shell command in the current dir |
| `~` | **help** (full keymap) |
| `q` | quit (the `y` wrapper cd's you here) |
| `Q` | quit **without** changing directory |
