# .bashrc
################################################################################
# Bash Configuration
################################################################################

#------------------------------------------------------------------------------#
# If not running interactively, don't do anything.
#------------------------------------------------------------------------------#

[ -z "$PS1" ] && return

#------------------------------------------------------------------------------#
# Source custom configuration files.
#------------------------------------------------------------------------------#

[ -f $HOME/.bash.d/colors ] && . $HOME/.bash.d/colors
[ -f $HOME/.bash.d/functions ] && . $HOME/.bash.d/functions

#------------------------------------------------------------------------------#
# System information.
#------------------------------------------------------------------------------#

me=`whoami`
host=`hostname`
os=`uname -s`
arch=`uname -m`
dist=""

if [ -f /etc/os-release ] ; then
  dist=`cat /etc/os-release | tr '\n' '%' | \
    awk -F '%' '{print $6}' | sed 's,ID=,,g'`
elif [ "$os" = "Darwin" ]; then
  dist="Darwin"
fi

print_env_var "OS" $os
print_env_var "ARCH" $arch
print_env_var "DISTRO" $dist

if [[ $host == *cn* ]] ; then
  host_simple=`echo $host | sed 's,\..*$,,g;s,[0-9],,g'`
elif [[ $host == *darwin* ]] ; then
  host_simple="darwin"
elif [[ $host == *rzvernal* ]] ; then
  host_simple="rzvernal"
else
  host_simple=`echo $host | sed 's,\..*$,,g'`
fi

#------------------------------------------------------------------------------#
# Pickup system configuration. (This gets lmod.)
#------------------------------------------------------------------------------#

[[ $dist != ubuntu ]] && [ -f /etc/profile ] && . /etc/profile

#------------------------------------------------------------------------------#
# History control.
#------------------------------------------------------------------------------#

# Don't put duplicate lines or lines starting with space in history.
HISTCONTROL=ignoreboth

# Append to history file, don't overwrite it.
shopt -s histappend

# Set history length.
HISTSIZE=1000
HISTFILESIZE=2000

#------------------------------------------------------------------------------#
# Check window size after each command.
#------------------------------------------------------------------------------#

shopt -s checkwinsize

#------------------------------------------------------------------------------#
# Make less more friendly for non-text input files, see lesspipe(1).
#------------------------------------------------------------------------------#

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

#------------------------------------------------------------------------------#
# Add local modulefile path and modules.
#------------------------------------------------------------------------------#

[ -f /usr/local/opt/lmod/init/profile ] && \
  . /usr/local/opt/lmod/init/profile
[ -f /opt/homebrew/opt/lmod/init/profile ] && \
  . /opt/homebrew/opt/lmod/init/profile

# Need to check to make sure that these aren't loaded by subsequent
# shells or lmod complains
if [ -d /opt/intel/oneapi/modulefiles ] && \
  [[ "$MODULEPATH" != *"/opt/intel/oneapi/modulefiles"* ]]; then
  export MODULEPATH=$MODULEPATH:/opt/intel/oneapi/modulefiles
fi
if [[ "$MODULEPATH" != *"$HOME/.modulefiles"* ]]; then
  export MODULEPATH=$MODULEPATH:$HOME/.modulefiles
fi

export LMOD_PAGER="less -+e -+E"

module load aliases

#------------------------------------------------------------------------------#
# Git.
#------------------------------------------------------------------------------#

export EDITOR="vi"
export SPACK_EDITOR="vi"

#------------------------------------------------------------------------------#
# EZA Colors.
#------------------------------------------------------------------------------#

owner="ur=38;5;250:uw=38;5;245:ux=38;5;255:ue=38;5;255"
group="gr=38;5;250:gw=38;5;245:gx=38;5;255"
other="tr=38;5;250:tw=38;5;245:tx=38;5;255"
export EZA_COLORS="da=38;5;30:uu=38;5;29:$owner:$group:$other"

#------------------------------------------------------------------------------#
# Xauthority
#------------------------------------------------------------------------------#

export XAUTHORITY=$HOME/.Xauthority

#------------------------------------------------------------------------------#
# Spack setup.
#------------------------------------------------------------------------------#

[ $os != "Darwin" ] && [[ $host != *darwin* ]] && \
  [ -f $HOME/.spack/share/spack/setup-env.sh ] && \
  . $HOME/.spack/share/spack/setup-env.sh

#------------------------------------------------------------------------------#
# Path setup.
#------------------------------------------------------------------------------#

prepend_path "$HOME/.local/bin"

