#!/usr/bin/env bash
# Project-scoped canonical-memory config management.
# Source this file; public entrypoint: pmctl_memory_config.

_pm_memory_config_usage() {
  cat <<'EOF'
Usage:
  pmctl memory config set --repo-root <repo> --memory-dir <absolute-dir> [--json]
  pmctl memory config migrate --repo-root <repo> [--json]
  pmctl memory config lint [--json]

Config key: memory.projects.<stable-project-key>.dir = <absolute-dir>

`migrate` converts the deprecated machine-wide dispatch.memory_dir entry into
one project-scoped entry. Writes are atomic and preserve unrelated config.
EOF
}

_pm_memory_config_path() {
  printf '%s\n' "${PM_DISPATCH_CONFIG_FILE:-${HOME}/.pm-dispatch/config}"
}

_pm_memory_config_identity() {
  local requested="$1" repo_root project_key
  repo_root="$(cd "$requested" 2>/dev/null && pwd -P)" || {
    printf 'pmctl memory config: --repo-root must name an existing directory\n' >&2
    return 2
  }
  repo_root="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'pmctl memory config: --repo-root must be inside a git worktree\n' >&2
    return 2
  }
  declare -F pm_config_project_key >/dev/null 2>&1 || {
    printf 'pmctl memory config: stable project-key resolver unavailable\n' >&2
    return 1
  }
  project_key="$(pm_config_project_key "$repo_root")"
  [[ "$project_key" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'pmctl memory config: failed to derive a stable project key\n' >&2
    return 1
  }
  printf '%s\t%s\n' "$repo_root" "$project_key"
}

_pm_memory_config_write_guard() {
  local config="$1" parent nlink
  parent="$(dirname "$config")"
  if [[ -L "$parent" || ( -e "$parent" && ! -d "$parent" ) ]]; then
    printf 'pmctl memory config: refusing non-directory or symlinked config parent: %s\n' "$parent" >&2
    return 1
  fi
  if [[ -e "$config" ]]; then
    [[ -f "$config" && ! -L "$config" ]] || {
      printf 'pmctl memory config: refusing non-regular or symlinked config: %s\n' "$config" >&2
      return 1
    }
    nlink="$(stat -c '%h' "$config" 2>/dev/null || stat -f '%l' "$config" 2>/dev/null || printf '1')"
    [[ "$nlink" == "1" ]] || {
      printf 'pmctl memory config: refusing hardlinked config: %s\n' "$config" >&2
      return 1
    }
  fi
  mkdir -p "$parent" || return 1
  chmod 700 "$parent" 2>/dev/null || true
}

