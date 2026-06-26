#!/usr/bin/env bash
# Layer 1 structural audit for milestone release readiness.
# Functions are sourced by cli/pmctl and called via `pmctl pre-release audit`.

pmctl_pre_release_audit() {
  local repo_root milestone_id base_ref rc=0
  repo_root="${1:-}"
  milestone_id="${2:-}"
  shift 2 2>/dev/null || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      *)
        printf 'pmctl pre-release audit: unknown flag: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done

  if [[ -z "$repo_root" || -z "$milestone_id" ]]; then
    printf 'Usage: pmctl pre-release audit <repo-root> <milestone-id>\n' >&2
    return 2
  fi

  local milestones="$repo_root/MILESTONES.md"
  local backlog="$repo_root/BACKLOG.md"
  local backlog_archive="$repo_root/BACKLOG-ARCHIVE.md"
  local changelog="$repo_root/CHANGELOG.md"

  for f in "$milestones" "$backlog" "$changelog"; do
    if [[ ! -f "$f" ]]; then
      printf 'pmctl pre-release audit: file not found: %s\n' "$f" >&2
      return 2
    fi
  done

  base_ref="$(git -C "$repo_root" describe --tags --abbrev=0 2>/dev/null || true)"
  local git_range="${base_ref:+${base_ref}..}HEAD"

  # Extract scope tickets (tab-separated: ticket_id <TAB> status_column)
  local scope_rows
  scope_rows="$(_pra_extract_scope_rows "$milestones" "$milestone_id")"

  if [[ -z "$scope_rows" ]]; then
    printf 'pmctl pre-release audit: milestone "%s" not found or has no scope tickets in MILESTONES.md\n' \
      "$milestone_id" >&2
    return 2
  fi

  local tickets
  tickets="$(printf '%s\n' "$scope_rows" | cut -f1)"

  local today
  today="$(date -u +%Y-%m-%d)"

  # Print provenance block
  printf '## /pre-release — %s — %s\n\n' "$milestone_id" "$today"
  printf '**Source**:\n'
  printf '%s\n' "- milestone: \`MILESTONES.md#${milestone_id}\`"
  local backlog_src="- backlog: \`BACKLOG.md\`"
  [[ -f "$backlog_archive" ]] && backlog_src="${backlog_src} + \`BACKLOG-ARCHIVE.md\`"
  printf '%s\n' "$backlog_src"
  printf '%s\n' "- git-range: \`${git_range:-n/a}\`"
  printf '%s\n\n' "- generated_at: ${today}"
  printf '%s\n\n' '---'
  printf '### Layer 1 — Structural (machine checks)\n\n'

  # Check 1.1 — milestone scope: ✅ + PR refs
  local c11_out c11_issues=0
  c11_out="$(_pra_check_11_pr_refs "$scope_rows" "$milestone_id")"
  c11_issues=$(printf '%s\n' "$c11_out" | grep -c '^❌' || true)

  printf '#### 1.1 Milestone scope — ✅ and PR refs\n\n'
  printf '%s\n\n' "$c11_out"

  # Check 1.2 — closed ticket body residuals (only scan ✅ tickets)
  local c12_out c12_issues=0
  c12_out="$(_pra_check_12_body_residuals "$backlog" "$backlog_archive" "$scope_rows")"
  c12_issues=$(printf '%s\n' "$c12_out" | grep -c '^❌' || true)

  printf '#### 1.2 Closed ticket body — residual unresolved markers\n\n'
  printf '%s\n\n' "$c12_out"

  # Check 1.3 — CHANGELOG coverage
  local c13_out c13_issues=0
  c13_out="$(_pra_check_13_changelog "$changelog" "$scope_rows")"
  c13_issues=$(printf '%s\n' "$c13_out" | grep -c '^❌' || true)

  printf '#### 1.3 CHANGELOG [Unreleased] coverage\n\n'
  printf '%s\n\n' "$c13_out"

  # Check 1.4 — BACKLOG index vs body heading status
  local c14_out c14_issues=0
  c14_out="$(_pra_check_14_status_consistency "$backlog" "$backlog_archive" "$tickets")"
  c14_issues=$(printf '%s\n' "$c14_out" | grep -c '^❌' || true)

  printf '#### 1.4 BACKLOG index ↔ body heading status\n\n'
  printf '%s\n\n' "$c14_out"

  printf '%s\n\n' '---'

  # Layer 3 blind spots
  printf '### Layer 3 — Blind spots\n\n'
  printf 'This scan **can** confirm:\n'
  printf '%s\n' "- Structural markers in MILESTONES.md, BACKLOG.md, and CHANGELOG.md"
  printf '%s\n' "- Presence of ✅ and PR refs for each scope ticket in MILESTONES.md"
  printf '%s\n' "- Absence of unresolved-work markers in ticket bodies"
  printf '%s\n\n' "- BACKLOG index/body status consistency"
  printf 'This scan **cannot** confirm:\n'
  printf '%s\n' "- Whether a PR diff actually satisfies the ticket requirement (Layer 2 — not yet implemented)"
  printf '%s\n' "- Whether features work correctly at runtime"
  printf '%s\n\n' "- Whether gaps exist in \"should have been changed but was not mentioned in any ticket\" (system topology knowledge)"
  printf '> **"No structural issues found" ≠ "release is safe."** Layer 1 verifies tracking hygiene, not implementation correctness. The release decision remains with the user.\n\n'
  printf '%s\n\n' '---'

  local total_issues=$(( c11_issues + c12_issues + c13_issues + c14_issues ))
  printf '**Summary**: %d structural issue(s), 0 semantic flags (Layer 2 not run), 3 blind spots declared.\n' \
    "$total_issues"

  [[ "$total_issues" -gt 0 ]] && rc=1
  return "$rc"
}

