#!/usr/bin/env bash
# Generic reader for hosts/<name>/host.yaml (schema v1, docs/host-contract.md).
#
# Consumed by install.sh/uninstall.sh/doctor.sh so none of them special-case a
# host name — every host-specific fact (target path, format, managed flag)
# comes from the manifest. Adding a host means adding hosts/<name>/host.yaml,
# not editing a caller of this file. Deliberately grep/awk-based (no YAML
# parser dependency), mirroring the block-extraction approach
# scripts/test-host-manifest.sh and doctor-host-claude.sh already use for the
# same file shape.
#
# Functions:
#   host_manifest_names                      -> one host name per line (dirs under hosts/ with a host.yaml)
#   host_manifest_file <name>                 -> prints hosts/<name>/host.yaml path (may not exist)
#   host_manifest_scalar <file> <key>         -> top-level scalar field value (e.g. host_binary, doctor_module)
#   host_manifest_install_targets <file>      -> TSV rows: id\tpath\tformat\tmanaged (one per install_targets entry)
#   host_manifest_expand_path <path_template> -> expands $CODEX_HOME/$CLAUDE_CONFIG_DIR/$XDG_CONFIG_HOME
#                                                 against env (with the same defaults doctor/install already use)

host_manifest_names() {
  local repo_root="$1" dir name
  for dir in "$repo_root"/hosts/*/; do
    [[ -f "${dir}host.yaml" ]] || continue
    name="$(basename "$dir")"
    printf '%s\n' "$name"
  done
}

host_manifest_file() {
  local repo_root="$1" name="$2"
  printf '%s/hosts/%s/host.yaml\n' "$repo_root" "$name"
}

# Top-level scalar field only (not list/map fields) — same restriction
# doctor-host-claude.sh's manifest_field helper has for guard_bindings entries.
host_manifest_scalar() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 1
  awk -v key="$key" '
    $0 ~ "^" key ":[[:space:]]*" {
      v = $0
      sub("^" key ":[[:space:]]*", "", v)
      sub("[[:space:]]*#.*$", "", v)
      gsub(/^"|"$/, "", v)
      print v
      exit
    }
  ' "$file"
}

host_manifest_install_targets() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  awk '
    /^install_targets:/ { insec=1; next }
    insec && /^[a-zA-Z_]+:/ && $0 !~ /^[[:space:]]/ { insec=0 }
    insec && /^[[:space:]]*-[[:space:]]*id:/ {
      if (id != "") printf "%s\t%s\t%s\t%s\n", id, path, fmt, managed
      id=$0; sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", id); sub(/[[:space:]]*#.*$/, "", id)
      path=""; fmt=""; managed=""
      next
    }
    insec && /^[[:space:]]+path:/ {
      v=$0; sub(/^[[:space:]]+path:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v); gsub(/^"|"$/, "", v); path=v; next
    }
    insec && /^[[:space:]]+format:/ {
      v=$0; sub(/^[[:space:]]+format:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v); fmt=v; next
    }
    insec && /^[[:space:]]+managed:/ {
      v=$0; sub(/^[[:space:]]+managed:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v); managed=v; next
    }
    END { if (id != "") printf "%s\t%s\t%s\t%s\n", id, path, fmt, managed }
  ' "$file"
}

# Bounded substitution: only the host-home env vars the schema actually uses
# (docs/host-contract.md "No maintainer-local layout assumptions"). Not a
# generic template engine on purpose — an unrecognized $VAR in a manifest
# path is left as a literal, not silently eval'd (manifest data must never
# reach a shell eval).
host_manifest_expand_path() {
  local path="$1"
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local claude_config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  path="${path//\$CODEX_HOME/$codex_home}"
  path="${path//\$CLAUDE_CONFIG_DIR/$claude_config_dir}"
  path="${path//\$XDG_CONFIG_HOME/$xdg_config_home}"
  printf '%s\n' "$path"
}
