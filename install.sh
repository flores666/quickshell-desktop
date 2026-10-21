#!/usr/bin/env bash
# Set a computer up as this desktop: the packages it needs, the Quickshell
# config "shell", the overview plugin, and the configs of Hyprland, hyprpaper,
# kitty, fish and neovim, the scripts in bin/, and the preferences and GTK
# settings saved in profile/ (tools/save-profile.sh). The wallpapers are the
# one thing to bring by hand, into the Pictures folder's Wallpapers.
#
# The configs are links into the project, so an edit to one lands in the
# project and the next machine gets it. Each goes through the one link to the
# checkout, ~/.config/quickshell/shell, so moving the checkout only takes
# running this again.
#
# Safe to re-run: each step checks before it changes anything. A file of yours
# that has to make way is kept beside itself as <name>.bak-<date>. The saved
# preferences only go to a machine that has none of its own yet.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
shell_dir="$config/quickshell/shell"
stamp="$(date +%Y%m%d-%H%M%S)"

say() { printf '%s\n' "$*"; }

# The packages listed in <file>, without comments, that are not installed.
missing() { grep -v '^\s*\(#\|$\)' "$1" | xargs pacman -T || true; }

put_aside() {
    mv -- "$1" "$1.bak-$stamp"
    say "kept your $1 as $1.bak-$stamp"
}

# link <target> <path>: make <path> a symlink to <target>.
link() {
    [[ "$(readlink -- "$2" || true)" == "$1" ]] && return
    mkdir -p "$(dirname "$2")"
    if [[ -e "$2" || -L "$2" ]]; then put_aside "$2"; fi
    ln -s -- "$1" "$2"
    say "linked $2 -> $1"
}

# append_once <file> <line> <comment>: add <line> to <file> unless it is there.
append_once() {
    [[ -f "$1" ]] && grep -qxF "$2" "$1" && return
    mkdir -p "$(dirname "$1")"
    printf '\n# %s\n%s\n' "$3" "$2" >> "$1"
    say "added to $1: $2"
}

# enable_service <unit>: enable and start a system service that is installed and off.
enable_service() {
    systemctl cat "$1" >/dev/null 2>&1 || return 0
    systemctl is-enabled -q "$1" 2>/dev/null && return
    sudo systemctl enable --now "$1"
    say "enabled $1"
}

# ------------------------------------------------------------------ packages

if command -v pacman >/dev/null; then
    official=($(missing "$repo/packages.txt"))
    if ((${#official[@]})); then
        sudo pacman -S --needed "${official[@]}"
    fi
    aur=($(missing "$repo/packages-aur.txt"))
    if ((${#aur[@]})); then
        helper="$(command -v yay || command -v paru || true)"
        if [[ -z "$helper" ]]; then
            # yay itself comes from the AUR, built the way any AUR package is.
            build="$(mktemp -d)"
            git clone --quiet https://aur.archlinux.org/yay-bin.git "$build/yay-bin"
            (cd "$build/yay-bin" && makepkg -si --needed)
            rm -rf "$build"
            helper="$(command -v yay)"
        fi
        "$helper" -S --needed "${aur[@]}"
    fi
else
    say "not Arch: install what packages.txt and packages-aur.txt list yourself"
fi

enable_service bluetooth.service
enable_service power-profiles-daemon.service
# Only where nothing else manages the network, so as not to cut off the
# connection this may be running over.
network_others=(systemd-networkd.service iwd.service connman.service dhcpcd.service)
if ! systemctl is-enabled -q "${network_others[@]}" 2>/dev/null; then
    enable_service NetworkManager.service
fi

# The shell is the notification daemon, so any other has to go.
for unit in dunst.service mako.service swaync.service; do
    state="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"
    [[ -z "$state" || "$state" == masked || "$state" == not-found ]] && continue
    systemctl --user mask --now "$unit"
    say "masked $unit"
done

# --------------------------------------------------------------------- shell

link "$repo" "$shell_dir"

# Built when missing, or built against another Hyprland or other patches;
# hyprland.conf runs the same check at every login, so an update rebuilds it
# by itself.
if pkg-config --exists hyprland 2>/dev/null; then
    "$repo/tools/build-overview-plugin.sh" --if-stale
fi

# ------------------------------------------------------------------- configs

# Hyprland's own file stays the machine's, for what only it needs: everything
# else comes from the one line that sources the project.
hypr_conf="$config/hypr/hyprland.conf"
hypr_line="source = $shell_dir/hypr/hyprland.conf"
if ! { [[ -f "$hypr_conf" ]] && grep -qxF "$hypr_line" "$hypr_conf"; }; then
    mkdir -p "$(dirname "$hypr_conf")"
    if [[ -e "$hypr_conf" || -L "$hypr_conf" ]]; then put_aside "$hypr_conf"; fi
    printf '%s\n' \
        "# The desktop's Hyprland config is in the project (written by its install.sh)." \
        "# What only this machine needs goes below this line." \
        "$hypr_line" > "$hypr_conf"
    say "wrote $hypr_conf"
fi
link "$shell_dir/hypr/hyprpaper.conf" "$config/hypr/hyprpaper.conf"

# kitty's own file likewise: the font size kitty-font-size keeps is the
# machine's, and anything after the include wins over the project.
kitty_conf="$config/kitty/kitty.conf"
append_once "$kitty_conf" "include $shell_dir/terminal/kitty.conf" "quickshell-desktop: the terminal"
append_once "$kitty_conf" "include font-size.conf" "the font size kitty-font-size keeps for this machine"
# Running kitty windows reload their config on SIGUSR1.
pkill -USR1 -x kitty || true

link "$shell_dir/terminal/prompt.fish" "$config/fish/conf.d/quickshell-prompt.fish"
fish="$(command -v fish || true)"
if [[ -n "$fish" && "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$fish" ]]; then
    chsh -s "$fish" || say "kept your login shell; fish is $fish"
fi

link "$shell_dir/nvim" "$config/nvim"

for script in "$repo"/bin/*; do
    link "$shell_dir/bin/${script##*/}" "$HOME/.local/bin/${script##*/}"
done

# ------------------------------------------------------------------- profile

# A saved setting only where the machine still has the default: a re-run
# never takes back a change made since.
if command -v dconf >/dev/null && [[ -f "$repo/profile/gtk.dconf" ]]; then
    dir=""
    while IFS= read -r line; do
        case "$line" in
            '['*']') dir="${line:1:${#line}-2}" ;;
            *=*)
                key="/$dir/${line%%=*}"
                [[ -n "$(dconf read "$key")" ]] && continue
                dconf write "$key" "${line#*=}"
                say "set $key"
                ;;
        esac
    done < "$repo/profile/gtk.dconf"
fi

# The shell's preferences need nothing here: the first time the shell runs
# without any, it starts from profile/settings.json (services/Settings.qml).

say "done. Log in to Hyprland again, or start the shell now with: qs -c shell"