# Extract scope rows from MILESTONES.md as TSV: ticket_id <TAB> status_column
_pra_extract_scope_rows() {
  local milestones="$1" milestone_id="$2"
  awk -v mid="$milestone_id" '
    /^## / {
      if (in_section) exit
      rest = substr($0, 4)
      if (substr(rest, 1, length(mid)) == mid) in_section = 1
      next
    }
    in_section && /^\| CC-[0-9]+ \|/ {
      n = split($0, cols, "|")
      # cols[1]="" cols[2]=ticket cols[3..n-1]=middle cols[n]="" cols[n-1]=status
      tid = cols[2]
      status = cols[n-1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", tid)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      if (tid ~ /^CC-[0-9]+$/) printf "%s\t%s\n", tid, status
    }
  ' "$milestones"
}

# Check 1.1: each scope ticket has ✅ and a valid PR ref in MILESTONES scope table
_pra_check_11_pr_refs() {
  local scope_rows="$1"
  local output=""

  while IFS=$'\t' read -r ticket status; do
    local line=""
    # Classify status
    if printf '%s' "$status" | grep -qF '✅'; then
      # Has done marker — check PR ref quality
      if printf '%s' "$status" | grep -qE 'pr:#[0-9]+'; then
        line="✅ $ticket — closed with canonical PR ref"
      elif printf '%s' "$status" | grep -qiE 'pr:#[Tt][Bb][Dd]'; then
        line="❌ $ticket — ✅ but PR ref is TBD (MILESTONES.md)"
  
      elif printf '%s' "$status" | grep -qE '#[0-9]+'; then
        line="⚠️  $ticket — ✅ with PR# but non-canonical format (expected \`pr:#NNN\`)"
      else
        line="❌ $ticket — ✅ but no PR ref found (MILESTONES.md)"
  
      fi
    else
      line="❌ $ticket — not marked ✅ in MILESTONES.md scope (status: $status)"

    fi
    output="${output}${line}"$'\n'
  done <<< "$scope_rows"

  printf '%s' "$output"
}

