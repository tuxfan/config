#! /usr/bin/env bash

_chspk_completion() {
  if [ "${#COMP_WORDS[@]}" != "2" ]; then
    return
  fi
  current=`/bin/ls -l $HOME/.spack | sed 's,^.*/,,g'`
  spks=`/bin/ls $HOME/.spack.d`

  opts=""
  for spk in $spks ; do
    [ "$spk" != "$current" ] && opts=`echo $opts $spk`
  done

  COMPREPLY=($(compgen -W "$opts" "${COMP_WORDS[1]}"))
}

complete -F _chspk_completion chspk
