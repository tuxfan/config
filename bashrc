# .bashrc
################################################################################
# Bash Configuration
################################################################################

#------------------------------------------------------------------------------#
# If not running interactively, don't do anything.
#------------------------------------------------------------------------------#

case $- in
    *i*) ;;
      *) return;;
esac

#------------------------------------------------------------------------------#
# Pickup system configuration. (This gets lmod.)
#------------------------------------------------------------------------------#

if [ -f /etc/bashrc ] ; then
  . /etc/bashrc
fi

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
# System information.
#------------------------------------------------------------------------------#

host=`hostname`
os=`uname -a | awk '{print $1}'`

if [ $host == *cn* ] ; then
  host_simple=`echo $host | sed 's,\..*$,,g;s,[0-9],,g'`
else
  host_simple=`echo $host | sed 's,\..*$,,g'`
fi

#------------------------------------------------------------------------------#
# Source custom configuration files.
#------------------------------------------------------------------------------#

[ -f $HOME/.bash/colors ] && . $HOME/.bash/colors
[ -f $HOME/.bash/functions ] && . $HOME/.bash/functions

#------------------------------------------------------------------------------#
# Add local modulefile path and modules.
#------------------------------------------------------------------------------#

if [ $os == "Darwin" ] ; then
  if [ -f /opt/homebrew/opt/lmod/init/profile ] ; then
    . /opt/homebrew/opt/lmod/init/profile
  fi
fi

export MODULEPATH=$MODULEPATH:$HOME/.modulefiles
module load aliases

#------------------------------------------------------------------------------#
# Spack setup.
#------------------------------------------------------------------------------#

[ $os != "Darwin" ] && [ -f $HOME/.spack/share/spack/setup-env.sh ] && \
  . $HOME/.spack/share/spack/setup-env.sh

#------------------------------------------------------------------------------#
# Path setup.
#------------------------------------------------------------------------------#

prepend_path "$HOME/.local/bin"

if [ $os = "Darwin" ] ; then
  prepend_path "/opt/homebrew/bin"
  prepend_path "/opt/homebrew/sbin"
  prepend_path "/opt/homebrew/opt/coreutils/libexec/gnubin"
fi

prepend_path "$HOME/bin"

#------------------------------------------------------------------------------#
# Directory colors.
#------------------------------------------------------------------------------#

#[ -f $HOME/.dircolors ] && eval `dircolors -b $HOME/.dircolors`
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
# Set prompt.
#------------------------------------------------------------------------------#

extra_pinfo=""
[ -f $HOME/.bash/$host_simple ] && [[ -z "${BASHRC_SILENT}" ]] &&
  echo -e "$FG_DCYAN""Configuration""$FG_GREEN"" $host_simple""$NEUTRAL" &&
  . $HOME/.bash/$host_simple

if [ `whoami` = "root" ] ; then
  export PROMPT_COMMAND='echo -e "$RP_BG$RP_FG" `date +%H:%M` " $USER@$host$TOEND $BG_GREY ROOT WINDOW $RP_BG$RP_FG" `pwd` "$NEUTRAL"'
  PS1="$R1>$R2>$R3>$R4>$R5>$R6>$P "
else
  export PROMPT_COMMAND='echo -ne "\033];"${PWD##*/}"\007"; echo -e "$P_BG_DATE$P_FG_DATE" `date +%H:%M:%S` "$P_BG_HOST$P_FG_USER $USER$P_FG_AT@$P_FG_HOST$host $P_BG_EXTRA$P_FG_EXTRA$extra_pinfo $P_FG_SPACK`spack-env` $P_BG_EXTRA$P_FG_PWD$TOEND\n$P_BG_PWD$P_FG_PWD$TOEND" `pwd` "$NEUTRAL"'
  PS1="$P1>$P2>$P3>$P4>$P5>$P6>$P "
fi