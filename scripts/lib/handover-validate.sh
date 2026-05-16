#!/usr/bin/env bash
# Sourceable validation helpers for codex_dispatch_handover_v1 metadata.
# No shell options are set here; callers own their execution policy.

METADATA_REJECT_CHARS=${METADATA_REJECT_CHARS:-'single quote, double quote, backtick, dollar, semicolon, ampersand, pipe, redirect chars (< >), parens, braces, backslash, CR, LF, leading/trailing whitespace'}

handover_validate_metadata_value() {
  local field_name=${1-}
  local value=${2-}

  if [[ $# -ne 2 ]]; then
    printf 'handover-validate: reject %s: expected field_name and value\n' "${field_name:-<unknown>}" >&2
    return 1
  fi

  if [[ "$value" != "${value#"${value%%[![:space:]]*}"}" || "$value" != "${value%"${value##*[![:space:]]}"}" ]]; then
    printf 'handover-validate: reject %s: leading or trailing whitespace is not allowed\n' "$field_name" >&2
    return 1
  fi

  if [[ "$value" == *$'\r'* || "$value" == *$'\n'* ]]; then
    printf 'handover-validate: reject %s: control newline is not allowed\n' "$field_name" >&2
    return 1
  fi

  if [[ "$value" == *["'\"\`\$\;\&\|\<\>\(\)\{\}\\"]* ]]; then
    printf 'handover-validate: reject %s: shell metacharacter is not allowed\n' "$field_name" >&2
    return 1
  fi

  return 0
}

handover_reject() {
  local field_name=${1-<unknown>}
  local reason=${2-}

  printf 'handover-validate: reject %s: %s\n' "$field_name" "$reason" >&2
  return 1
}

handover_has_dotdot_segment() {
  local value=${1-}

  [[ "$value" == ".." || "$value" == ../* || "$value" == */.. || "$value" == */../* ]]
}

handover_extract_block() {
  local input=${1-}

  if [[ $# -eq 0 ]]; then
    input="$(cat)"
  fi

  awk '
    BEGIN { in_block = 0; found = 0; closed = 0; block = "" }
    /^```codex_dispatch_handover_v1$/ { in_block = 1; found = 1; next }
    in_block && /^```$/ { closed = 1; printf "%s", block; exit }
    in_block { block = block $0 ORS; next }
    END {
      if (!found) exit 1
      if (in_block && !closed) {
        print "handover-validate: reject handover_block: unterminated fence" > "/dev/stderr"
        exit 1
      }
    }
  ' <<<"$input"
}

handover_extract_metadata() {
  local block=${1-}

  awk '
    /^---$/ { found = 1; exit }
    { print }
    END { if (!found) exit 1 }
  ' <<<"$block"
}

handover_extract_body() {
  local block=${1-}

  awk '
    found { print; next }
    /^---$/ { found = 1; next }
    END { if (!found) exit 1 }
  ' <<<"$block"
}

handover_get_field() {
  local metadata=${1-}
  local key=${2-}
  local value

  if [[ $# -ne 2 || -z "$key" ]]; then
    handover_reject "${key:-field}" "expected metadata and key"
    return 1
  fi

  value="$(awk -F': ' -v key="$key" '$1 == key { print substr($0, length(key) + 3); found = 1; exit } END { if (!found) exit 1 }' <<<"$metadata")" || {
    handover_reject "$key" "missing required metadata field"
    return 1
  }
  printf '%s\n' "$value"
}

handover_validate_handover_version() {
  local value=${1-}

  handover_validate_metadata_value handover_version "$value" || return 1
  [[ "$value" == "1" ]] || handover_reject handover_version "only version 1 is accepted"
}

handover_validate_dispatch_route() {
  local value=${1-}

  handover_validate_metadata_value dispatch_route "$value" || return 1
  case "$value" in
    main_thread_bash_background|agent_codex_executor) return 0 ;;
    *) handover_reject dispatch_route "unknown dispatch route" ;;
  esac
}

handover_validate_working_dir() {
  local value=${1-}

  handover_validate_metadata_value working_dir "$value" || return 1
  [[ "$value" == /* ]] || handover_reject working_dir "must be an absolute path" || return 1
  [[ "${#value}" -le 4096 ]] || handover_reject working_dir "path is longer than 4096 bytes" || return 1
  ! handover_has_dotdot_segment "$value" || handover_reject working_dir "dot-dot path segment is not allowed" || return 1
  [[ -d "$value" ]] || handover_reject working_dir "directory does not exist"
}

handover_validate_brief_file() {
  local value=${1-}

  handover_validate_metadata_value brief_file "$value" || return 1
  [[ "$value" == /* ]] || handover_reject brief_file "must be an absolute path" || return 1
  [[ "$value" == /tmp/brief-* ]] || handover_reject brief_file "must start with /tmp/brief-" || return 1
  [[ "$value" == /tmp/brief-*.md ]] || handover_reject brief_file "must end with .md" || return 1
  [[ "$value" != /tmp/brief-*/* ]] || handover_reject brief_file "subdirectories are not allowed" || return 1
  ! handover_has_dotdot_segment "$value" || handover_reject brief_file "dot-dot path segment is not allowed" || return 1
  [[ ! -L "$value" ]] || handover_reject brief_file "symlink path is not allowed"
}

handover_validate_sandbox() {
  local value=${1-}

  handover_validate_metadata_value sandbox "$value" || return 1
  case "$value" in
    workspace-write|read-only) return 0 ;;
    danger-full-access) handover_reject sandbox "danger-full-access not supported by bash route; use Agent(codex-executor) fallback" ;;
    *) handover_reject sandbox "unsupported sandbox value" ;;
  esac
}

handover_validate_approval() {
  local value=${1-}

  handover_validate_metadata_value approval "$value" || return 1
  case "$value" in
    never) return 0 ;;
    on-failure|on-request|untrusted) handover_reject approval "approval value not supported by bash route; use Agent(codex-executor) fallback" ;;
    *) handover_reject approval "unsupported approval value" ;;
  esac
}

