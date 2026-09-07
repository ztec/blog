#!/usr/bin/env bash

set -Eeuo pipefail

[[ $# -gt 0 ]] || {
  printf 'Usage: %s CONTAINER_ENGINE [COMPOSE_ARGUMENT ...]\n' "${0##*/}" >&2
  exit 2
}

readonly CONTAINER_ENGINE="$1"
shift

if [[ "${CONTAINER_ENGINE##*/}" == podman ]] && command -v systemctl >/dev/null 2>&1; then
  if ! systemctl --user is-active --quiet podman.socket; then
    printf 'Starting the Podman API socket for the Compose provider\n' >&2
    systemctl --user start podman.socket || {
      printf 'Could not start podman.socket; run: systemctl --user start podman.socket\n' >&2
      exit 1
    }
  fi
fi

"$CONTAINER_ENGINE" compose "$@"
