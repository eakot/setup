# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================
# DETECT OS
# ============================================
case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *)      OS="unknown" ;;
esac

# ============================================
# HISTORY
# ============================================
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# ============================================
# SHELL OPTIONS
# ============================================
shopt -s checkwinsize
# shopt -s globstar  # uncomment if you want ** pattern matching

# ============================================
# LS ALIASES (OS-specific)
# ============================================
if [[ "$OS" == "macos" ]]; then
    # macOS: -G for color (--color not supported by BSD ls)
    alias ls='ls -G'
    alias ll='ls -laG'
    alias l.='ls -dG .*'
    alias lt='ls -lhSG'
else
    # Linux: --color=auto
    alias ls='ls --color=auto'
    alias ll='ls -la --color=auto'
    alias l.='ls -d .* --color=auto'
    alias lt='ls --human-readable --size -1 -S --classify --color=auto'
fi

alias la='ls -A'
alias l='ls -CF'

# ============================================
# NAVIGATION
# ============================================
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../../'

# ============================================
# GREP (same on both)
# ============================================
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# ============================================
# UTILITIES
# ============================================
alias bc='bc -l'
alias du='du -ch -d 2 | sort -h'

# OS-specific utilities
if [[ "$OS" == "macos" ]]; then
    alias ports='lsof -i -P -n | grep LISTEN'
    alias cpuinfo='sysctl -n machdep.cpu.brand_string'
    alias meminfo='top -l 1 -s 0 | head -n 10'
else
    alias ports='netstat -tulanp'
    alias cpuinfo='lscpu'
    alias meminfo='free -m -l -t'
    alias gpumeminfo='grep -i --color memory /var/log/Xorg.0.log'
    # Parenting changing perms on / (Linux only, macOS doesn't support --preserve-root)
    alias chown='chown --preserve-root'
    alias chmod='chmod --preserve-root'
    alias chgrp='chgrp --preserve-root'
fi

# Process monitoring
if [[ "$OS" == "macos" ]]; then
    alias psmem='ps aux | sort -nr -k 4'
    alias pscpu='ps aux | sort -nr -k 3'
else
    alias psmem='ps auxf | sort -nr -k 4'
    alias pscpu='ps auxf | sort -nr -k 3'
fi

# ============================================
# TAR (careful: this overrides default behavior!)
# ============================================
# alias tar='tar -zxvf'  # commented out - this breaks tar creation

# ============================================
# CD WITH LS
# ============================================
function cd() {
    local dir="$*"
    if [[ $# -lt 1 ]]; then
        dir="$HOME"
    fi
    builtin cd "$dir" && ll
}

# ============================================
# PROMPT
# ============================================
# Set color prompt
if [[ "$TERM" == *color* || "$TERM" == *256* || "$TERM" == xterm-* || "$TERM" == screen-* ]]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi

# Set terminal title (for xterm/Terminal.app)
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\u@\h: \w\a\]$PS1"
    ;;
esac

# ============================================
# COMPLETIONS
# ============================================
if [[ "$OS" == "macos" ]]; then
    # Homebrew bash completion
    if [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]]; then
        . "/usr/local/etc/profile.d/bash_completion.sh"
    elif [[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]]; then
        . "/opt/homebrew/etc/profile.d/bash_completion.sh"
    fi
else
    # Linux bash completion
    if ! shopt -oq posix; then
        if [[ -f /usr/share/bash-completion/bash_completion ]]; then
            . /usr/share/bash-completion/bash_completion
        elif [[ -f /etc/bash_completion ]]; then
            . /etc/bash_completion
        fi
    fi
fi

# ============================================
# ADDITIONAL ALIASES FILE
# ============================================
if [[ -f ~/.bash_aliases ]]; then
    . ~/.bash_aliases
fi

# ============================================
# LOCAL OVERRIDES (machine-specific settings)
# ============================================
if [[ -f ~/.bashrc.local ]]; then
    . ~/.bashrc.local
fi

