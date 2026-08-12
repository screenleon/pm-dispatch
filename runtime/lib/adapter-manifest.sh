#!/usr/bin/env bash
# Canonical Adapter manifest reader and dispatch-entrypoint resolver.
#
# This library owns the adapter.yaml trust boundary.  Callers must not parse
# manifest scalars themselves or derive an executable from a filename
# convention.  No shell options are changed while this file is sourced.

_ADAPTER_MANIFEST_LIB_DIR="${BASH_SOURCE[0]%/*}"
[[ "$_ADAPTER_MANIFEST_LIB_DIR" != "${BASH_SOURCE[0]}" ]] || _ADAPTER_MANIFEST_LIB_DIR=.

if ! declare -F pm_identifier_adapter_is_valid >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/identifier-policy.sh
  # shellcheck disable=SC1091
  . "$_ADAPTER_MANIFEST_LIB_DIR/identifier-policy.sh"
fi
if ! declare -F runner_kind_valid >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/runner-kind.sh
  # shellcheck disable=SC1091
  . "$_ADAPTER_MANIFEST_LIB_DIR/runner-kind.sh"
fi

_adapter_manifest_error() {
  printf 'adapter-manifest: %s\n' "$*" >&2
  return 2
}

# adapter_manifest_scalar <manifest-path> <top-level-key>
#
# Read one flat top-level YAML scalar without evaluating it.  Adapter manifests
# intentionally keep runtime-owned fields flat.  Duplicate keys are rejected so
# every consumer observes one value rather than depending on parser ordering.
# An absent key prints nothing and succeeds, allowing callers to apply an
# explicitly documented default.
adapter_manifest_scalar() {
  local manifest=${1-} key=${2-} line value="" count=0

  [[ $# -eq 2 ]] || {
    _adapter_manifest_error 'adapter_manifest_scalar expects <manifest-path> <top-level-key>'
    return 2
  }
  [[ "$key" =~ ^[a-z][a-z0-9_]*$ ]] || {
    _adapter_manifest_error "invalid manifest key: $key"
    return 2
  }
  [[ -r "$manifest" && -f "$manifest" && ! -L "$manifest" ]] || {
    _adapter_manifest_error "manifest must be a readable regular non-symlink file: $manifest"
    return 2
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "$key":*)
        count=$((count + 1))
        [[ "$count" -eq 1 ]] || {
          _adapter_manifest_error "duplicate top-level key '$key' in $manifest"
          return 2
        }
        value=${line#"$key":}
        value=${value%%#*}
        value=${value#"${value%%[![:space:]]*}"}
        value=${value%"${value##*[![:space:]]}"}
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
          value=${value#\"}; value=${value%\"}
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
          value=${value#\'}; value=${value%\'}
        fi
        ;;
    esac
  done < "$manifest"

  printf '%s\n' "$value"
}

# adapter_manifest_has_key <manifest-path> <top-level-key>
# Return 0 when the key occurs exactly once, 1 when absent, and 2 for invalid
# input or a duplicate. This keeps "missing" distinct from "present but empty"
# for required fields and compatibility defaults.
adapter_manifest_has_key() {
  local manifest=${1-} key=${2-} line count=0
  [[ $# -eq 2 ]] || {
    _adapter_manifest_error 'adapter_manifest_has_key expects <manifest-path> <top-level-key>'
    return 2
  }
  [[ "$key" =~ ^[a-z][a-z0-9_]*$ ]] || {
    _adapter_manifest_error "invalid manifest key: $key"
    return 2
  }
  [[ -r "$manifest" && -f "$manifest" && ! -L "$manifest" ]] || {
    _adapter_manifest_error "manifest must be a readable regular non-symlink file: $manifest"
    return 2
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "$key":*)
        count=$((count + 1))
        [[ "$count" -eq 1 ]] || {
          _adapter_manifest_error "duplicate top-level key '$key' in $manifest"
          return 2
        }
        ;;
    esac
  done < "$manifest"
  [[ "$count" -eq 1 ]]
}

# adapter_manifest_file <repo-root> <adapter>
# Print the validated manifest path.  The adapter name, directory, and manifest
# are all checked at this boundary before any field is trusted.
adapter_manifest_file() {
  local repo_root=${1-} adapter=${2-}
  local adapters_dir adapter_dir manifest adapters_real adapter_real schema declared_name

  [[ $# -eq 2 ]] || {
    _adapter_manifest_error 'adapter_manifest_file expects <repo-root> <adapter>'
    return 2
  }
  pm_identifier_adapter_is_valid "$adapter" || {
    _adapter_manifest_error "invalid adapter name: ${adapter:-<empty>}"
    return 2
  }

  adapters_dir="$repo_root/adapters"
  adapter_dir="$adapters_dir/$adapter"
  manifest="$adapter_dir/adapter.yaml"
  [[ -d "$adapters_dir" ]] || {
    _adapter_manifest_error "adapters directory not found: $adapters_dir"
    return 2
  }
  [[ -d "$adapter_dir" && ! -L "$adapter_dir" ]] || {
    _adapter_manifest_error "adapter directory must be a real directory: $adapter_dir"
    return 2
  }
  [[ -r "$manifest" && -f "$manifest" && ! -L "$manifest" ]] || {
    _adapter_manifest_error "manifest must be a readable regular non-symlink file: $manifest"
    return 2
  }

  adapters_real="$(cd -P -- "$adapters_dir" 2>/dev/null && pwd -P)" || {
    _adapter_manifest_error "cannot resolve adapters directory: $adapters_dir"
    return 2
  }
  adapter_real="$(cd -P -- "$adapter_dir" 2>/dev/null && pwd -P)" || {
    _adapter_manifest_error "cannot resolve adapter directory: $adapter_dir"
    return 2
  }
  case "$adapter_real" in
    "$adapters_real"/*) ;;
    *)
      _adapter_manifest_error "adapter directory escapes adapters/: $adapter_dir"
      return 2
      ;;
  esac

  schema="$(adapter_manifest_scalar "$manifest" schema_version)" || return 2
  [[ "$schema" == 1 ]] || {
    _adapter_manifest_error "unsupported schema_version '${schema:-<missing>}' in $manifest (expected 1)"
    return 2
  }
  declared_name="$(adapter_manifest_scalar "$manifest" adapter_name)" || return 2
  [[ "$declared_name" == "$adapter" ]] || {
    _adapter_manifest_error "adapter_name '${declared_name:-<missing>}' does not match directory '$adapter'"
    return 2
  }

  printf '%s\n' "$manifest"
}

adapter_manifest_runner_kind() {
  local repo_root=${1-} adapter=${2-} manifest runner_kind
  [[ $# -eq 2 ]] || {
    _adapter_manifest_error 'adapter_manifest_runner_kind expects <repo-root> <adapter>'
    return 2
  }
  manifest="$(adapter_manifest_file "$repo_root" "$adapter")" || return 2
  runner_kind="$(adapter_manifest_scalar "$manifest" runner_kind)" || return 2
  runner_kind_valid "$runner_kind" || {
    _adapter_manifest_error "adapter '$adapter' declares invalid runner_kind '${runner_kind:-<missing>}'"
    return 2
  }
  printf '%s\n' "$runner_kind"
}

adapter_manifest_effective_route() {
  local repo_root=${1-} adapter=${2-} manifest runner_kind override
  [[ $# -eq 2 ]] || {
    _adapter_manifest_error 'adapter_manifest_effective_route expects <repo-root> <adapter>'
    return 2
  }
  manifest="$(adapter_manifest_file "$repo_root" "$adapter")" || return 2
  runner_kind="$(adapter_manifest_runner_kind "$repo_root" "$adapter")" || return 2
  override="$(adapter_manifest_scalar "$manifest" dispatch_route)" || return 2
  runner_kind_resolve_flag "$runner_kind" dispatch_route "$override"
}

# _adapter_manifest_dispatch_ref <manifest>
#
# dispatch_entrypoint is the only new runtime authority.  During the schema-v1
# migration window, manifests without it retain the historical *runtime*
# behavior (`./dispatch.sh`) irrespective of runner_ref.  In particular,
# runner_ref=./run.sh was generated as a user wrapper and must never recurse
# back into pmctl as an executor.  The compatibility path is intentionally
# noisy so custom adapters can migrate before the public-contract freeze.
_adapter_manifest_dispatch_ref() {
  local manifest=${1-} canonical legacy present_rc=0
  canonical="$(adapter_manifest_scalar "$manifest" dispatch_entrypoint)" || return 2
  legacy="$(adapter_manifest_scalar "$manifest" runner_ref)" || return 2

  adapter_manifest_has_key "$manifest" dispatch_entrypoint || present_rc=$?
  [[ "$present_rc" -ne 2 ]] || return 2
  if [[ "$present_rc" -eq 0 ]]; then
    [[ -n "$canonical" ]] || {
      _adapter_manifest_error "dispatch_entrypoint is present but empty in $manifest"
      return 2
    }
    if [[ -n "$legacy" ]]; then
      printf 'adapter-manifest: warning: runner_ref is deprecated and ignored by runtime; dispatch_entrypoint is authoritative in %s\n' "$manifest" >&2
    fi
    printf '%s\n' "$canonical"
    return 0
  fi

  printf 'adapter-manifest: warning: schema v1 manifest lacks dispatch_entrypoint; using deprecated ./dispatch.sh compatibility default: %s\n' "$manifest" >&2
  printf './dispatch.sh\n'
}

_adapter_manifest_ref_is_safe() {
  local ref=${1-} remainder part
  local -a parts

  [[ "$ref" == ./* && "$ref" != ./ ]] || return 1
  case "$ref" in
    *\\*|*$'\n'*|*$'\r'*|*$'\t'*) return 1 ;;
  esac
  remainder=${ref#./}
  [[ -n "$remainder" && "$remainder" != */ && "$remainder" != *//* ]] || return 1
  IFS='/' read -r -a parts <<< "$remainder"
  for part in "${parts[@]}"; do
    [[ -n "$part" && "$part" != . && "$part" != .. \
      && "$part" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  done
  return 0
}

# adapter_manifest_dispatch_path <repo-root> <adapter>
# Print the validated absolute/anchored executable path from adapter.yaml.
adapter_manifest_dispatch_path() {
  local repo_root=${1-} adapter=${2-} manifest ref adapter_dir target walk part remainder
  local adapter_real parent_real route
  local -a parts

  [[ $# -eq 2 ]] || {
    _adapter_manifest_error 'adapter_manifest_dispatch_path expects <repo-root> <adapter>'
    return 2
  }
  manifest="$(adapter_manifest_file "$repo_root" "$adapter")" || return 2
  adapter_manifest_runner_kind "$repo_root" "$adapter" >/dev/null || return 2
  route="$(adapter_manifest_effective_route "$repo_root" "$adapter")" || return 2
  [[ "$route" == main_thread_bash_background ]] || {
    _adapter_manifest_error "adapter '$adapter' resolves dispatch_route '$route'; a shell dispatch_entrypoint requires main_thread_bash_background"
    return 2
  }

  ref="$(_adapter_manifest_dispatch_ref "$manifest")" || return 2
  _adapter_manifest_ref_is_safe "$ref" || {
    _adapter_manifest_error "dispatch_entrypoint must be a safe ./-relative path without dot, empty, backslash, or control-character components: ${ref:-<missing>}"
    return 2
  }

  adapter_dir=${manifest%/adapter.yaml}
  target="$adapter_dir/${ref#./}"
  remainder=${ref#./}
  IFS='/' read -r -a parts <<< "$remainder"
  walk=$adapter_dir
  for part in "${parts[@]}"; do
    walk="$walk/$part"
    [[ ! -L "$walk" ]] || {
      _adapter_manifest_error "dispatch_entrypoint must not traverse a symlink: $walk"
      return 2
    }
  done
  [[ -f "$target" ]] || {
    _adapter_manifest_error "dispatch_entrypoint is missing or not a regular file: $target"
    return 2
  }
  [[ -x "$target" ]] || {
    _adapter_manifest_error "dispatch_entrypoint is not executable: $target"
    return 2
  }

  adapter_real="$(cd -P -- "$adapter_dir" 2>/dev/null && pwd -P)" || return 2
  parent_real="$(cd -P -- "${target%/*}" 2>/dev/null && pwd -P)" || {
    _adapter_manifest_error "cannot resolve dispatch_entrypoint parent: ${target%/*}"
    return 2
  }
  case "$parent_real" in
    "$adapter_real"|"$adapter_real"/*) ;;
    *)
      _adapter_manifest_error "dispatch_entrypoint escapes adapter directory: $target"
      return 2
      ;;
  esac

  printf '%s\n' "$target"
}

# Enumerate only complete, dispatchable manifests. Invalid entries are skipped;
# their direct use still produces the detailed resolver diagnostic above.
adapter_manifest_names() {
  local repo_root=${1-} adapter_dir adapter
  [[ $# -eq 1 ]] || {
    _adapter_manifest_error 'adapter_manifest_names expects <repo-root>'
    return 2
  }
  for adapter_dir in "$repo_root"/adapters/*; do
    [[ -d "$adapter_dir" ]] || continue
    adapter=${adapter_dir##*/}
    adapter_manifest_dispatch_path "$repo_root" "$adapter" >/dev/null 2>&1 || continue
    printf '%s\n' "$adapter"
  done
}

export -f adapter_manifest_scalar
export -f adapter_manifest_has_key
export -f adapter_manifest_file
export -f adapter_manifest_runner_kind
export -f adapter_manifest_effective_route
export -f adapter_manifest_dispatch_path
export -f adapter_manifest_names
export -f _adapter_manifest_error
export -f _adapter_manifest_dispatch_ref
export -f _adapter_manifest_ref_is_safe

unset _ADAPTER_MANIFEST_LIB_DIR
