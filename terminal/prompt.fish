# The prompt for the Soft Surface terminal (kitty.conf, beside this file): the
# working directory and the git branch as pills, the last command's status as a
# third when it failed, and a blank line above each prompt. install.sh links
# it into fish's conf.d. Syntax highlighting is left to fish's default theme,
# which draws in the terminal's own palette.

status is-interactive; or return

set -g fish_greeting

# The colours are palette.conf's, beside this file (the link resolved), each
# as __soft_<name> without its '#', which is how set_color takes it.
for line in (string match -rv '^\s*(#|$)' <(path dirname (path resolve (status filename)))/palette.conf)
    set -l pair (string split -n ' ' -- $line)
    set -g __soft_$pair[1] (string sub -s 2 -- $pair[2])
end

# ~/projects/dotfiles rather than ~/p/dotfiles; deeper parents still shorten.
set -q fish_prompt_pwd_full_dirs; or set -g fish_prompt_pwd_full_dirs 2

# A pill: <background> <foreground> <text...>, its rounded ends drawn in its
# own colour on the terminal's background.
function __soft_pill -a bg fg
    set_color -b normal $bg
    printf \ue0b6
    set_color -b $bg $fg
    printf ' %s ' "$argv[3..]"
    set_color -b normal $bg
    printf \ue0b4
    set_color normal
end

function fish_prompt
    set -l last $status
    set -l cwd (prompt_pwd)
    set -l place \uf07b
    string match -q '~*' -- $cwd; and set place \uf015

    # The place's icon on a lighter cap of the directory's own pill.
    set_color -b normal $__soft_raised
    printf \ue0b6
    set_color -b $__soft_raised $__soft_text_soft
    printf ' %s ' $place
    set_color -b $__soft_surface $__soft_text_soft
    printf ' %s ' $cwd
    set_color -b normal $__soft_surface
    printf \ue0b4
    set_color normal

    if command -q git
        set -l branch (command git symbolic-ref --short HEAD 2>/dev/null
            or command git rev-parse --short HEAD 2>/dev/null)
        if test -n "$branch"
            printf ' '
            __soft_pill $__soft_selection $__soft_text_soft \uf418 $branch
        end
    end

    if test $last -ne 0
        printf ' '
        __soft_pill $__soft_error_surface $__soft_red_bright $last
    end

    printf ' '
end

# The gap is printed on the fish_prompt event rather than by fish_prompt
# itself, which runs again on every repaint, and so it comes after an empty
# Enter too, where fish_postexec does not. None above the first prompt, or
# above the first after clearing the screen, whose point is a prompt on the
# top line; Ctrl+L repaints without the event and so keeps it there as well.
function __soft_prompt_gap --on-event fish_prompt
    set -q __soft_prompt_gap; and echo
    set -g __soft_prompt_gap
end

function __soft_prompt_cleared --on-event fish_postexec
    string match -qr '^\s*(clear|reset)\s*$' -- $argv; and set -e __soft_prompt_gap
end
