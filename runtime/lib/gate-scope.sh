#!/usr/bin/env bash
# Source-safe Gate scope construction and bounded expansion contract.

if ! declare -F gate_digest_stream >/dev/null 2>&1; then
  _gate_scope_dir="${BASH_SOURCE[0]%/*}"
  _gate_digest_module="$_gate_scope_dir/gate-digest.sh"
  if [[ ! -r "$_gate_digest_module" ]]; then
    printf 'gate-scope: digest module unavailable: %s\n' "$_gate_digest_module" >&2
    return 2
  fi
  # shellcheck source=runtime/lib/gate-digest.sh
  # shellcheck disable=SC1091  # dependency path is resolved beside this module
  . "$_gate_digest_module"
  unset _gate_scope_dir _gate_digest_module
fi

# Emit a deterministic, content-addressed representation of the exact diff
# covered by policy resolution. The outer scope fingerprint also binds the
# requested policy/pass/brief coordinates; this digest prevents an approved
# downgrade from being replayed against a shape-identical but content-different
# patch. Working-tree scopes additionally bind every non-ignored untracked
# file's path, kind, executable bit, and content (or symlink target).
_gate_policy_scope_content_digest() {
  local diff_kind="${1:-}" base="${2:-}" head_ref="${3:-HEAD}"
  local include_untracked="${4:-false}" path quoted kind executable digest
  {
    printf 'gate-policy-scope-content-v1\0'
    case "$diff_kind" in
      fixed-head)
        git diff --binary --full-index "$base"..."$head_ref" --
        ;;
      allow-dirty)
        git diff --binary --full-index "$base" --
        ;;
      committed)
        git diff --binary --full-index "$base"...HEAD --
        ;;
      working-tree)
        git diff --binary --full-index HEAD --
        ;;
      *)
        printf 'Error: unknown gate policy diff kind: %s\n' "$diff_kind" >&2
        return 2
        ;;
    esac || return 2

    if [[ "$include_untracked" == true ]]; then
      while IFS= read -r -d '' path; do
        quoted="$(printf '%q' "$path")"
        if [[ -L "$WORK_DIR/$path" ]]; then
          kind=symlink
          executable=false
          digest="$(printf '%s' "$(readlink "$WORK_DIR/$path")" \
            | gate_digest_stream)" || return 2
        elif [[ -f "$WORK_DIR/$path" ]]; then
          # shellcheck disable=SC2209  # This is a literal enum value.
          kind=file
          [[ -x "$WORK_DIR/$path" ]] && executable=true || executable=false
          digest="$(gate_digest_file "$WORK_DIR/$path")" || return 2
        else
          printf 'Error: unsupported untracked gate policy input: %s\n' \
            "$path" >&2
          return 2
        fi
        printf 'untracked\0path=%s\0kind=%s\0executable=%s\0sha256=%s\0' \
          "$quoted" "$kind" "$executable" "$digest"
      done < <(git ls-files --others --exclude-standard -z)
    fi
  } | gate_digest_stream
}

# Emit the exact status-bearing change set for the same comparison mode used by
# policy resolution. NUL-delimited Git output keeps paths with whitespace,
# tabs, or newlines intact until jq encodes them as JSON strings.
_gate_scope_changes_collect() {
  local records raw status path old_path new_path similarity
  records="$(mktemp "${TMPDIR:-/tmp}/gate-scope-changes.XXXXXX")" || return 2
  : > "$records"

  while IFS= read -r -d '' raw; do
    status="${raw:0:1}"
    similarity=null
    case "$status" in
      R|C)
        IFS= read -r -d '' old_path || {
          rm -f -- "$records"
          return 2
        }
        IFS= read -r -d '' new_path || {
          rm -f -- "$records"
          return 2
        }
        [[ "${raw:1}" =~ ^[0-9]+$ ]] && similarity="${raw:1}"
        jq -nc --arg status "$(if [[ "$status" == R ]]; then printf renamed; else printf copied; fi)" \
          --arg old "$old_path" --arg new "$new_path" \
          --argjson similarity "$similarity" \
          '{status:$status,old_path:$old,new_path:$new,similarity:$similarity}' \
          >> "$records" || {
            rm -f -- "$records"
            return 2
          }
        ;;
      *)
        IFS= read -r -d '' path || {
          rm -f -- "$records"
          return 2
        }
        case "$status" in
          A) status=added ;;
          M) status=modified ;;
          D) status=deleted ;;
          T) status=type_changed ;;
          U) status=unmerged ;;
          *) status=unknown ;;
        esac
        if [[ "$status" == deleted ]]; then
          jq -nc --arg status "$status" --arg old "$path" \
            '{status:$status,old_path:$old,new_path:null,similarity:null}' \
            >> "$records" || {
              rm -f -- "$records"
              return 2
            }
        else
          jq -nc --arg status "$status" --arg new "$path" \
            '{status:$status,old_path:null,new_path:$new,similarity:null}' \
            >> "$records" || {
              rm -f -- "$records"
              return 2
            }
        fi
        ;;
    esac
  done < <(
    # shellcheck disable=SC2153  # BASE and HEAD_REF are entrypoint coordinates.
    case "$POLICY_DIFF_KIND" in
      fixed-head)
        git diff --find-renames --name-status -z "$BASE"..."$HEAD_REF" --
        ;;
      allow-dirty)
        git diff --find-renames --name-status -z "$BASE" --
        ;;
      committed)
        git diff --find-renames --name-status -z "$BASE"...HEAD --
        ;;
      working-tree)
        git diff --find-renames --name-status -z HEAD --
        ;;
      *)
        return 2
        ;;
    esac
  )

  if [[ "$POLICY_SCOPE_INCLUDE_UNTRACKED" == true ]]; then
    while IFS= read -r -d '' path; do
      jq -nc --arg new "$path" \
        '{status:"untracked",old_path:null,new_path:$new,similarity:null}' \
        >> "$records" || {
          rm -f -- "$records"
          return 2
        }
    done < <(git ls-files --others --exclude-standard -z)
  fi

  jq -s 'sort_by((.new_path // .old_path),.status)' "$records"
  status=$?
  rm -f -- "$records"
  return "$status"
}