# Check 1.2: only scan CLOSED (✅) ticket bodies for unresolved markers (skip code fences)
# Accepts scope_rows TSV (ticket_id TAB status) so it can skip non-closed tickets.
_pra_check_12_body_residuals() {
  local backlog="$1" backlog_archive="${2:-}" scope_rows="$3"
  local output=""

  while IFS=$'\t' read -r ticket status; do
    [[ -z "$ticket" ]] && continue

    # Only scan bodies of closed tickets (✅ in scope status)
    if ! printf '%s' "$status" | grep -qF '✅'; then
      output="${output}⏭  $ticket — skipped (not closed: $status)"$'\n'
      continue
    fi

    # Find body in BACKLOG.md first, then BACKLOG-ARCHIVE.md
    local body_source=""
    for src in "$backlog" "$backlog_archive"; do
      [[ -z "$src" || ! -f "$src" ]] && continue
      if grep -qE "^## ${ticket}[[:space:]]" "$src" 2>/dev/null; then
        body_source="$src"
        break
      fi
    done

    if [[ -z "$body_source" ]]; then
      output="${output}⚠️  $ticket — body section not found in BACKLOG.md or BACKLOG-ARCHIVE.md"$'\n'
      continue
    fi

    # Extract body section (from ## CC-NNN line to next ## or EOF), skip code fences
    local hits
    hits="$(awk -v tid="$ticket" '
      /^## / && found { exit }
      /^## / && $0 ~ ("^## " tid "[[:space:]]") { found = 1; next }
      found && /^```/ { fence = !fence; next }
      found && !fence {
        if (/仍待辦|待辦|TODO|pr:#TBD/ || /\bTBD\b/) {
          line = $0
          gsub(/「[^」]*」/, "", line)
          if (line ~ /仍待辦|待辦|TODO|pr:#TBD/ || line ~ /\bTBD\b/) {
            printf NR ": " $0 "\n"
          }
        }
      }
    ' "$body_source")"

    if [[ -n "$hits" ]]; then
      output="${output}❌ $ticket — unresolved markers in body ($body_source):"$'\n'
      while IFS= read -r h; do
        output="${output}   $h"$'\n'
      done <<< "$hits"

    else
      output="${output}✅ $ticket — no unresolved markers"$'\n'
    fi
  done <<< "$scope_rows"

  printf '%s' "$output"
}

# Check 1.3: CHANGELOG [Unreleased] section mentions each scope ticket by CC-NNN or PR#
_pra_check_13_changelog() {
  local changelog="$1" scope_rows="$2"
  local output=""

  # Extract [Unreleased] section
  local unreleased
  unreleased="$(awk '
    /^## \[Unreleased\]/ { in_section = 1; next }
    in_section && /^## \[/ { exit }
    in_section { print }
  ' "$changelog")"

  if [[ -z "$unreleased" ]]; then
    while IFS=$'\t' read -r ticket _status; do
      [[ -z "$ticket" ]] && continue
      output="${output}❌ $ticket — CHANGELOG has no [Unreleased] section; coverage unverifiable"$'\n'
    done <<< "$scope_rows"
    printf '%s' "$output"
    return
  fi

  while IFS=$'\t' read -r ticket status; do
    [[ -z "$ticket" ]] && continue

    # Extract canonical PR# from status column (pr:#NNN)
    local pr_num=""
    if printf '%s' "$status" | grep -qE 'pr:#[0-9]+'; then
      pr_num="$(printf '%s' "$status" | grep -oE 'pr:#[0-9]+' | head -1 | sed 's/pr:#//')"
    fi

    # Check CC-NNN mention
    local found_cc found_pr
    found_cc="$(printf '%s\n' "$unreleased" | grep -c "$ticket" || true)"
    found_pr=0
    [[ -n "$pr_num" ]] && found_pr="$(printf '%s\n' "$unreleased" | grep -cE "#${pr_num}[^0-9]|#${pr_num}$" || true)"

    if [[ "$found_cc" -gt 0 || "$found_pr" -gt 0 ]]; then
      output="${output}✅ $ticket — mentioned in CHANGELOG [Unreleased]"$'\n'
    elif [[ -z "$pr_num" ]]; then
      output="${output}⚠️  $ticket — no canonical PR ref; searched CC-NNN only (not found)"$'\n'
    else
      output="${output}❌ $ticket — not mentioned in CHANGELOG [Unreleased] (searched $ticket, #${pr_num})"$'\n'

    fi
  done <<< "$scope_rows"

  printf '%s' "$output"
}

# Check 1.4: BACKLOG index row status emoji matches body heading status emoji
_pra_check_14_status_consistency() {
  local backlog="$1" backlog_archive="${2:-}" tickets="$3"
  local output=""

  while IFS= read -r ticket; do
    [[ -z "$ticket" ]] && continue

    # Get index row status (second column) — search both BACKLOG.md and BACKLOG-ARCHIVE.md
    local idx_status=""
    for src in "$backlog" "$backlog_archive"; do
      [[ -z "$src" || ! -f "$src" ]] && continue
      local row
      row="$(grep -E "^\| ${ticket} \|" "$src" 2>/dev/null | head -1 || true)"
      if [[ -n "$row" ]]; then
        idx_status="$(printf '%s' "$row" | awk -F'|' '{s=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); print s}')"
        break
      fi
    done

    if [[ -z "$idx_status" ]]; then
      # Index rows are removed when tickets are archived — check body heading only
      local archive_heading=""
      if [[ -f "$backlog_archive" ]]; then
        archive_heading="$(grep -E "^## ${ticket}[[:space:]]" "$backlog_archive" 2>/dev/null | head -1 || true)"
      fi
      if [[ -n "$archive_heading" ]]; then
        local arch_status
        arch_status="$(printf '%s' "$archive_heading" | sed 's/^## CC-[0-9]* — //' | \
          grep -oE '(✅|🔵|🟢|🟡|⏸|🚫|⚠️)[^🔵🟢🟡✅⏸🚫⚠️]*$' | \
          sed 's/[[:space:]]*$//' || true)"
        output="${output}✅ $ticket — archived (no index row); body heading: ${arch_status:-unknown}"$'\n'
      else
        output="${output}⚠️  $ticket — not found in BACKLOG.md or BACKLOG-ARCHIVE.md index"$'\n'
      fi
      continue
    fi

    # Get body heading status — last word-group of the heading line
    local heading_status=""
    for src in "$backlog" "$backlog_archive"; do
      [[ -z "$src" || ! -f "$src" ]] && continue
      local heading
      heading="$(grep -E "^## ${ticket}[[:space:]]" "$src" 2>/dev/null | head -1 || true)"
      if [[ -n "$heading" ]]; then
        # Extract trailing status: last space-separated token(s) after the title
        # e.g. "## CC-428 — title ✅ 2026-06-26" → "✅ 2026-06-26"
        # e.g. "## CC-426 — title 🟢 someday"   → "🟢 someday"
        heading_status="$(printf '%s' "$heading" | sed 's/^## CC-[0-9]* — //' | \
          grep -oE '(✅|🔵|🟢|🟡|⏸|🚫|⚠️)[^🔵🟢🟡✅⏸🚫⚠️]*$' | \
          sed 's/[[:space:]]*$//' || true)"
        break
      fi
    done

    if [[ -z "$heading_status" ]]; then
      output="${output}⚠️  $ticket — body heading not found or status not parseable"$'\n'
      continue
    fi

    # Normalize both to leading emoji for comparison
    local idx_emoji heading_emoji
    idx_emoji="$(printf '%s' "$idx_status" | grep -oE '^(✅|🔵|🟢|🟡|⏸|🚫|⚠️)' || true)"
    heading_emoji="$(printf '%s' "$heading_status" | grep -oE '^(✅|🔵|🟢|🟡|⏸|🚫|⚠️)' || true)"

    if [[ "$idx_emoji" == "$heading_emoji" ]]; then
      output="${output}✅ $ticket — index ($idx_status) ↔ body ($heading_status) consistent"$'\n'
    else
      output="${output}❌ $ticket — status mismatch: index ($idx_status) ↔ body ($heading_status)"$'\n'

    fi
  done <<< "$tickets"

  printf '%s' "$output"
}
