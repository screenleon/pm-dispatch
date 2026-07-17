#!/usr/bin/env bash

pmctl_command_catalog_die() {
  printf 'pmctl: %s\n' "$*" >&2
  return 2
}

pmctl_command_catalog_require_registry() {
  [[ -r "${PMCTL_COMMAND_REGISTRY:-}" ]] || {
    pmctl_command_catalog_die "command registry unavailable"
    return 2
  }
}

pmctl_command_catalog_root_help() {
  pmctl_command_catalog_require_registry || return
  cat <<'EOF'
pmctl — project-maintenance runtime CLI

Usage:
  pmctl <area> <command> [options]
  pmctl help <area> [command]
  pmctl commands --json

Stability: experimental

Command areas:
EOF
  awk -F '\t' 'NR > 1 {
    split($1, part, " ")
    if (!seen[part[1]]++) printf "  %-14s %s\n", part[1], $2
  }' "$PMCTL_COMMAND_REGISTRY"
  cat <<'EOF'

Examples:
  pmctl help task
  pmctl task list --json
  pmctl commands --json

Run "pmctl help <area>" to discover the next level.
EOF
}

pmctl_command_catalog_area_help() {
  local area="$1" direct
  pmctl_command_catalog_require_registry || return
  if ! awk -F '\t' -v area="$area" 'NR > 1 { split($1, p, " "); if (p[1] == area) found=1 } END { exit !found }' "$PMCTL_COMMAND_REGISTRY"; then
    pmctl_command_catalog_unknown "$area"
    return 2
  fi
  printf '%s — pmctl command area\n\n' "$area"
  printf 'Usage:\n  pmctl %s <command> [options]\n\n' "$area"
  printf 'Stability: experimental\n\nCommands:\n'
  awk -F '\t' -v area="$area" 'NR > 1 {
    split($1, p, " ")
    if (p[1] != area) next
    if (p[2] == "") label="(direct)"; else label=p[2]
    printf "  %-18s %s\n", label, $2
  }' "$PMCTL_COMMAND_REGISTRY"
  direct="$(awk -F '\t' -v area="$area" 'NR > 1 && $1 == area { print; exit }' "$PMCTL_COMMAND_REGISTRY")"
  if [[ -n "$direct" ]]; then
    local _path _summary usage _stability _json _mutating options example
    IFS=$'\t' read -r _path _summary usage _stability _json _mutating options example <<< "$direct"
    printf '\nDirect usage:\n  %s\n\nMain options:\n  %s\n\nExample:\n  %s\n' "$usage" "$options" "$example"
  else
    printf '\nExample:\n  pmctl help %s %s\n' "$area" "$(awk -F '\t' -v area="$area" 'NR > 1 { split($1,p," "); if (p[1] == area && p[2] != "") { print p[2]; exit } }' "$PMCTL_COMMAND_REGISTRY")"
  fi
}

pmctl_command_catalog_leaf_help() {
  local path="$1" row
  [[ -z "${2:-}" ]] || path+=" $2"
  pmctl_command_catalog_require_registry || return
  row="$(awk -F '\t' -v path="$path" 'NR > 1 && $1 == path { print; exit }' "$PMCTL_COMMAND_REGISTRY")"
  if [[ -z "$row" ]]; then
    pmctl_command_catalog_unknown "$path"
    return 2
  fi
  local _path summary usage stability json mutating options example
  IFS=$'\t' read -r _path summary usage stability json mutating options example <<< "$row"
  printf '%s — %s\n\n' "$_path" "$summary"
  printf 'Usage: %s\n\n' "$usage"
  printf 'Stability: %s\nJSON output: %s\nMutating: %s\n\n' "$stability" "$json" "$mutating"
  printf 'Main options:\n  %s\n\n' "$options"
  printf 'Example:\n  %s\n' "$example"
}

pmctl_command_catalog_help() {
  case "$#" in
    0) pmctl_command_catalog_root_help ;;
    1)
      if awk -F '\t' -v area="$1" 'NR > 1 { split($1,p," "); if (p[1] == area && p[2] != "") found=1 } END { exit !found }' "$PMCTL_COMMAND_REGISTRY"; then
        pmctl_command_catalog_area_help "$1"
      elif awk -F '\t' -v path="$1" 'NR > 1 && $1 == path { found=1 } END { exit !found }' "$PMCTL_COMMAND_REGISTRY"; then
        pmctl_command_catalog_leaf_help "$1" ""
      else
        pmctl_command_catalog_area_help "$1"
      fi
      ;;
    2) pmctl_command_catalog_leaf_help "$1" "$2" ;;
    *) pmctl_command_catalog_die 'help accepts at most an area and command'; return 2 ;;
  esac
}

pmctl_command_catalog_commands_json() {
  pmctl_command_catalog_require_registry || return
  awk -F '\t' '
    function esc(value) {
      gsub(/\\/, "\\\\", value); gsub(/"/, "\\\"", value)
      gsub(/\r/, "\\r", value); gsub(/\n/, "\\n", value); gsub(/\t/, "\\t", value)
      return value
    }
    BEGIN { printf "{\"commands\":[" }
    NR > 1 {
      if (count++) printf ","
      split($1, p, " ")
      printf "{\"path\":\"%s\",\"area\":\"%s\",\"summary\":\"%s\",\"usage\":\"%s\",\"stability\":\"%s\",\"json\":%s,\"mutating\":%s}", esc($1), esc(p[1]), esc($2), esc($3), esc($4), $5, $6
    }
    END { printf "]}\n" }
  ' "$PMCTL_COMMAND_REGISTRY"
}

pmctl_command_catalog_unknown() {
  local input="$1" suggestion
  pmctl_command_catalog_require_registry || return
  suggestion="$(awk -F '\t' -v input="$input" '
    function min3(a,b,c) { m=a; if (b<m) m=b; if (c<m) m=c; return m }
    function distance(a,b, i,j,cost,d) {
      for (i=0;i<=length(a);i++) d[i,0]=i
      for (j=0;j<=length(b);j++) d[0,j]=j
      for (i=1;i<=length(a);i++) for (j=1;j<=length(b);j++) {
        cost=(substr(a,i,1)==substr(b,j,1) ? 0 : 1)
        d[i,j]=min3(d[i-1,j]+1,d[i,j-1]+1,d[i-1,j-1]+cost)
      }
      return d[length(a),length(b)]
    }
    NR > 1 {
      candidate=$1; score=distance(input,candidate)
      if (best == "" || score < best_score) { best=candidate; best_score=score }
    }
    END { print best }
  ' "$PMCTL_COMMAND_REGISTRY")"
  printf 'pmctl: unknown command: %s\n' "$input" >&2
  [[ -n "$suggestion" ]] && printf 'Did you mean "%s"?\n' "$suggestion" >&2
  printf 'Run "pmctl --help" for available commands.\n' >&2
}
