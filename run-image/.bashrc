# shellcheck shell=bash

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
      # shellcheck source=/dev/null
      . /etc/bash_completion
fi

# Setup git user
if [[ -z "$(git config --global --get user.name)" && -v GIT_AUTHOR_NAME ]]; then
    git config --global user.name "$GIT_AUTHOR_NAME"
fi
if [[ -z "$(git config --global --get user.email)" && -v EMAIL ]]; then
    git config --global user.email "$EMAIL"
fi

if [[ "$POWERLINE_SHELL_DISABLE" != "1" ]]; then
    function _update_ps1() {
        # shellcheck disable=SC2046
        PS1="$(/usr/local/bin/powerline-shell -error $? -jobs $(jobs -p | wc -l) -mode compatible -modules ssh,venv,cwd,git,root)"
    }

    if [ "$TERM" != "linux" ] && [ -f "/usr/local/bin/powerline-shell" ]; then
        PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
    fi
fi

export RENKU_DISABLE_VERSION_CHECK=1
