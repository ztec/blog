#!/usr/bin/env bash

set -Eeuo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_ROOT
readonly DEPLOY_IMAGE="${BUNNY_DEPLOY_IMAGE:-ztec-blog-bunny-deploy:local}"
readonly CONTAINER_ENGINE="${BUNNY_CONTAINER_ENGINE:-docker}"
readonly COPY_MODE="${BUNNY_DEPLOY_COPY_MODE:-false}"
HUGO_CACHE_DIRECTORY="${BUNNY_HUGO_CACHE_DIR:-$REPOSITORY_ROOT/.cache/hugo}"

if [[ "$HUGO_CACHE_DIRECTORY" != /* ]]; then
  HUGO_CACHE_DIRECTORY="$REPOSITORY_ROOT/$HUGO_CACHE_DIRECTORY"
fi
[[ "$HUGO_CACHE_DIRECTORY" != / ]] || {
  printf 'Refusing to mount the filesystem root as the Hugo cache\n' >&2
  exit 1
}
mkdir -p "$HUGO_CACHE_DIRECTORY"
HUGO_CACHE_DIRECTORY="$(cd "$HUGO_CACHE_DIRECTORY" && pwd -P)"
readonly HUGO_CACHE_DIRECTORY

command -v "$CONTAINER_ENGINE" >/dev/null 2>&1 || {
  printf 'Container engine not found: %s\n' "$CONTAINER_ENGINE" >&2
  exit 1
}
if [[ "$COPY_MODE" == "true" ]]; then
  command -v tar >/dev/null 2>&1 || {
    printf 'tar is required for copy-mode deployment\n' >&2
    exit 1
  }
elif [[ "$COPY_MODE" != "false" ]]; then
  printf 'BUNNY_DEPLOY_COPY_MODE must be true or false\n' >&2
  exit 1
fi

if [[ "${BUNNY_DEPLOY_SKIP_BUILD:-false}" != "true" ]]; then
  "$CONTAINER_ENGINE" build --file "$REPOSITORY_ROOT/Dockerfile" --tag "$DEPLOY_IMAGE" "$REPOSITORY_ROOT/bin"
fi

container_options=(
  --user "$(id -u):$(id -g)"
  --env HOME=/tmp
  --env BUNNY_HUGO_CACHE_ROOT=/cache
  --workdir /workspace
)
if [[ "${CONTAINER_ENGINE##*/}" == "podman" ]]; then
  container_options+=(--security-opt label=disable --userns=keep-id)
fi

environment_names=(
  BUNNY_API_KEY
  GITHUB_SHA
  PP_HOST
  PP_TOKEN
)

for environment_name in "${environment_names[@]}"; do
  if [[ -v "$environment_name" ]]; then
    container_options+=(--env "$environment_name")
  fi
done

if [[ "$COPY_MODE" == "true" ]]; then
  container_id="$("$CONTAINER_ENGINE" create "${container_options[@]}" "$DEPLOY_IMAGE" "$@")"
  readonly container_id

  cleanup_container() {
    "$CONTAINER_ENGINE" rm --force "$container_id" >/dev/null 2>&1 || true
  }
  trap cleanup_container EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  printf 'Copying source into deployment container\n' >&2
  tar --create --file - --directory "$REPOSITORY_ROOT" \
    --exclude='./.cache' \
    --exclude='./public' \
    --exclude='./resources' \
    --exclude='./logs' \
    . | "$CONTAINER_ENGINE" cp --archive - "$container_id:/workspace"

  if [[ -n "$(find "$HUGO_CACHE_DIRECTORY" -mindepth 1 -print -quit)" ]]; then
    printf 'Restoring Hugo cache into deployment container\n' >&2
    tar --create --file - --directory "$HUGO_CACHE_DIRECTORY" . |
      "$CONTAINER_ENGINE" cp --archive - "$container_id:/cache"
  fi

  container_status=0
  "$CONTAINER_ENGINE" start --attach "$container_id" || container_status=$?

  if ! "$CONTAINER_ENGINE" cp "$container_id:/cache/." "$HUGO_CACHE_DIRECTORY"; then
    printf 'Warning: could not copy the updated Hugo cache out of the container\n' >&2
  fi

  cleanup_container
  trap - EXIT INT TERM
  exit "$container_status"
fi

docker_args=(
  run --rm
  "${container_options[@]}"
  --volume "$REPOSITORY_ROOT:/workspace:ro"
  --volume "$HUGO_CACHE_DIRECTORY:/cache"
)

exec "$CONTAINER_ENGINE" "${docker_args[@]}" "$DEPLOY_IMAGE" "$@"
