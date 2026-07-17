#!/usr/bin/env bash
# Reject maintainer-local repository layout assumptions from operational files.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
home_token='$HOME'
patterns=("~""/github" "${home_token}""/github")
scan_roots=(README.md agents commands skills scripts runtime pm docs)
status=0

for scan_root in "${scan_roots[@]}"; do
  [[ -e "$repo_root/$scan_root" ]] || continue
  while IFS= read -r -d '' file; do
    case "$file" in
      "$repo_root/docs/spikes/"*|"$repo_root/pm/scripts/test/"*) continue ;;
    esac
    for pattern in "${patterns[@]}"; do
      if grep -Fn -- "$pattern" "$file" >/dev/null; then
        grep -HFn -- "$pattern" "$file" >&2 || true
        status=1
      fi
    done
  done < <(find "$repo_root/$scan_root" -type f -print0 2>/dev/null)
done

if [[ "$status" -ne 0 ]]; then
  printf 'lint-portable-repo-paths: maintainer-local repository layout literal found\n' >&2
  printf 'Use PM_DISPATCH_REPOS_ROOT, PM_DISPATCH_REPO, or a neutral placeholder.\n' >&2
  exit 1
fi

printf 'lint-portable-repo-paths: OK\n'