GATE_SCOPE_MAX_DIFF_HUNKS=512
GATE_SCOPE_MAX_EXPANSION_SOURCES=256
GATE_SCOPE_MAX_SYMBOLS_PER_SOURCE=1024
GATE_SCOPE_MAX_MATCHES_PER_QUERY=64
# Contract bundles are explicitly enumerated framework surfaces.  They retain
# a bounded path-reference summary, independently from the tighter symbol
# call-site search budget used for arbitrary application sources.
GATE_SCOPE_MAX_CONTRACT_CONSUMERS_PER_SOURCE=128
GATE_SCOPE_MAX_EXPANSION_ENTRIES=512

_gate_scope_diff_for_path() {
  local path="$1"
  case "$POLICY_DIFF_KIND" in
    fixed-head)
      git diff --unified=0 --no-color --no-ext-diff \
        "$BASE"..."$HEAD_REF" -- "$path"
      ;;
    allow-dirty)
      git diff --unified=0 --no-color --no-ext-diff "$BASE" -- "$path"
      ;;
    committed)
      git diff --unified=0 --no-color --no-ext-diff "$BASE"...HEAD -- "$path"
      ;;
    working-tree)
      git diff --unified=0 --no-color --no-ext-diff HEAD -- "$path"
      ;;
    *)
      return 2
      ;;
  esac
}

_gate_scope_numstat_for_path() {
  local path="$1"
  case "$POLICY_DIFF_KIND" in
    fixed-head) git diff --numstat "$BASE"..."$HEAD_REF" -- "$path" ;;
    allow-dirty) git diff --numstat "$BASE" -- "$path" ;;
    committed) git diff --numstat "$BASE"...HEAD -- "$path" ;;
    working-tree) git diff --numstat HEAD -- "$path" ;;
    *) return 2 ;;
  esac
}

_gate_scope_path_exists() {
  local path="$1"
  if [[ "$POLICY_DIFF_KIND" == fixed-head ]]; then
    git cat-file -e "${GATE_BINDING_HEAD_COMMIT}:$path" 2>/dev/null
  else
    [[ -f "$WORK_DIR/$path" && ! -L "$WORK_DIR/$path" ]]
  fi
}

_gate_scope_path_content() {
  local path="$1"
  if [[ "$POLICY_DIFF_KIND" == fixed-head ]]; then
    git show "${GATE_BINDING_HEAD_COMMIT}:$path" 2>/dev/null
  else
    cat -- "$WORK_DIR/$path"
  fi
}