if [ $os == "Darwin" ] ; then
  if [ $arch == "x86_64" ] ; then
    prepend_path "/Applications/VMware Fusion.app/Contents/Library"
    prepend_path "/usr/local/bin"
    prepend_path "/usr/local/opt/coreutils/libexec/gnubin"
    prepend_path "/usr/local/opt/make/libexec/gnubin"
    prepend_path "/opt/local/bin"
  elif [ $arch == "arm64" ] ; then
    prepend_path "/opt/homebrew/bin"
    prepend_path "/opt/homebrew/sbin"
    prepend_path "/opt/homebrew/opt/coreutils/libexec/gnubin"
  fi
fi

[ -d /opt/nvim ] && prepend_path "/opt/nvim/bin"
[ -d $HOME/.config/nvim/local/lua-language-server ] &&
  prepend_path "$HOME/.config/nvim/local/lua-language-server/bin"
[ -d $HOME/.config/nvim/local/tex-language-server ] &&
  prepend_path "$HOME/.config/nvim/local/tex-language-server/bin"
[ -d $HOME/.config/nvim/local/node_modules/tree-sitter-cli ] &&
  prepend_path "$HOME/.config/nvim/local/node_modules/tree-sitter-cli"

prepend_path "$HOME/bin"

#------------------------------------------------------------------------------#
# Directory colors.
#------------------------------------------------------------------------------#

eval `dircolors -b ~/.dircolors`

#------------------------------------------------------------------------------#
# Color man pages
#------------------------------------------------------------------------------#

export LESS_TERMCAP_mb=$'\E[1;31m'     # begin bold
export LESS_TERMCAP_md=$'\E[1;36m'     # begin blink
export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\E[01;44;33m' # begin reverse video
export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # reset underline
export GROFF_NO_SGR=1                  # for konsole and gnome-terminal

#------------------------------------------------------------------------------#
# Config state.
#------------------------------------------------------------------------------#

if [[ $host == x1 ]]; then
  cd ~
fi

#------------------------------------------------------------------------------#
# Run fixdate on vms.
#------------------------------------------------------------------------------#

if [[ $host != *darwin* && $host != *cn* && $host != *grac* && $host != *X1* && $host != *u24-m4* && "$os" == "Linux" && "$(sudo dmidecode | grep Vendor)" == *"Parallels"* ]]; then
  fd=$(nc -vz google.com 443 2>&1)
  if [[ "$fd" == *"succeeded"* ]]; then
    echo -e "$FG_CYAN""Checking Date""$NEUTRAL"
    date=`$HOME/bin/fixdate 2>&1`
    echo -e "$FG_CYAN""$date""$NEUTRAL"
  fi
fi

#------------------------------------------------------------------------------#
# Config state.
#------------------------------------------------------------------------------#

if [[ $me != "root" ]] ; then
  ssh -xT git@github.com > /dev/null 2>&1

  if [ $? -eq 1 ]; then
    echo -e "$FG_40""Checking configuration status...""$NEUTRAL"
    (cd $HOME/.config/bergen; git fetch 2>&1 > /dev/null)
    change=`(cd $HOME/.config/bergen; git status -uno)`
    [[ -n $change ]] && [[ "$change" != *"Your branch is up to date"* ]] && \
      echo -e "$FG_160""$change""$NEUTRAL"
  fi
fi

#------------------------------------------------------------------------------#
# Set prompt.
#------------------------------------------------------------------------------#

extra_pinfo=""
[ -f $HOME/.bash.d/$host_simple ] && [[ -z "${BASHRC_SILENT}" ]] &&
  echo -e "$FG_28""Configuration""$FG_39"" $host_simple""$NEUTRAL" &&
  . $HOME/.bash.d/$host_simple

prompt() {
  echo -ne "\033];"${PWD##*/}"\007"
  echo -ne "$P_BG_DATE$P_FG_DATE" `date +%H:%M:%S`
  echo -ne " $P_BG_HOST$P_FG_USER $USER$P_FG_AT@$P_FG_HOST$host "
  echo -ne "$P_BG_EXTRA$P_FG_EXTRA $extra_pinfo "
  if [[ -n "${SPACK_ENV}" ]] ; then
    echo -ne "$P_FG_SPACK "
    echo -ne "Spack ENV: "
    echo -ne $SPACK_ENV | sed 's,.*\/,,g'
    echo -ne "$P_BG_EXTRA$P_FG_PWD$TOEND"
  fi
  echo -e ""

  echo -e "$P_BG_PWD$P_FG_PWD$TOEND" `pwd` "$NEUTRAL"
}

PROMPT_COMMAND=prompt
PS1="$P1>$P2>$P3>$P4>$P5>$P6>$P "

#------------------------------------------------------------------------------#
# Print info.
#------------------------------------------------------------------------------#

print_env_var "PATH" $PATH
print_env_var "MODULEPATH" $MODULEPATH

# vim: set nornu:
