#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly DEPLOYER="$ROOT/bin/bunny-deploy"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

export BUNNY_WORKSPACE="$ROOT"
# shellcheck disable=SC1090
source "$DEPLOYER"
load_configuration

test_canonical_dockerfile() {
  [[ -f "$ROOT/Dockerfile" ]] || fail 'canonical Dockerfile is missing'
  grep -F -- 'REPOSITORY_ROOT/Dockerfile"' "$ROOT/bin/deploy.sh" >/dev/null ||
    fail 'deployment wrapper does not use the canonical Dockerfile'
}

test_compose_launcher_starts_podman_socket() {
  local temporary fake_bin calls
  temporary="$(mktemp -d)"
  fake_bin="$temporary/bin"
  calls="$temporary/calls"
  mkdir -p "$fake_bin"
  trap 'rm -rf -- "$temporary"' RETURN

  cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'systemctl <%s>\n' "$*" >>"$MOCK_COMPOSE_CALLS"
if [[ "$*" == '--user is-active --quiet podman.socket' ]]; then
  exit 3
fi
EOF
  cat >"$fake_bin/podman" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'podman <%s>\n' "$*" >>"$MOCK_COMPOSE_CALLS"
EOF
  chmod +x "$fake_bin/systemctl" "$fake_bin/podman"

  PATH="$fake_bin:$PATH" MOCK_COMPOSE_CALLS="$calls" \
    "$ROOT/bin/compose.sh" "$fake_bin/podman" up dev

  grep -Fx -- 'systemctl <--user is-active --quiet podman.socket>' "$calls" >/dev/null ||
    fail 'Compose launcher did not inspect the Podman socket'
  grep -Fx -- 'systemctl <--user start podman.socket>' "$calls" >/dev/null ||
    fail 'Compose launcher did not start the inactive Podman socket'
  grep -Fx -- 'podman <compose up dev>' "$calls" >/dev/null ||
    fail 'Compose launcher did not invoke Podman Compose'
  if grep -Fx -- 'systemctl <--user stop podman.socket>' "$calls" >/dev/null; then
    fail 'Compose launcher stopped the socket before Compose cleanup completed'
  fi
}

test_release_validation() {
  bash -c 'source "$1"; validate_release "2026-09-07T120000Z-abcdef"' _ "$DEPLOYER"
  if bash -c 'source "$1"; validate_release "../logs"' _ "$DEPLOYER" >/dev/null 2>&1; then
    fail 'unsafe release name was accepted'
  fi
}

test_configuration_is_authoritative() {
  BUNNY_API_URL=http://wrong.test \
  BUNNY_STORAGE_ZONE=logs \
  BUNNY_SITE=wrong \
  BUNNY_SITE_HOSTNAME=wrong.test \
  BUNNY_PULL_ZONE_ID=99 \
  BUNNY_EDGE_RULE_DESCRIPTION=wrong \
  BUNNY_EDGE_RULE_GUID=wrong \
  BUNNY_EDGE_RULE_ORDER=99 \
  BUNNY_UPLOAD_CONCURRENCY=99 \
  BUNNY_RETAIN_RELEASES=99 \
  bash -c '
    source "$1"
    load_configuration
    [[ "$CORE_API_URL" == https://api.bunny.net ]]
    [[ "$STORAGE_ZONE" == ztec-fr-web ]]
    [[ "$SITE" == blog ]]
    [[ "$SITE_HOSTNAME" == blog.ztec.fr ]]
    [[ "$PULL_ZONE_ID" == 4889935 ]]
    [[ "$EDGE_RULE_DESCRIPTION" == "Managed storage release for blog.ztec.fr" ]]
    [[ -z "$EDGE_RULE_GUID" ]]
    [[ "$EDGE_RULE_ORDER" == preserve ]]
    [[ "$EDGE_RULE_PATTERN" == "*://blog.ztec.fr/*" ]]
    [[ "$RETAIN_RELEASES" == 3 ]]
    [[ "$UPLOAD_CONCURRENCY" == 8 ]]
  ' _ "$DEPLOYER" || fail 'environment variables overrode config.toml Bunny settings'
}

test_missing_configuration_fails() {
  local temporary
  temporary="$(mktemp -d)"
  trap 'rm -rf -- "$temporary"' RETURN

  if BUNNY_WORKSPACE="$temporary" bash -c 'source "$1"; load_configuration' _ "$DEPLOYER" >/dev/null 2>&1; then
    fail 'missing Bunny configuration was accepted'
  fi
}

test_invalid_configuration_fails() {
  local temporary
  temporary="$(mktemp -d)"
  trap 'rm -rf -- "$temporary"' RETURN
  cp "$ROOT/config.toml" "$temporary/config.toml"
  sed -i 's/pull_zone_id = 4889935/pull_zone_id = "invalid"/' "$temporary/config.toml"

  if BUNNY_WORKSPACE="$temporary" bash -c 'source "$1"; load_configuration' _ "$DEPLOYER" >/dev/null 2>&1; then
    fail 'invalid Bunny configuration was accepted'
  fi
}

test_full_cache_purge_has_no_tag_filter() {
  BUNNY_CACHE_TAG='*page*' bash -c '
    source "$1"
    load_configuration
    core_request() {
      [[ "$1" == POST ]]
      [[ "$2" == "/pullzone/4889935/purgeCache" ]]
      [[ "$3" == "{}" ]]
    }
    purge_cache
  ' _ "$DEPLOYER" || fail 'cache purge still applied a CDN tag filter'
}

test_edge_payload() {
  local payload
  # shellcheck disable=SC2034
  STORAGE_ZONE_ID=1234
  MANAGED_RULE_JSON=''
  payload="$(edge_rule_payload '2026-09-07T120000Z-abcdef')"
  jq -e '
    .ActionType == 17
    and .ActionParameter1 == "1234"
    and .ActionParameter2 == "ztec-fr-web"
    and .ActionParameter3 == "/blog/2026-09-07T120000Z-abcdef/"
    and .Triggers == [{Type: 0, PatternMatches: ["*://blog.ztec.fr/*"], PatternMatchingType: 0}]
  ' <<<"$payload" >/dev/null || fail 'edge rule payload is incorrect'
}

test_current_release_listing() {
  local output
  # shellcheck disable=SC2034
  STORAGE_ZONE_ID=1234
  # shellcheck disable=SC2034
  MANAGED_RULE_JSON='{
    "ActionType": 17,
    "ActionParameter1": "1234",
    "ActionParameter2": "ztec-fr-web",
    "ActionParameter3": "/blog/2026-09-07T120000Z-current/"
  }'
  RELEASES_JSON='["2026-09-06T120000Z-old", "2026-09-07T120000Z-current"]'
  output="$(print_releases)"
  grep -Eq '^2026-09-07T120000Z-current +current$' <<<"$output" ||
    fail 'current release was not identified in the listing'
  grep -Eq '^2026-09-06T120000Z-old +available$' <<<"$output" ||
    fail 'rollback release was not identified in the listing'
}

test_storage_zone_resolution() {
  bash -c '
    source "$1"
    load_configuration
    core_request() {
      printf "%s\n" '\''{"Items":[{"Id":1234,"Name":"ztec-fr-web","Password":"storage-password","StorageHostname":"storage.test","Region":"DE"}]}'\''
    }
    resolve_storage_zone
    [[ "$STORAGE_ZONE_ID" == 1234 ]]
    [[ "$STORAGE_PASSWORD" == storage-password ]]
    [[ "$STORAGE_HOSTNAME" == storage.test ]]
  ' _ "$DEPLOYER" || fail 'storage zone was not resolved from the account API response'
}

test_delete_release_uses_directory_object_url() {
  local requested_url=''
  # shellcheck disable=SC2034
  STORAGE_HOSTNAME=storage.test
  # shellcheck disable=SC2034
  STORAGE_PASSWORD=test-storage-password
  request() { requested_url="$3"; }

  delete_release '2026-09-07T120000Z-old'
  [[ "$requested_url" == 'https://storage.test/ztec-fr-web/blog/2026-09-07T120000Z-old' ]] ||
    fail "unexpected recursive delete URL: $requested_url"
}

test_retention_keeps_selected_and_two_newest() {
  local deleted
  refresh_pull_zone() { :; }
  select_managed_rule() { :; }
  refresh_releases() {
    # shellcheck disable=SC2034
    RELEASES_JSON='["2026-09-01T120000Z-a", "2026-09-02T120000Z-b", "2026-09-03T120000Z-c", "2026-09-04T120000Z-d"]'
  }
  current_release() { printf '%s\n' '2026-09-02T120000Z-b'; }
  delete_release() { printf '%s\n' "$1"; }

  deleted="$(prune_releases 2>/dev/null)"
  [[ "$deleted" == '2026-09-01T120000Z-a' ]] || fail "unexpected pruned releases: $deleted"
}

test_hugo_cache_is_reused() {
  local temporary fake_bin
  temporary="$(mktemp -d)"
  fake_bin="$temporary/bin"
  mkdir -p "$fake_bin" "$temporary/workspace/themes/VHS"
  touch "$temporary/workspace/config.toml" "$temporary/workspace/themes/VHS/theme.toml"
  trap 'rm -rf -- "$temporary"' RETURN

  cat >"$fake_bin/hugo" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
destination=''
cache_dir=''
while (($#)); do
  case "$1" in
    --destination) destination="$2"; shift 2 ;;
    --cacheDir) cache_dir="$2"; shift 2 ;;
    --source) shift 2 ;;
    *) shift ;;
  esac
done
[[ "$cache_dir" == "$EXPECTED_CACHE_ROOT/downloads" ]]
[[ "$HUGO_RESOURCEDIR" == "$EXPECTED_CACHE_ROOT/resources" ]]
if [[ -f "$cache_dir/primed" && -f "$HUGO_RESOURCEDIR/primed" ]]; then
  touch "$EXPECTED_CACHE_ROOT/reused"
fi
touch "$cache_dir/primed" "$HUGO_RESOURCEDIR/primed"
mkdir -p "$destination"
printf '<html></html>\n' >"$destination/index.html"
EOF
  chmod +x "$fake_bin/hugo"

  PATH="$fake_bin:$PATH" \
    BUNNY_HUGO_CACHE_ROOT="$temporary/cache" \
    BUNNY_WORKSPACE="$temporary/workspace" \
    EXPECTED_CACHE_ROOT="$temporary/cache" \
    bash -c 'source "$1"; build_site "$2/first"; build_site "$2/second"' \
      _ "$DEPLOYER" "$temporary"

  [[ -f "$temporary/cache/reused" ]] || fail 'Hugo cache was not reused between builds'
}

test_wrapper_mounts_writable_cache() {
  local temporary fake_engine arguments expected_user
  temporary="$(mktemp -d)"
  fake_engine="$temporary/podman"
  arguments="$temporary/arguments"
  trap 'rm -rf -- "$temporary"' RETURN

  cat >"$fake_engine" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$@" >"$MOCK_CONTAINER_ARGUMENTS"
EOF
  chmod +x "$fake_engine"

  MOCK_CONTAINER_ARGUMENTS="$arguments" \
    BUNNY_CONTAINER_ENGINE="$fake_engine" \
    BUNNY_DEPLOY_SKIP_BUILD=true \
    BUNNY_HUGO_CACHE_DIR="$temporary/cache" \
    "$ROOT/bin/deploy.sh" list

  expected_user="$(id -u):$(id -g)"
  grep -Fx -- "$expected_user" "$arguments" >/dev/null || fail 'container does not run with the caller UID/GID'
  grep -Fx -- 'HOME=/tmp' "$arguments" >/dev/null || fail 'container HOME is not writable'
  grep -Fx -- 'BUNNY_HUGO_CACHE_ROOT=/cache' "$arguments" >/dev/null || fail 'container cache root is not configured'
  grep -Fx -- "$temporary/cache:/cache" "$arguments" >/dev/null || fail 'persistent Hugo cache is not mounted'
  grep -Fx -- '--userns=keep-id' "$arguments" >/dev/null || fail 'rootless Podman does not keep the caller UID/GID'
  [[ -d "$temporary/cache" ]] || fail 'host Hugo cache directory was not created'
}

test_wrapper_copy_mode_uses_no_volumes() {
  local temporary fake_engine calls
  temporary="$(mktemp -d)"
  fake_engine="$temporary/docker"
  calls="$temporary/calls"
  mkdir -p "$temporary/cache/downloads"
  touch "$temporary/cache/downloads/seed"
  trap 'rm -rf -- "$temporary"' RETURN

  cat >"$fake_engine" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
{
  printf 'CALL'
  printf ' <%s>' "$@"
  printf '\n'
} >>"$MOCK_CONTAINER_CALLS"
case "$1" in
  create)
    printf '%s\n' 'container-123'
    ;;
  cp)
    if [[ "${3:-}" == '-' ]]; then
      cat >/dev/null
    else
      mkdir -p "$3"
      touch "$3/exported"
    fi
    ;;
  start|rm)
    ;;
  *)
    printf 'unexpected fake container command: %s\n' "$1" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$fake_engine"

  MOCK_CONTAINER_CALLS="$calls" \
    BUNNY_CONTAINER_ENGINE="$fake_engine" \
    BUNNY_DEPLOY_COPY_MODE=true \
    BUNNY_DEPLOY_SKIP_BUILD=true \
    BUNNY_HUGO_CACHE_DIR="$temporary/cache" \
    "$ROOT/bin/deploy.sh" help

  grep -F -- 'CALL <create>' "$calls" >/dev/null || fail 'copy mode did not create a container'
  grep -F -- 'CALL <cp> <--archive> <-> <container-123:/workspace>' "$calls" >/dev/null || fail 'source was not copied into the container'
  grep -F -- 'CALL <cp> <--archive> <-> <container-123:/cache>' "$calls" >/dev/null || fail 'cache was not restored into the container'
  grep -F -- 'CALL <start> <--attach> <container-123>' "$calls" >/dev/null || fail 'copied container was not started'
  grep -F -- 'CALL <cp> <container-123:/cache/.>' "$calls" >/dev/null || fail 'updated cache was not exported'
  if grep -F -- '--volume' "$calls" >/dev/null; then
    fail 'copy mode attempted to use a container volume'
  fi
  [[ -f "$temporary/cache/exported" ]] || fail 'updated copy-mode cache was not stored on the runner'
}

test_list_command_with_mock_api() {
  local temporary fake_bin output
  temporary="$(mktemp -d)"
  fake_bin="$temporary/bin"
  mkdir -p "$fake_bin"
  trap 'rm -rf -- "$temporary"' RETURN

  cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
method=GET
output=''
url=''
while (($#)); do
  case "$1" in
    --request) method="$2"; shift 2 ;;
    --header|--write-out|--data|--upload-file) shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --silent|--show-error|--location|--retry-all-errors) shift ;;
    --retry) shift 2 ;;
    *) url="$1"; shift ;;
  esac
done
case "$method $url" in
  'GET https://api.bunny.net/storagezone?search=ztec-fr-web&perPage=1000')
    body='{"Items":[{"Id":1234,"Name":"ztec-fr-web","Password":"test-storage-password","StorageHostname":"storage.test","Region":"DE"}]}'
    status=200
    ;;
  'GET https://api.bunny.net/pullzone/4889935')
    body='{"Id":4889935,"Hostnames":[{"Value":"*.ztec.fr"}],"EdgeRules":[{"Guid":"rule-1","ActionType":17,"ActionParameter1":"1234","ActionParameter2":"ztec-fr-web","ActionParameter3":"/blog/2026-09-07T120000Z-current/","Description":"Managed storage release for blog.ztec.fr","Enabled":true,"OrderIndex":2}]}'
    status=200
    ;;
  'GET https://storage.test/ztec-fr-web/blog/')
    body='[{"ObjectName":"2026-09-06T120000Z-previous","IsDirectory":true},{"ObjectName":"2026-09-07T120000Z-current","IsDirectory":true}]'
    status=200
    ;;
  *)
    body="unexpected request: $method $url"
    status=500
    ;;
esac
printf '%s' "$body" >"$output"
printf '%s' "$status"
EOF
  chmod +x "$fake_bin/curl"

  output="$(
    PATH="$fake_bin:$PATH" \
    BUNNY_API_KEY=test \
    "$DEPLOYER" list
  )"
  grep -Eq '^2026-09-07T120000Z-current +current$' <<<"$output" || fail 'mock API current release was not identified'
  grep -Eq '^2026-09-06T120000Z-previous +available$' <<<"$output" || fail 'mock API rollback release was not identified'
}