_gate_scope_hunks_collect() {
  local changes_json="$1" output="$2" binary_output="$3"
  local max_hunks="$GATE_SCOPE_MAX_DIFF_HUNKS"
  local status path old_path line old_start old_lines
  local new_start new_lines header line_count path_hunks=0
  local total_hunks=0
  : > "$output"
  : > "$binary_output"

  while IFS= read -r -d '' status \
      && IFS= read -r -d '' path \
      && IFS= read -r -d '' old_path; do
    [[ -n "$path" ]] || path="$old_path"
    [[ -n "$path" ]] || continue
    path_hunks=0
    if [[ "$status" == untracked ]]; then
      if [[ -L "$WORK_DIR/$path" || ! -f "$WORK_DIR/$path" ]] \
          || ! grep -Iq . "$WORK_DIR/$path" 2>/dev/null; then
        jq -nc --arg path "$path" '$path' >> "$binary_output" || return 2
        continue
      fi
      line_count="$(awk 'END { print NR+0 }' "$WORK_DIR/$path")"
      header="@@ -0,0 +1,${line_count} @@ untracked"
      total_hunks=$((total_hunks + 1))
      if [[ "$total_hunks" -le "$max_hunks" ]]; then
        jq -nc --arg path "$path" --arg header "$header" \
          --argjson lines "$line_count" '{
            path:$path,source:"untracked",
            old_start:0,old_lines:0,new_start:1,new_lines:$lines,header:$header
          }' >> "$output" || return 2
      fi
      continue
    fi

    while IFS= read -r line; do
      if [[ "$line" =~ ^@@[[:space:]]-([0-9]+)(,([0-9]+))?[[:space:]]\+([0-9]+)(,([0-9]+))?[[:space:]]@@ ]]; then
        old_start="${BASH_REMATCH[1]}"
        old_lines="${BASH_REMATCH[3]:-1}"
        new_start="${BASH_REMATCH[4]}"
        new_lines="${BASH_REMATCH[6]:-1}"
        header="$line"
        path_hunks=$((path_hunks + 1))
        total_hunks=$((total_hunks + 1))
        if [[ "$total_hunks" -le "$max_hunks" ]]; then
          jq -nc --arg path "$path" --arg header "$header" \
            --argjson old_start "$old_start" --argjson old_lines "$old_lines" \
            --argjson new_start "$new_start" --argjson new_lines "$new_lines" '{
              path:$path,source:"tracked",
              old_start:$old_start,old_lines:$old_lines,
              new_start:$new_start,new_lines:$new_lines,header:$header
            }' >> "$output" || return 2
        fi
      fi
    done < <(_gate_scope_diff_for_path "$path")
    if [[ "$path_hunks" -eq 0 ]] \
        && _gate_scope_numstat_for_path "$path" | grep -q $'^-\t-'; then
      jq -nc --arg path "$path" '$path' >> "$binary_output" || return 2
    fi
  done < <(jq -j '.[] |
    .status, "\u0000", (.new_path // ""), "\u0000",
    (.old_path // ""), "\u0000"' <<<"$changes_json")

  GATE_SCOPE_OMITTED_DIFF_HUNKS=$((total_hunks > max_hunks ? total_hunks - max_hunks : 0))
}

_gate_scope_paired_tests_collect() {
  local changed_paths_json="$1" records source base stem dir candidate
  records="$(mktemp "${TMPDIR:-/tmp}/gate-scope-pairs.XXXXXX")" || return 2
  : > "$records"
  while IFS= read -r -d '' source; do
    _gate_scope_path_exists "$source" || continue
    base="$(basename "$source")"
    stem="${base%.*}"
    dir="$(dirname "$source")"
    case "$source" in
      *.go)
        [[ "$source" == *_test.go ]] || {
          candidate="${source%.go}_test.go"
          if _gate_scope_path_exists "$candidate"; then
            jq -nc --arg source "$source" --arg test "$candidate" \
              '{source_path:$source,test_path:$test,reason:"language-convention"}' \
              >> "$records" || return 2
          fi
        }
        ;;
      *.ts|*.tsx|*.js|*.jsx)
        case "$base" in *.test.*|*.spec.*) continue ;; esac
        for candidate in \
          "$dir/__tests__/$stem.test.ts" "$dir/__tests__/$stem.test.tsx" \
          "$dir/__tests__/$stem.spec.ts" "$dir/__tests__/$stem.spec.tsx" \
          "$dir/$stem.test.ts" "$dir/$stem.test.tsx" \
          "$dir/$stem.spec.ts" "$dir/$stem.spec.tsx" \
          "$dir/$stem.test.js" "$dir/$stem.spec.js"; do
          candidate="${candidate#./}"
          if _gate_scope_path_exists "$candidate"; then
            jq -nc --arg source "$source" --arg test "$candidate" \
              '{source_path:$source,test_path:$test,reason:"language-convention"}' \
              >> "$records" || return 2
          fi
        done
        ;;
      *.py)
        [[ "$base" == test_*.py ]] || {
          for candidate in "$dir/test_$base" "tests/test_$base"; do
            candidate="${candidate#./}"
            if _gate_scope_path_exists "$candidate"; then
              jq -nc --arg source "$source" --arg test "$candidate" \
                '{source_path:$source,test_path:$test,reason:"language-convention"}' \
                >> "$records" || return 2
            fi
          done
        }
        ;;
      *.sh)
        [[ "$base" == test-*.sh ]] || {
          for candidate in "$dir/test-$base" "tests/shell/test-$base"; do
            candidate="${candidate#./}"
            if _gate_scope_path_exists "$candidate"; then
              jq -nc --arg source "$source" --arg test "$candidate" \
                '{source_path:$source,test_path:$test,reason:"language-convention"}' \
                >> "$records" || return 2
            fi
          done
        }
        ;;
    esac
  done < <(jq -j '.[] | ., "\u0000"' <<<"$changed_paths_json")
  jq -s 'unique_by([.source_path,.test_path]) |
    sort_by(.source_path,.test_path)' "$records"
  local rc=$?
  rm -f -- "$records"
  return "$rc"
}

_gate_scope_symbols_collect() {
  local source="$1"
  case "$source" in
    *.sh|*.bash)
      _gate_scope_path_content "$source" 2>/dev/null |
        sed -nE \
          -e 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(\)[[:space:]]*(\{|$).*/\1/p'
      ;;
    *.go)
      _gate_scope_path_content "$source" 2>/dev/null |
        sed -nE \
          -e 's/^[[:space:]]*func[[:space:]]+\([^)]*\)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\1/p' \
          -e 's/^[[:space:]]*func[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\1/p'
      ;;
    *.js|*.jsx|*.ts|*.tsx)
      _gate_scope_path_content "$source" 2>/dev/null |
        sed -nE \
          -e 's/^[[:space:]]*(export[[:space:]]+)?(async[[:space:]]+)?function[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\3/p' \
          -e 's/^[[:space:]]*(export[[:space:]]+)?class[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p' \
          -e 's/^[[:space:]]*(export[[:space:]]+)?(const|let|var)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*/\3/p'
      ;;
    *.py)
      _gate_scope_path_content "$source" 2>/dev/null |
        sed -nE \
          -e 's/^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\2/p' \
          -e 's/^[[:space:]]*class[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p'
      ;;
    *.java)
      _gate_scope_path_content "$source" 2>/dev/null |
        sed -nE \
          -e 's/^[[:space:]]*(public|protected|private)?[[:space:]]*(abstract[[:space:]]+|final[[:space:]]+)?class[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/p'
      ;;
    *.kt)
      _gate_scope_path_content "$source" 2>/dev/null |
        sed -nE \
          -e 's/^[[:space:]]*(public|protected|private|internal)?[[:space:]]*(data[[:space:]]+|sealed[[:space:]]+)?class[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/p' \
          -e 's/^[[:space:]]*(public|protected|private|internal)?[[:space:]]*(suspend[[:space:]]+)?fun[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\3/p'
      ;;
    *.rs)
      _gate_scope_path_content "$source" 2>/dev/null |
        sed -nE \
          -e 's/^[[:space:]]*(pub([[:space:]]*\([^)]*\))?[[:space:]]+)?(async[[:space:]]+)?fn[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\4/p'
      ;;
  esac |
    awk 'length($0) >= 3 && !seen[$0]++' |
    LC_ALL=C sort
}