handover_validate_timeout() {
  local value=${1-}

  handover_validate_metadata_value timeout "$value" || return 1
  [[ "$value" =~ ^[0-9]+$ ]] || handover_reject timeout "must be an integer" || return 1
  [[ "$value" -ge 30 ]] || handover_reject timeout "must be at least 30 seconds" || return 1
  [[ "$value" -le 3600 ]] || handover_reject timeout "must be at most 3600 seconds"
}

handover_validate_model() {
  local value=${1-}

  handover_validate_metadata_value model "$value" || return 1
  [[ "$value" == "default" || "$value" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || handover_reject model "unsupported model name shape"
}

handover_validate_skip_git_check() {
  local value=${1-}

  handover_validate_metadata_value skip_git_check "$value" || return 1
  case "$value" in
    false) return 0 ;;
    true) handover_reject skip_git_check "skip_git_check:true not supported by bash route; use Agent(codex-executor) fallback" ;;
    *) handover_reject skip_git_check "must be false by default" ;;
  esac
}

handover_validate_fallback_allowed() {
  local value=${1-}

  handover_validate_metadata_value fallback_allowed "$value" || return 1
  case "$value" in
    true|false) return 0 ;;
    *) handover_reject fallback_allowed "must be true or false" ;;
  esac
}

handover_validate_required_fields() {
  local metadata=${1-}
  local field

  for field in handover_version dispatch_route working_dir brief_file sandbox approval timeout model skip_git_check fallback_allowed; do
    handover_get_field "$metadata" "$field" >/dev/null || return 1
  done
}

handover_validate_all_metadata() {
  local metadata=${1-}
  local value

  handover_validate_required_fields "$metadata" || return 1

  value="$(handover_get_field "$metadata" handover_version)" || return 1
  handover_validate_handover_version "$value" || return 1
  value="$(handover_get_field "$metadata" dispatch_route)" || return 1
  handover_validate_dispatch_route "$value" || return 1
  value="$(handover_get_field "$metadata" working_dir)" || return 1
  handover_validate_working_dir "$value" || return 1
  value="$(handover_get_field "$metadata" brief_file)" || return 1
  handover_validate_brief_file "$value" || return 1
  value="$(handover_get_field "$metadata" sandbox)" || return 1
  handover_validate_sandbox "$value" || return 1
  value="$(handover_get_field "$metadata" approval)" || return 1
  handover_validate_approval "$value" || return 1
  value="$(handover_get_field "$metadata" timeout)" || return 1
  handover_validate_timeout "$value" || return 1
  value="$(handover_get_field "$metadata" model)" || return 1
  handover_validate_model "$value" || return 1
  value="$(handover_get_field "$metadata" skip_git_check)" || return 1
  handover_validate_skip_git_check "$value" || return 1
  value="$(handover_get_field "$metadata" fallback_allowed)" || return 1
  handover_validate_fallback_allowed "$value"
}

handover_validate_working_dir_match() {
  local metadata_wd=${1-}
  local body_wd=${2-}

  [[ $# -eq 2 ]] || handover_reject working_dir "expected metadata and body working_dir" || return 1
  [[ -n "$body_wd" ]] || handover_reject working_dir "missing body working_dir" || return 1
  [[ "$metadata_wd" == "$body_wd" ]] || handover_reject working_dir "metadata and body working_dir mismatch"
}

handover_safe_argv() {
  local field_name=${1-}
  local value=${2-}

  if ! handover_validate_metadata_value "$field_name" "$value"; then
    return 1
  fi

  printf '%q\n' "$value"
}

export METADATA_REJECT_CHARS
export -f handover_reject
export -f handover_has_dotdot_segment
export -f handover_extract_block
export -f handover_extract_metadata
export -f handover_extract_body
export -f handover_get_field
export -f handover_validate_metadata_value
export -f handover_validate_handover_version
export -f handover_validate_dispatch_route
export -f handover_validate_working_dir
export -f handover_validate_brief_file
export -f handover_validate_sandbox
export -f handover_validate_approval
export -f handover_validate_timeout
export -f handover_validate_model
export -f handover_validate_skip_git_check
export -f handover_validate_fallback_allowed
export -f handover_validate_required_fields
export -f handover_validate_all_metadata
export -f handover_validate_working_dir_match
export -f handover_safe_argv