test_rollback_command_with_mock_api() {
  local temporary fake_bin output
  temporary="$(mktemp -d)"
  fake_bin="$temporary/bin"
  mkdir -p "$fake_bin"
  printf '%s\n' '2026-09-07T120000Z-current' >"$temporary/current"
  trap 'rm -rf -- "$temporary"' RETURN

  cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
method=GET
output=''
data=''
url=''
while (($#)); do
  case "$1" in
    --request) method="$2"; shift 2 ;;
    --header|--write-out|--upload-file) shift 2 ;;
    --data) data="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --silent|--show-error|--location|--retry-all-errors) shift ;;
    --retry) shift 2 ;;
    *) url="$1"; shift ;;
  esac
done
current="$(<"$MOCK_STATE_FILE")"
case "$method $url" in
  'GET https://api.bunny.net/storagezone?search=ztec-fr-web&perPage=1000')
    body='{"Items":[{"Id":1234,"Name":"ztec-fr-web","Password":"test-storage-password","StorageHostname":"storage.test","Region":"DE"}]}'
    status=200
    ;;
  'GET https://api.bunny.net/pullzone/4889935')
    body="{\"Id\":4889935,\"Hostnames\":[{\"Value\":\"blog.ztec.fr\"}],\"EdgeRules\":[{\"Guid\":\"rule-1\",\"ActionType\":17,\"ActionParameter1\":\"1234\",\"ActionParameter2\":\"ztec-fr-web\",\"ActionParameter3\":\"/blog/${current}/\",\"Description\":\"Managed storage release for blog.ztec.fr\",\"Enabled\":true,\"OrderIndex\":2}]}"
    status=200
    ;;
  'GET https://storage.test/ztec-fr-web/blog/')
    body='[{"ObjectName":"2026-09-05T120000Z-old","IsDirectory":true},{"ObjectName":"2026-09-06T120000Z-previous","IsDirectory":true},{"ObjectName":"2026-09-07T120000Z-current","IsDirectory":true}]'
    status=200
    ;;
  'POST https://api.bunny.net/pullzone/4889935/edgerules/addOrUpdate')
    jq -e '
      .Guid == "rule-1"
      and .OrderIndex == 2
      and .ActionType == 17
      and .ActionParameter3 == "/blog/2026-09-06T120000Z-previous/"
    ' <<<"$data" >/dev/null
    printf '%s\n' '2026-09-06T120000Z-previous' >"$MOCK_STATE_FILE"
    body='{}'
    status=200
    ;;
  'POST https://api.bunny.net/pullzone/4889935/purgeCache')
    jq -e '. == {}' <<<"$data" >/dev/null
    : >"$MOCK_PURGE_FILE"
    body='{}'
    status=204
    ;;
  *)
    body="unexpected request: $method $url"
    status=500
    ;;
esac
printf '%s' "$body" >"$output"
printf '%s' "$status"
EOF
  chmod +x "$fake_bin/curl"

  output="$(
    PATH="$fake_bin:$PATH" \
    MOCK_STATE_FILE="$temporary/current" \
    MOCK_PURGE_FILE="$temporary/purged" \
    BUNNY_API_KEY=test \
    "$DEPLOYER" rollback 2026-09-06T120000Z-previous
  )"
  [[ "$(<"$temporary/current")" == '2026-09-06T120000Z-previous' ]] || fail 'rollback did not switch the edge target'
  [[ -f "$temporary/purged" ]] || fail 'rollback did not purge the cache'
  grep -Eq '^2026-09-06T120000Z-previous +current$' <<<"$output" || fail 'rollback result did not mark the selected target current'
}

test_canonical_dockerfile
test_compose_launcher_starts_podman_socket
test_release_validation
test_configuration_is_authoritative
test_missing_configuration_fails
test_invalid_configuration_fails
test_full_cache_purge_has_no_tag_filter
test_edge_payload
test_current_release_listing
test_storage_zone_resolution
test_delete_release_uses_directory_object_url
test_retention_keeps_selected_and_two_newest
test_hugo_cache_is_reused
test_wrapper_mounts_writable_cache
test_wrapper_copy_mode_uses_no_volumes
test_list_command_with_mock_api
test_rollback_command_with_mock_api

printf 'All bunny deployment tests passed.\n'