_gate_scope_symbol_path_compatible() {
  local source="$1" candidate="$2"
  case "$source" in
    *.sh|*.bash) [[ "$candidate" == *.sh || "$candidate" == *.bash ]] ;;
    *.go) [[ "$candidate" == *.go ]] ;;
    *.js|*.jsx|*.ts|*.tsx)
      [[ "$candidate" == *.js || "$candidate" == *.jsx \
        || "$candidate" == *.ts || "$candidate" == *.tsx ]]
      ;;
    *.py) [[ "$candidate" == *.py ]] ;;
    *.java|*.kt) [[ "$candidate" == *.java || "$candidate" == *.kt ]] ;;
    *.rs) [[ "$candidate" == *.rs ]] ;;
    *) return 1 ;;
  esac
}

_gate_scope_search_paths() {
  local query="$1" search_kind="$2" source="${3-}" result
  local -a options=(-l -z -F)
  [[ "$search_kind" == symbol ]] && options+=(-w)
  if [[ "$POLICY_DIFF_KIND" == fixed-head ]]; then
    while IFS= read -r -d '' result; do
      result="${result#*:}"
      if [[ "$search_kind" != symbol ]] \
          || _gate_scope_symbol_path_compatible "$source" "$result"; then
        printf '%s\0' "$result"
      fi
    done < <(git grep "${options[@]}" "$query" "$GATE_BINDING_HEAD_COMMIT" -- \
      2>/dev/null || true)
  else
    while IFS= read -r -d '' result; do
      if [[ "$search_kind" != symbol ]] \
          || _gate_scope_symbol_path_compatible "$source" "$result"; then
        printf '%s\0' "$result"
      fi
    done < <(git grep "${options[@]}" "$query" -- 2>/dev/null || true)
    if [[ "$POLICY_SCOPE_INCLUDE_UNTRACKED" == true ]]; then
      while IFS= read -r -d '' result; do
        [[ -f "$WORK_DIR/$result" && ! -L "$WORK_DIR/$result" ]] || continue
        if [[ "$search_kind" == symbol ]] \
            && ! _gate_scope_symbol_path_compatible "$source" "$result"; then
          continue
        fi
        if [[ "$search_kind" == symbol ]]; then
          grep -IqlwF -- "$query" "$WORK_DIR/$result" 2>/dev/null \
            && printf '%s\0' "$result"
        else
          grep -IqlF -- "$query" "$WORK_DIR/$result" 2>/dev/null \
            && printf '%s\0' "$result"
        fi
      done < <(git ls-files --others --exclude-standard -z)
    fi
  fi
}

