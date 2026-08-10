set fish_greeting

alias n='nvim'
alias htop='btop'
alias ls='lsd'
alias cat='bat'
alias df='duf'
alias find='fd'
alias clean='wipeclean'

zoxide init fish --cmd cd | source
set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml
starship init fish | source

if status is-interactive
    function __starship_repaint_on_palette --on-variable __starship_palette_rev
        commandline -f repaint
    end
end
