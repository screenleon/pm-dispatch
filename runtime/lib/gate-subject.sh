#!/usr/bin/env bash
# Source-safe Gate subject coordinate helpers.

# Read the trusted architecture impact from a validated dispatch brief. The
# brief path itself remains owned by the entrypoint's workspace-boundary checks;
# this module owns only the subject field and its closed enum.
gate_subject_architecture_impact() {
  local brief="${1:-}" values value count
  [[ -n "$brief" && -r "$brief" ]] || return 2
  values="$(awk '
    /^[[:space:]]*architecture_impact[[:space:]]*:/ {
      sub(/^[^:]*:[[:space:]]*/, "")
      gsub(/[[:space:]]+$/, "")
      print
    }
  ' "$brief")" || return 2
  count="$(printf '%s\n' "$values" | grep -c '[^[:space:]]' || true)"
  if (( count > 1 )); then
    printf 'Error: --brief has duplicate architecture_impact declarations\n' >&2
    return 2
  fi
  value="$(printf '%s\n' "$values" | sed -n '1p')"
  : "${value:=unknown}"
  case "$value" in
    none|minor|major|unknown) printf '%s\n' "$value" ;;
    *)
      printf 'Error: --brief has invalid architecture_impact: %s\n' \
        "$value" >&2
      return 2
      ;;
  esac
}
