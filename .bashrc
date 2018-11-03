#!/bin/bash

magicnt_python() {
  local _DOC="Create a Python container and create aliases for python and pip."
  local _DOC_PARAM_LIST="[version] [container_name]"
  local _DOC_PARAMS=(
    "[version]: Python image version, defaults to 'latest'"
    "[container_name]: defaults to current directory name"
  )
  _magicnt_doc $1 || return

  magicnt_activate python:${1:-latest} ${2:-_} "python" "pip"
}

magicnt_activate() {
  local _DOC="Create a container from the image given, with the name given, if missing."
  local _DOC_PARAM_LIST="<image:tag> [container_name] [aliases] [root_aliases]"
  local _DOC_PARAMS=(
    "<image:tag>: from the configured docker registry"
    "[container_name]: defaults to current directory name"
    "[aliases]: aliases to be set from the current shell to the container, space separated."
    "[root_aliases]: the same as [aliases], but run as root"
  )
  _magicnt_doc $1 || return

  if [[ $MAGICNT_IMAGE ]] || [[ $MAGICNT_NAME ]]; then
    echo "Looks like you already have an active magic container: '$MAGICNT_NAME'."
    return 1
  fi

  MAGICNT_IMAGE="$1"; shift
  MAGICNT_NAME="${1:-_}"; shift
  [[ $MAGICNT_NAME = _ ]] &&
    MAGICNT_NAME="$(basename "$(pwd)")"
  if ! _magicnt_container_create_if_missing "$MAGICNT_NAME" "$MAGICNT_IMAGE"; then
    unset MAGICNT_IMAGE MAGICNT_NAME
    return 1
  fi

  in_container() {
    local _DOC="Run <command> (optionally as root) in container (works in subdirectories)."
    local _DOC_PARAM_LIST="[sudo] <command> [parameters...]"
    local _DOC_PARAMS=(
      "[sudo]: run as root"
      "<command> [parameters...]: command to run with its parameters"
    )
    _magicnt_doc $1 || return

    local user_param="-u $(id -u):$(id -g)"
    if [[ $1 == sudo ]]; then
      user_param=
      shift
    fi
    docker exec -w "$(pwd)" -ti $user_param "$MAGICNT_NAME" "$@"
  }
  in_container sudo useradd --uid $(id -u) $USER
  MAGICNT_ALIASES=
  magicnt_alias() {
    local _DOC="Alias <command> to the container one."
    local _DOC_PARAM_LIST="[sudo] <command>"
    local _DOC_PARAMS=(
      "[sudo]: run as root"
      "<command>: command name"
    )
    _magicnt_doc $1 || return

    local sudo=
    if [[ $1 == sudo ]]; then
      sudo='sudo'
      shift
    fi
    [[ $1 ]] &&
      alias $1="in_container $sudo $1" &&
      MAGICNT_ALIASES="$MAGICNT_ALIASES $1"
  }

  for cmd in $1; do
    magicnt_alias $cmd
  done

  for cmd in $2; do
    magicnt_alias sudo $cmd
  done

  CONTAINER_PS1_BACKUP="$PS1"
  PS1="$PS1<$MAGICNT_IMAGE:$MAGICNT_NAME> "
}

magicnt_deactivate() {
  local _DOC="Unalias everything and optionally destroy the container."
  local _DOC_PARAM_LIST="[keep]"
  local _DOC_PARAMS=(
    "[keep]: if omitted, the contaner is destroyed"
  )
  _magicnt_doc $1 || return

  for cmd in $MAGICNT_ALIASES; do
    unalias $cmd
  done
  PS1="$CONTAINER_PS1_BACKUP"
  [[ $1 == keep ]] ||
    _magicnt_container_remove "$MAGICNT_NAME"
  unset MAGICNT_IMAGE MAGICNT_NAME MAGICNT_ALIASES magicnt_alias in_container
}

_magicnt_container_exists() {
  docker inspect "$1" --format '{{.Id}}' &>/dev/null
}

_magicnt_container_remove() {
  _magicnt_container_exists "$1" &&
    docker rm -f "$1"
}

_magicnt_container_create_if_missing() {
  _magicnt_container_exists "$1" ||
    docker run \
      --detach \
      --name "$1" \
      --network host \
      -v "$(pwd)":"$(pwd)" \
      -w "$(pwd)" \
      "$2" tail -f /dev/null >/dev/null
}

_magicnt_doc() {
  [[ $1 = -h ]] || return

  echo "Usage: ${FUNCNAME[1]} $_DOC_PARAM_LIST"
  echo
  echo "$_DOC"
  echo
  for param in "${_DOC_PARAMS[@]}"; do
    echo "$param"
  done
  return 1
}