_gate_scope_expansion_append() {
  local output="$1" path="$2" reason="$3" source="$4" evidence="$5"
  local limit_kind="$6" maximum="$7"
  [[ -n "$path" && "$path" != /* && "$path" != ../* && "$path" != */../* ]] || return 0
  case "$path" in
    .agent-trace|.agent-trace/*|.gate-briefs|.gate-briefs/*|.gate-results|.gate-results/*)
      return 0
      ;;
  esac
  # Six NUL-separated fields, decoded in one pass by the caller. A bounded run
  # appends 512 of these, and building each object with its own jq process cost
  # more than the search that found them. NUL is safe as the separator by
  # construction, not by escaping: a bash string cannot contain a NUL byte, so
  # no field value can forge a boundary.
  printf '%s\0%s\0%s\0%s\0%s\0%s\0' \
    "$path" "$reason" "$source" "$evidence" "$limit_kind" "$maximum" >> "$output"
}

_gate_scope_expansions_collect() {
  local changed_paths_json="$1" output="$2"
  local candidates sources source_count=0 source path base stem dir ext candidate
  local query match eligible_count symbol_count
  local source_is_shared=false source_is_shell=false source_is_contract_bundle=false
  local symbol_limit="$GATE_SCOPE_MAX_SYMBOLS_PER_SOURCE"
  local match_limit="$GATE_SCOPE_MAX_MATCHES_PER_QUERY"
  local contract_consumer_limit="$GATE_SCOPE_MAX_CONTRACT_CONSUMERS_PER_SOURCE"
  local source_limit="$GATE_SCOPE_MAX_EXPANSION_SOURCES"
  local expansion_limit="$GATE_SCOPE_MAX_EXPANSION_ENTRIES"
  local omitted_sources=0 omitted_symbols=0 omitted_matches=0
  local omitted_contract_consumers=0 omitted_entries=0
  local -a symbols=() shell_consumers=()
  local -A query_seen=()
  # Membership in the changed set is asked once per expansion candidate, and a
  # bounded run reaches 512 of them. Answering each with its own jq process cost
  # more than every other collector in this file combined. The set is small and
  # fixed for the whole call, so resolve it once here and answer from memory.
  local -A changed_seen=()
  candidates="$(mktemp "${TMPDIR:-/tmp}/gate-scope-expansions.XXXXXX")" || return 2
  sources="$(mktemp "${TMPDIR:-/tmp}/gate-scope-sources.XXXXXX")" || {
    rm -f -- "$candidates"
    return 2
  }
  : > "$candidates"
  : > "$sources"

  while IFS= read -r -d '' source; do
    # Record membership before the existence filter: a deleted path is still a
    # changed path, and the jq predicate this replaces tested the whole array.
    [[ -z "$source" ]] || changed_seen["$source"]=1
    _gate_scope_path_exists "$source" || continue
    case "$source" in
      *.sh|*.bash|*.go|*.py|*.js|*.jsx|*.ts|*.tsx|*.java|*.kt|*.rs)
        printf '%s\0' "$source" >> "$sources"
        ;;
    esac
  done < <(jq -j '.[] | ., "\u0000"' <<<"$changed_paths_json")

  while IFS= read -r -d '' source; do
    source_count=$((source_count + 1))
    if [[ "$source_count" -gt "$source_limit" ]]; then
      omitted_sources=$((omitted_sources + 1))
      continue
    fi
    base="$(basename "$source")"
    stem="${base%.*}"
    dir="$(dirname "$source")"
    source_is_shared=false
    source_is_shell=false
    source_is_contract_bundle=false
    shell_consumers=()
    case "$source" in
      */lib/*|lib/*|*/shared/*|shared/*) source_is_shared=true ;;
    esac
    case "$source" in
      *.sh|*.bash) source_is_shell=true ;;
    esac
    case "$source" in
      tests/lib/test-harness.sh|runtime/lib/gate-result-verify.sh|runtime/bin/pr-gate.sh)
        source_is_contract_bundle=true
        # runtime/bin/pr-gate.sh is a shell entry point, not a lib path, but
        # its direct consumers are still a useful bounded review surface.
        source_is_shared=true
        ;;
    esac

    for ext in sh bash go py js jsx ts tsx java kt rs md; do
      candidate="$dir/$stem.$ext"
      candidate="${candidate#./}"
      [[ "$candidate" != "$source" ]] || continue
      if _gate_scope_path_exists "$candidate" \
          && [[ -z "${changed_seen[$candidate]:-}" ]]; then
        _gate_scope_expansion_append "$candidates" "$candidate" \
          same-stem-peer "$source" peer-convention per-source 1 || return 2
      fi
    done

    if [[ "$source_is_shared" == true || "$source_is_shell" == true ]]; then
      eligible_count=0
      query_seen=()
      while IFS= read -r -d '' match; do
        [[ "$match" != "$source" ]] || continue
        [[ -z "${query_seen[$match]:-}" ]] || continue
        query_seen["$match"]=1
        [[ -z "${changed_seen[$match]:-}" ]] || continue
        if [[ "$source_is_shell" == true ]] \
            && _gate_scope_symbol_path_compatible "$source" "$match"; then
          shell_consumers+=("$match")
        fi
        if [[ "$source_is_shared" == true ]]; then
          eligible_count=$((eligible_count + 1))
          local path_limit="$match_limit"
          [[ "$source_is_contract_bundle" == true ]] \
            && path_limit="$contract_consumer_limit"
          if [[ "$eligible_count" -le "$path_limit" ]]; then
            _gate_scope_expansion_append "$candidates" "$match" \
              shared-helper-consumer "$source" path-reference per-source "$path_limit" \
              || return 2
          elif [[ "$source_is_contract_bundle" == true ]]; then
            omitted_contract_consumers=$((omitted_contract_consumers + 1))
          else
            omitted_matches=$((omitted_matches + 1))
          fi
        fi
      done < <(_gate_scope_search_paths "$source" path)
    fi

    # These framework/verification bundles have deliberately broad consumer
    # surfaces. Their path-level consumer lists are the authoritative review
    # hints; expanding generic helpers repeats the same files once per symbol
    # and can exhaust a per-query budget without adding scope information.
    # Preserve the bounded consumer summary above and skip symbol-level
    # call-site expansion for these contract bundles.
    [[ "$source_is_contract_bundle" == true ]] && continue

    mapfile -t symbols < <(_gate_scope_symbols_collect "$source")
    symbol_count="${#symbols[@]}"
    if [[ "$symbol_count" -gt "$symbol_limit" ]]; then
      omitted_symbols=$((omitted_symbols + symbol_count - symbol_limit))
      symbols=("${symbols[@]:0:symbol_limit}")
    fi
    for query in "${symbols[@]}"; do
      eligible_count=0
      query_seen=()
      if [[ "$source_is_shell" == true ]]; then
        for match in "${shell_consumers[@]}"; do
          _gate_scope_path_content "$match" 2>/dev/null |
            grep -IwF -- "$query" >/dev/null || continue
          eligible_count=$((eligible_count + 1))
          if [[ "$eligible_count" -le "$match_limit" ]]; then
            _gate_scope_expansion_append "$candidates" "$match" \
              call-site-hint "$source#$query" symbol-reference per-symbol "$match_limit" \
              || return 2
          else
            omitted_matches=$((omitted_matches + 1))
          fi
        done
      else
        while IFS= read -r -d '' match; do
          [[ "$match" != "$source" ]] || continue
          [[ -z "${query_seen[$match]:-}" ]] || continue
          query_seen["$match"]=1
          [[ -z "${changed_seen[$match]:-}" ]] || continue
          eligible_count=$((eligible_count + 1))
          if [[ "$eligible_count" -le "$match_limit" ]]; then
            _gate_scope_expansion_append "$candidates" "$match" \
              call-site-hint "$source#$query" symbol-reference per-symbol "$match_limit" \
              || return 2
          else
            omitted_matches=$((omitted_matches + 1))
          fi
        done < <(_gate_scope_search_paths "$query" symbol "$source")
      fi
    done
  done < "$sources"

  # Decode the NUL-separated records _gate_scope_expansion_append wrote, then
  # dedupe and order exactly as before. The record shape is fixed at six fields,
  # so the stream is regrouped positionally.
  local _decode_records
  # shellcheck disable=SC2016 # $i and $limit are jq variables, bound by jq itself.
  _decode_records='
    split("\u0000")
    | if (length > 0 and .[-1] == "") then .[:-1] else . end
    | [ range(0; (length / 6) | floor) as $i
        | .[$i * 6 : $i * 6 + 6]
        | {path: .[0], reason: .[1], source: .[2], evidence: .[3],
           limit: {kind: .[4], maximum: (.[5] | tonumber)}} ]
    | unique_by([.path,.reason,.source,.evidence])
    | sort_by(.path,.reason,.source,.evidence)'
  jq -Rs --argjson limit "$expansion_limit" \
    "$_decode_records | .[:\$limit]" "$candidates" > "$output" || {
      rm -f -- "$candidates" "$sources"
      return 2
    }
  local total_entries
  total_entries="$(jq -Rs "$_decode_records | length" "$candidates")" || {
      rm -f -- "$candidates" "$sources"
      return 2
    }
  [[ "$total_entries" -le "$expansion_limit" ]] \
    || omitted_entries=$((total_entries - expansion_limit))
  rm -f -- "$candidates" "$sources"

  GATE_SCOPE_OMITTED_EXPANSION_SOURCES="$omitted_sources"
  GATE_SCOPE_OMITTED_SYMBOLS="$omitted_symbols"
  GATE_SCOPE_OMITTED_SEARCH_MATCHES="$omitted_matches"
  GATE_SCOPE_OMITTED_CONTRACT_CONSUMERS="$omitted_contract_consumers"
  GATE_SCOPE_OMITTED_EXPANSION_ENTRIES="$omitted_entries"
}

_gate_scope_flags_resolve() {
  local changed_paths_json="$1"
  jq -nc --argjson paths "$changed_paths_json" '
    def flag($pattern):
      ($paths | map(select(test($pattern))) | unique | sort) as $matched |
      {matched:($matched|length > 0),paths:$matched};
    {
      public_interface:flag("^(cli|commands|skills|agents|core/schema)/|(^|/)(README|CONTRIBUTING)\\.md$|(^|/)(api|apis|contract|contracts)(/|$)"),
      schema:flag("(^|/)(schema|schemas)(/|$)|\\.schema\\.json$"),
      config:flag("(^|/)(config|configs|\\.github|\\.pm-dispatch)(/|$)|\\.(yaml|yml|toml|ini|conf)$|(^|/)\\.gitignore$"),
      install:flag("(^|/)(install|uninstall)([^/]*$|/)|(^|/)(setup|bootstrap)(/|[-_.])"),
      ci:flag("(^|/)(\\.github/workflows|ci)(/|$)|(^|/)(Dockerfile|Makefile)$"),
      release:flag("(^|/)(CHANGELOG|RELEASE[^/]*)\\.md$|(^|/)release(s)?(/|[-_.])"),
      migration:flag("(^|/)(migration|migrations|migrate)(/|[-_.])")
    }
  '
}

_gate_scope_reference_index_collect() {
  local changed_paths_json="$1" paired_tests_json="$2"
  local sensitive_signals_json="$3" flags_json="$4"
  local expansion_file="$5" output="$6"
  local paths_file content_file sorted_file path snapshot line_count digest
  local reference_fd
  paths_file="$(mktemp "${TMPDIR:-/tmp}/gate-scope-reference-paths.XXXXXX")" \
    || return 2
  content_file="$(mktemp "${TMPDIR:-/tmp}/gate-scope-reference-content.XXXXXX")" \
    || {
      rm -f -- "$paths_file"
      return 2
    }
  sorted_file="$(mktemp "${TMPDIR:-/tmp}/gate-scope-reference-index.XXXXXX")" \
    || {
      rm -f -- "$paths_file" "$content_file"
      return 2
    }
  : > "$output"
  if ! jq -jnr \
      --argjson changed "$changed_paths_json" \
      --argjson paired "$paired_tests_json" \
      --argjson signals "$sensitive_signals_json" \
      --argjson flags "$flags_json" \
      --slurpfile expansion "$expansion_file" '
      ([$changed[]] +
       [$paired[] | .source_path, .test_path] +
       [$signals[] | .matches[]] +
       [$flags[] | .paths[]] +
       [$expansion[0][] | .path] |
       unique | sort | .[]) + "\u0000"
    ' > "$paths_file"; then
    rm -f -- "$paths_file" "$content_file" "$sorted_file"
    return 2
  fi

  exec {reference_fd}< "$paths_file" || {
    rm -f -- "$paths_file" "$content_file" "$sorted_file"
    return 2
  }
  while IFS= read -r -d '' path <&"$reference_fd"; do
    snapshot=subject
    if [[ "$POLICY_DIFF_KIND" != fixed-head && -L "$WORK_DIR/$path" ]]; then
      readlink -n -- "$WORK_DIR/$path" > "$content_file" || {
        rm -f -- "$paths_file" "$content_file" "$sorted_file"
        return 2
      }
    elif _gate_scope_path_exists "$path"; then
      _gate_scope_path_content "$path" > "$content_file" || {
        rm -f -- "$paths_file" "$content_file" "$sorted_file"
        return 2
      }
    elif git -C "$WORK_DIR" cat-file -e \
        "${GATE_BINDING_BASE_COMMIT}:$path" 2>/dev/null; then
      snapshot=base
      git -C "$WORK_DIR" show \
        "${GATE_BINDING_BASE_COMMIT}:$path" > "$content_file" || {
        rm -f -- "$paths_file" "$content_file" "$sorted_file"
        return 2
      }
    else
      continue
    fi
    line_count="$(awk 'END { print NR+0 }' "$content_file")"
    digest="$(gate_digest_stream < "$content_file")" || {
      rm -f -- "$paths_file" "$content_file" "$sorted_file"
      return 2
    }
    jq -nc --arg path "$path" --arg snapshot "$snapshot" \
      --argjson line_count "$line_count" --arg sha256 "$digest" '{
        path:$path,
        snapshot:$snapshot,
        line_count:$line_count,
        sha256:$sha256
      }' >> "$output" || {
        rm -f -- "$paths_file" "$content_file" "$sorted_file"
        return 2
      }
  done
  exec {reference_fd}<&-

  jq -s 'unique_by(.path) | sort_by(.path)' "$output" > "$sorted_file" || {
    rm -f -- "$paths_file" "$content_file" "$sorted_file"
    return 2
  }
  mv -- "$sorted_file" "$output" || {
    rm -f -- "$paths_file" "$content_file" "$sorted_file"
    return 2
  }
  rm -f -- "$paths_file" "$content_file"
}

_gate_scope_manifest_write() {
  local destination="$1" changes_json="$2" policy_json="$3"
  local hunks_file binary_file expansion_file reference_file manifest_tmp
  local changed_paths_json renamed_paths_json untracked_paths_json
  local paired_tests_json sensitive_signals_json flags_json
  local truncation_occurred=false truncation_accepted=false
  local status=complete acceptance_source="" reasons_json content_digest
  hunks_file="$(mktemp "${TMPDIR:-/tmp}/gate-scope-hunks.XXXXXX")" || return 2
  binary_file="$(mktemp "${TMPDIR:-/tmp}/gate-scope-binary.XXXXXX")" || {
    rm -f -- "$hunks_file"
    return 2
  }
  expansion_file="$(mktemp "${TMPDIR:-/tmp}/gate-scope-expansion.XXXXXX")" || {
    rm -f -- "$hunks_file" "$binary_file"
    return 2
  }
  reference_file="$(mktemp "${TMPDIR:-/tmp}/gate-scope-references.XXXXXX")" || {
    rm -f -- "$hunks_file" "$binary_file" "$expansion_file"
    return 2
  }
  manifest_tmp="$(mktemp "${destination}.tmp.XXXXXX")" || {
    rm -f -- "$hunks_file" "$binary_file" "$expansion_file" "$reference_file"
    return 2
  }

  changed_paths_json="$(jq -c '[
    .[] | .old_path, .new_path | select(. != null)
  ] | unique | sort' <<<"$changes_json")" || return 2
  renamed_paths_json="$(jq -c '[.[] |
    select(.status == "renamed") |
    {from:.old_path,to:.new_path,similarity:(.similarity // 0)}
  ] | sort_by(.from,.to)' <<<"$changes_json")" || return 2
  untracked_paths_json="$(jq -c '[.[] |
    select(.status == "untracked") | .new_path
  ] | unique | sort' <<<"$changes_json")" || return 2

  _gate_scope_hunks_collect "$changes_json" "$hunks_file" "$binary_file" || {
    rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
      "$reference_file" "$manifest_tmp"
    return 2
  }
  paired_tests_json="$(_gate_scope_paired_tests_collect "$changed_paths_json")" || {
    rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
      "$reference_file" "$manifest_tmp"
    return 2
  }
  _gate_scope_expansions_collect "$changed_paths_json" "$expansion_file" || {
      rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
        "$reference_file" "$manifest_tmp"
      return 2
    }
  sensitive_signals_json="$(jq -c '[
    .matched_signals[] | select(.source == "path-regex")
  ] | sort_by(.id)' <<<"$policy_json")" || return 2
  flags_json="$(_gate_scope_flags_resolve "$changed_paths_json")" || return 2
  _gate_scope_reference_index_collect \
    "$changed_paths_json" "$paired_tests_json" "$sensitive_signals_json" \
    "$flags_json" "$expansion_file" "$reference_file" || {
      rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
        "$reference_file" "$manifest_tmp"
      return 2
    }

  if [[ "$GATE_SCOPE_OMITTED_DIFF_HUNKS" -gt 0 \
      || "$GATE_SCOPE_OMITTED_EXPANSION_SOURCES" -gt 0 \
      || "$GATE_SCOPE_OMITTED_SYMBOLS" -gt 0 \
      || "$GATE_SCOPE_OMITTED_SEARCH_MATCHES" -gt 0 \
      || "$GATE_SCOPE_OMITTED_CONTRACT_CONSUMERS" -gt 0 \
      || "$GATE_SCOPE_OMITTED_EXPANSION_ENTRIES" -gt 0 ]]; then
    truncation_occurred=true
    if [[ "$ACCEPT_SCOPE_TRUNCATION" == true ]]; then
      truncation_accepted=true
      status=accepted_truncation
      acceptance_source=--accept-scope-truncation
    else
      status=incomplete
    fi
  fi
  reasons_json="$(jq -nc \
    --argjson hunks "$GATE_SCOPE_OMITTED_DIFF_HUNKS" \
    --argjson sources "$GATE_SCOPE_OMITTED_EXPANSION_SOURCES" \
    --argjson symbols "$GATE_SCOPE_OMITTED_SYMBOLS" \
    --argjson matches "$GATE_SCOPE_OMITTED_SEARCH_MATCHES" \
    --argjson contract_consumers "$GATE_SCOPE_OMITTED_CONTRACT_CONSUMERS" \
    --argjson entries "$GATE_SCOPE_OMITTED_EXPANSION_ENTRIES" '[
      if $hunks > 0 then "diff-hunk-budget" else empty end,
      if $sources > 0 then "expansion-source-budget" else empty end,
      if $symbols > 0 then "symbol-budget" else empty end,
      if $matches > 0 then "search-match-budget" else empty end,
      if $contract_consumers > 0 then "contract-consumer-budget" else empty end,
      if $entries > 0 then "expansion-entry-budget" else empty end
    ]')"

  if ! jq -n \
      --arg status "$status" \
      --arg repository_key "$GATE_SUBJECT_REPOSITORY_KEY" \
      --arg base_commit "$GATE_BINDING_BASE_COMMIT" \
      --arg head_commit "$GATE_BINDING_HEAD_COMMIT" \
      --arg tree_fingerprint "$GATE_BINDING_SUBJECT_FINGERPRINT" \
      --arg subject_kind "$GATE_SUBJECT_KIND" \
      --arg diff_kind "$POLICY_DIFF_KIND" --arg base_ref "$BASE" \
      --arg head_ref "$HEAD_REF" \
      --arg acceptance_source "$acceptance_source" \
      --argjson include_untracked "$POLICY_SCOPE_INCLUDE_UNTRACKED" \
      --argjson changes "$changes_json" \
      --argjson changed_paths "$changed_paths_json" \
      --argjson renamed_paths "$renamed_paths_json" \
      --argjson untracked_paths "$untracked_paths_json" \
      --slurpfile hunks "$hunks_file" --slurpfile binary "$binary_file" \
      --argjson paired_tests "$paired_tests_json" \
      --argjson sensitive_signals "$sensitive_signals_json" \
      --argjson flags "$flags_json" --slurpfile expansion "$expansion_file" \
      --slurpfile references "$reference_file" \
      --argjson truncation_occurred "$truncation_occurred" \
      --argjson truncation_accepted "$truncation_accepted" \
      --argjson omitted_hunks "$GATE_SCOPE_OMITTED_DIFF_HUNKS" \
      --argjson omitted_sources "$GATE_SCOPE_OMITTED_EXPANSION_SOURCES" \
      --argjson omitted_symbols "$GATE_SCOPE_OMITTED_SYMBOLS" \
      --argjson omitted_matches "$GATE_SCOPE_OMITTED_SEARCH_MATCHES" \
      --argjson omitted_contract_consumers "$GATE_SCOPE_OMITTED_CONTRACT_CONSUMERS" \
      --argjson omitted_entries "$GATE_SCOPE_OMITTED_EXPANSION_ENTRIES" \
      --argjson budget_hunks "$GATE_SCOPE_MAX_DIFF_HUNKS" \
      --argjson budget_sources "$GATE_SCOPE_MAX_EXPANSION_SOURCES" \
      --argjson budget_symbols "$GATE_SCOPE_MAX_SYMBOLS_PER_SOURCE" \
      --argjson budget_matches "$GATE_SCOPE_MAX_MATCHES_PER_QUERY" \
      --argjson budget_contract_consumers "$GATE_SCOPE_MAX_CONTRACT_CONSUMERS_PER_SOURCE" \
      --argjson budget_entries "$GATE_SCOPE_MAX_EXPANSION_ENTRIES" \
      --argjson reasons "$reasons_json" '{
        kind:"gate_scope_manifest_v1",
        schema_version:1,
        status:$status,
        subject:{
          repository_key:$repository_key,
          base_commit:$base_commit,
          head_commit:$head_commit,
          tree_fingerprint:$tree_fingerprint,
          subject_kind:$subject_kind
        },
        selection:{
          diff_kind:$diff_kind,
          base_ref:$base_ref,
          head_ref:$head_ref,
          include_untracked:$include_untracked
        },
        changes:{
          entries:$changes,
          changed_paths:$changed_paths,
          renamed_paths:$renamed_paths,
          untracked_paths:$untracked_paths
        },
        diff:{
          hunks:$hunks,
          binary_or_special_paths:($binary | unique | sort)
        },
        paired_tests:$paired_tests,
        sensitive_signals:$sensitive_signals,
        flags:$flags,
        expansion:{
          claim:"bounded-hints-not-complete-call-graph",
          entries:$expansion[0],
          included_paths:([$expansion[0][].path] | unique | sort)
        },
        reference_index:{
          claim:"declared-review-reference-set",
          entries:$references[0]
        },
        truncation:{
          occurred:$truncation_occurred,
          budgets:{
            diff_hunks:$budget_hunks,
            expansion_source_paths:$budget_sources,
            symbols_per_source:$budget_symbols,
            matches_per_query:$budget_matches,
            contract_consumers_per_source:$budget_contract_consumers,
            expansion_entries:$budget_entries
          },
          omitted:{
            diff_hunks:$omitted_hunks,
            expansion_source_paths:$omitted_sources,
            symbols_per_source:$omitted_symbols,
            matches_per_query:$omitted_matches,
            contract_consumers_per_source:$omitted_contract_consumers,
            expansion_entries:$omitted_entries
          },
          reasons:$reasons,
          acceptance:{
            required:$truncation_occurred,
            accepted:$truncation_accepted,
            source:(if $acceptance_source == "" then null else $acceptance_source end)
          }
        },
        content:{
          digest_algorithm:"sha256-canonical-json-without-content-digest",
          digest:("")
        }
      }' > "$manifest_tmp"; then
    rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
      "$reference_file" "$manifest_tmp"
    return 2
  fi
  content_digest="$(jq -cS 'del(.content.digest)' "$manifest_tmp" |
    gate_digest_stream)" || {
      rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
        "$reference_file" "$manifest_tmp"
      return 2
    }
  jq --arg digest "$content_digest" '.content.digest=$digest' \
    "$manifest_tmp" > "${manifest_tmp}.final" || {
      rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
        "$reference_file" "$manifest_tmp" "${manifest_tmp}.final"
      return 2
    }
  mv -- "${manifest_tmp}.final" "$destination" || {
    rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
      "$reference_file" "$manifest_tmp" "${manifest_tmp}.final"
    return 2
  }
  rm -f -- "$hunks_file" "$binary_file" "$expansion_file" \
    "$reference_file" "$manifest_tmp"
}
