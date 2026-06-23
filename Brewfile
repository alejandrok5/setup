# Brewfile — packages for the macOS console + AeroSpace desktop setup.
# Install with:  brew bundle --file=Brewfile   (install-macos.sh does this for you)

tap "nikitabobko/tap"        # AeroSpace
tap "felixkratz/formulae"    # borders (JankyBorders)

# --- desktop layer ---
cask "aerospace"               # i3-like tiling window manager
brew "borders"                 # mauve focused-window outline (JankyBorders)
cask "alacritty"               # terminal
cask "stats"                   # menu-bar system monitor (CPU/mem/net/battery)
cask "font-meslo-lg-nerd-font" # Nerd Font (glyphs for starship/tmux/lazygit)

# --- shell / prompt ---
brew "zsh-syntax-highlighting"
brew "starship"
brew "mise"                    # runtime manager (.zshrc activates it)

# --- console / TUI stack ---
brew "neovim"
brew "tmux"
brew "btop"
brew "yazi"
brew "lazygit"
brew "lazydocker"              # needs a Docker runtime you provide — see README

# --- CLI helpers (yazi previews + general) ---
brew "ffmpegthumbnailer"
brew "poppler"
brew "sevenzip"
brew "jq"
brew "fd"
brew "ripgrep"
brew "chafa"