_pm_memory_config_set_value_inner() {
  local config="$1" key="$2" value="$3" remove_legacy="${4:-0}"
  local tmp
  tmp="$(mktemp "$(dirname "$config")/.config.tmp.XXXXXX")" || return 1
  chmod 600 "$tmp" 2>/dev/null || true
  if [[ -r "$config" ]]; then
    awk -v target="$key" -v remove_legacy="$remove_legacy" '
      {
        line=$0; parsed=line
        sub(/[[:space:]]*#.*/, "", parsed)
        split(parsed, fields, "=")
        k=fields[1]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
        if (k == target) next
        if (remove_legacy == "1" && k == "dispatch.memory_dir") next
        print line
      }
    ' "$config" > "$tmp" || { rm -f "$tmp"; return 1; }
  fi
  printf '%s = %s\n' "$key" "$value" >> "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$config"
}

_pm_memory_config_set_value() {
  local config="$1"
  _pm_memory_config_write_guard "$config" || return 1
  declare -F serialize_with_lock >/dev/null 2>&1 || {
    printf 'pmctl memory config: lock helper unavailable\n' >&2
    return 1
  }
  serialize_with_lock "$config" _pm_memory_config_set_value_inner "$@"
}

_pm_memory_config_emit() {
  local json="$1" action="$2" repo_root="$3" project_key="$4" memory_dir="$5" config="$6"
  if [[ "$json" -eq 1 ]]; then
    jq -cn --arg action "$action" --arg repo_root "$repo_root" --arg project_key "$project_key" \
      --arg memory_dir "$memory_dir" --arg config "$config" \
      '{schema_version:1,status:"ok",action:$action,repo_root:$repo_root,project_key:$project_key,memory_dir:$memory_dir,config_file:$config}'
  else
    printf 'status: ok\naction: %s\nrepo_root: %s\nproject_key: %s\nmemory_dir: %s\nconfig_file: %s\n' \
      "$action" "$repo_root" "$project_key" "$memory_dir" "$config"
  fi
}

_pm_memory_config_set() {
  local repo_root="" memory_dir="" json=0 identity project_key config
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root) [[ $# -ge 2 ]] || return 2; repo_root="$2"; shift 2 ;;
      --memory-dir) [[ $# -ge 2 ]] || return 2; memory_dir="$2"; shift 2 ;;
      --json) json=1; shift ;;
      *) printf 'pmctl memory config set: unknown argument: %s\n' "$1" >&2; return 2 ;;
    esac
  done
  [[ -n "$repo_root" && -n "$memory_dir" ]] || { _pm_memory_config_usage >&2; return 2; }
  [[ "$memory_dir" == /* && -d "$memory_dir" ]] || {
    printf 'pmctl memory config set: --memory-dir must be an existing absolute directory\n' >&2
    return 2
  }
  [[ "$memory_dir" != *$'\n'* && "$memory_dir" != *'#'* ]] || {
    printf 'pmctl memory config set: --memory-dir contains characters unsupported by the config format\n' >&2
    return 2
  }
  identity="$(_pm_memory_config_identity "$repo_root")" || return $?
  repo_root="${identity%%$'\t'*}"; project_key="${identity#*$'\t'}"
  memory_dir="$(cd "$memory_dir" && pwd -P)"
  config="$(_pm_memory_config_path)"
  # A successful scoped set supersedes and removes the unsafe global key so the
  # config is immediately lint-clean rather than leaving a latent cross-project
  # selector behind.
  _pm_memory_config_set_value "$config" "memory.projects.$project_key.dir" "$memory_dir" 1 || return 1
  _pm_memory_config_emit "$json" set "$repo_root" "$project_key" "$memory_dir" "$config"
}

_pm_memory_config_migrate() {
  local repo_root="" json=0 identity project_key config memory_dir
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root) [[ $# -ge 2 ]] || return 2; repo_root="$2"; shift 2 ;;
      --json) json=1; shift ;;
      *) printf 'pmctl memory config migrate: unknown argument: %s\n' "$1" >&2; return 2 ;;
    esac
  done
  [[ -n "$repo_root" ]] || { _pm_memory_config_usage >&2; return 2; }
  identity="$(_pm_memory_config_identity "$repo_root")" || return $?
  repo_root="${identity%%$'\t'*}"; project_key="${identity#*$'\t'}"
  config="$(_pm_memory_config_path)"
  declare -F pm_config_load >/dev/null 2>&1 || return 1
  pm_config_load "$project_key"
  memory_dir="${PM_CFG_LEGACY_MEMORY_DIR:-}"
  if [[ -z "$memory_dir" && "${PM_CFG_MEMORY_CONFIG_STATUS:-none}" == "matched" \
        && -d "${PM_CFG_MEMORY_DIR:-}" ]]; then
    memory_dir="$(cd "$PM_CFG_MEMORY_DIR" && pwd -P)"
    _pm_memory_config_emit "$json" migrate-noop "$repo_root" "$project_key" "$memory_dir" "$config"
    return 0
  fi
  [[ -n "$memory_dir" && -d "$memory_dir" ]] || {
    printf 'pmctl memory config migrate: no valid dispatch.memory_dir to migrate in %s\n' "$config" >&2
    return 1
  }
  memory_dir="$(cd "$memory_dir" && pwd -P)"
  _pm_memory_config_set_value "$config" "memory.projects.$project_key.dir" "$memory_dir" 1 || return 1
  _pm_memory_config_emit "$json" migrate "$repo_root" "$project_key" "$memory_dir" "$config"
}

_pm_memory_config_lint() {
  local json=0 config issues_file issue_count=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json=1; shift ;;
      *) printf 'pmctl memory config lint: unknown argument: %s\n' "$1" >&2; return 2 ;;
    esac
  done
  config="$(_pm_memory_config_path)"
  issues_file="$(mktemp)" || return 1
  if [[ -r "$config" ]]; then
    awk '
      {
        line=$0; parsed=line
        sub(/[[:space:]]*#.*/, "", parsed)
        if (parsed !~ /=/) next
        split(parsed, fields, "=")
        key=fields[1]; value=substr(parsed, index(parsed, "=")+1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        if (key == "dispatch.memory_dir") print NR "\tunsafe-legacy-global\t" key
        else if (key ~ /^memory\.projects\./ && key !~ /^memory\.projects\.[0-9a-f]{40}\.dir$/) print NR "\tmalformed-project-key\t" key
        else if (key ~ /^memory\.projects\.[0-9a-f]{40}\.dir$/) {
          if (seen[key]++) print NR "\tduplicate-project-key\t" key
          if (value !~ /^\//) print NR "\tnon-absolute-memory-dir\t" key
        }
      }
    ' "$config" > "$issues_file"
    local line_no=0 line parsed key value
    while IFS= read -r line || [[ -n "$line" ]]; do
      line_no=$((line_no + 1))
      parsed="${line%%#*}"
      [[ "$parsed" == *"="* ]] || continue
      key="${parsed%%=*}"; value="${parsed#*=}"
      key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
      value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"
      if [[ "$key" =~ ^memory\.projects\.[0-9a-f]{40}\.dir$ && "$value" == /* && ! -d "$value" ]]; then
        printf '%s\tmissing-memory-dir\t%s\n' "$line_no" "$key" >> "$issues_file"
      fi
    done < "$config"
  fi
  issue_count="$(wc -l < "$issues_file" | tr -d ' ')"
  if [[ "$json" -eq 1 ]]; then
    jq -Rn --arg config "$config" --argjson count "$issue_count" '
      [inputs | split("\t") | {line:(.[0]|tonumber),code:.[1],key:.[2]}] as $issues |
      {schema_version:1,status:(if $count == 0 then "ok" else "issues" end),config_file:$config,issues_count:$count,issues:$issues}
    ' < "$issues_file"
  else
    printf 'config_file: %s\nissues_count: %s\n' "$config" "$issue_count"
    while IFS=$'\t' read -r line code key; do
      [[ -n "$line" ]] && printf '  line %s: %s (%s)\n' "$line" "$code" "$key"
    done < "$issues_file"
  fi
  rm -f "$issues_file"
  [[ "$issue_count" -eq 0 ]]
}

pmctl_memory_config() {
  local action="${1:-}"
  [[ $# -gt 0 ]] && shift
  case "$action" in
    set) _pm_memory_config_set "$@" ;;
    migrate) _pm_memory_config_migrate "$@" ;;
    lint) _pm_memory_config_lint "$@" ;;
    -h|--help|"") _pm_memory_config_usage ;;
    *) printf 'pmctl memory config: unknown action: %s\n' "$action" >&2; return 2 ;;
  esac
}
