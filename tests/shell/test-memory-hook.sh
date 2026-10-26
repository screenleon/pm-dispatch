#!/usr/bin/env bash
# Regression tests for runtime/hooks/guard-inject-memory.sh, the UserPromptSubmit memory injection (CC-686,
# issue #738). The hook used to start several processes per memory card, so on native Windows it needed more
# than the host's 30 s limit once the index held about 130 cards. These cases pin what it prints (ranking,
# pins, lifecycle demotion, the episode reminder) and that its process count no longer grows with the cards.
# The expected text was produced by the hook as it was before the change.
# shellcheck disable=SC2154  # tmp_root is set by th_init
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# TEST_MEMORY_HOOK lets a run target another copy of the hook (the pre-change one, to see which cases bite).
HOOK="${TEST_MEMORY_HOOK:-$REPO_ROOT/runtime/hooks/guard-inject-memory.sh}"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# _run_hook <memory dir> <prompt> [extra PATH dir]: the hook's output with the machine-specific parts masked.
_run_hook() {
  local payload
  payload="$(jq -cn --arg c "$REPO_ROOT" --arg p "$2" '{cwd:$c,prompt:$p}')"
  PATH="${3:+$3:}$PATH" PM_MEMORY_DIR="$1" bash "$HOOK" --host claude <<<"$payload" 2>/dev/null \
    | sed -E 's#^Memory dir: [^|]*\|#Memory dir: <DIR> |#; s#project_key: [0-9a-f]+#project_key: <KEY>#'
}

# _plain_cards <dir> <n>: n ordinary cards and an index, nothing pinned.
_plain_cards() {
  local dir="$1" n="$2" i
  : > "$dir/MEMORY.md"
  for ((i = 1; i <= n; i++)); do
    printf -- '---\nname: c%s\nstatus: active\ntopics:\n  - topic%s\n---\nbody\n' "$i" "$i" > "$dir/p$i.md"
    printf -- '- [c%s](p%s.md) — plain card %s\n' "$i" "$i" "$i" >> "$dir/MEMORY.md"
  done
}

# _edge_cards <dir>: the awkward cards: a quoted pin, fields after the closing marker, no frontmatter, a line
# before the first marker, a quoted status, deeper topic items, a missing target, padded values, upper
# case and non-ASCII upper case text, duplicate keys, an index line without a link, parentheses in a name.
_edge_cards() {
  local e="$1"
  printf -- '---\nname: q\npriority: "always"\n---\nbody\n' > "$e/c01.md"
  printf -- '---\nname: late\n---\npriority: always\nstatus: stale\n' > "$e/c02.md"
  printf 'priority: always\nstatus: stale\nno frontmatter at all\n' > "$e/c03.md"
  printf 'preamble line\n---\nname: late-open\npriority: always\n---\nbody\n' > "$e/c04.md"
  printf -- '---\nstatus: "stale"\ntopics:\n  - alpha\n---\n' > "$e/c05.md"
  printf -- '---\ntopics:\n  - alpha one\n    - deeper ignored\n  - bravo two\nstatus: superseded\n  - after key not a topic\n---\n' > "$e/c06.md"
  printf -- '---\npriority:   always  \nstatus:superseded\n---\n' > "$e/c09.md"
  printf -- '---\ntopics:\n  - UPPER Alpha\n  - ÉCOLE\n  - 記憶 檢索\n---\n' > "$e/c10.md"
  printf -- '---\nstatus: stale\nstatus: active\npriority: normal\npriority: always\n---\n' > "$e/c11.md"
  cat > "$e/MEMORY.md" <<'EOF'
# Memory index (a heading, not an entry)
- [quoted always](c01.md) — quoted pin
- [after closing](c02.md) — fields after the closing marker must not count
- [no frontmatter](c03.md) — no markers at all
- [late open](c04.md) — a line before the first marker
- [stale quoted](c05.md) — alpha stale quoted
- [deeper](c06.md) — topics with deeper items and a key after
- [missing](c08.md) — the linked file does not exist
- [spaces](c09.md) — padded values
- [upper](c10.md) — UPPER Alpha and ÉCOLE in topics
- [first wins](c11.md) — duplicate keys
- plain line without a link alpha
- [name with (parens)](c01.md) — parens in the name alpha
- [no md target](notes.txt) — not a markdown link target
not an entry because it has no dash
EOF
  printf '{"date":"2026-10-20T10:00:00Z","summary":"s"}\n' > "$e/episodes.jsonl"
}

# The hook's output on _edge_cards for the prompt "alpha bravo", produced by the hook before CC-686.
_edge_expected() {
  cat <<'EOF'
=== auto-memory: MEMORY.md index ===
Provider: pmctl | authority: canonical | project_key: <KEY> | resolution: env
Memory dir: <DIR> | 13 cards total | native memory: auxiliary/unknown
Use /mem-search <topic> for full retrieval
- [quoted always](c01.md) — quoted pin
- [late open](c04.md) — a line before the first marker
- [name with (parens)](c01.md) — parens in the name alpha
- [upper](c10.md) — UPPER Alpha and ÉCOLE in topics
- plain line without a link alpha
- [after closing](c02.md) — fields after the closing marker must not count
- [no frontmatter](c03.md) — no markers at all
- [missing](c08.md) — the linked file does not exist
- [no md target](notes.txt) — not a markdown link target
- [deeper](c06.md) — topics with deeper items and a key after
(3 entries omitted — use /mem-search <topic> to retrieve them)
💡 Last episode: 2026-10-20 — run /mem-log if this session has new learnings.
=== end auto-memory ===
EOF
}

# Behavior: for a set of awkward cards the hook prints exactly what it printed before CC-686, on the first
# run and on the second (when usage history exists). Pinned cards (`priority: always`, also quoted, after a
# preamble line, with CRLF) come first and are not capped; fields after the closing `---`, in a file without
# frontmatter, or with padded values do not pin; keyword hits (ASCII case-folded, not non-ASCII) outrank
# non-hits; a stale or superseded card goes to the tail; a missing target, a link-less line and a non-markdown
# target are still listed; the budget omits the rest with a count.
# Steps: build the awkward cards, run the hook twice for "alpha bravo" and compare both outputs with the text
# the pre-change hook produced.
test_edge_cards_print_what_the_hook_always_printed() {
  local name="memory-hook/edge-cards-print-what-the-hook-always-printed"
  should_run "$name" || return 0
  local dir out1 out2 want
  dir="$(mktemp -d "$tmp_root/edge.XXXXXX")"
  _edge_cards "$dir"
  want="$(_edge_expected)"
  out1="$(_run_hook "$dir" "alpha bravo")"
  out2="$(_run_hook "$dir" "alpha bravo")"
  if [[ "$out1" == "$want" && "$out2" == "$want" ]]; then
    pass "$name"
  else
    fail "$name" "first run $([[ "$out1" == "$want" ]] && echo same || echo differs); second run $([[ "$out2" == "$want" ]] && echo same || echo differs): $(diff <(printf '%s\n' "$want") <(printf '%s\n' "$out1") | head -8)"
  fi
}

# Behavior: the number of awk and tr processes does not depend on the number of cards. The hook used to start
# three awk and one tr per card (about 0.23 s per card on native Windows, so past the host's 30 s limit at
# roughly 130 cards); it now reads every card from one awk. The count is what a regression would move, a
# timing would not be reliable.
# Steps: put counting awk and tr stubs first on PATH, run the hook on 8 and on 40 cards, and expect the
# starts for 40 to be within one of the starts for 8.
test_process_count_does_not_grow_with_the_cards() {
  local name="memory-hook/process-count-does-not-grow-with-the-cards"
  should_run "$name" || return 0
  local stubs log small big tool real starts_small_awk starts_big_awk starts_small_tr starts_big_tr
  stubs="$(mktemp -d "$tmp_root/stubs.XXXXXX")"
  log="$stubs/log"
  : > "$log"
  for tool in awk tr; do
    real="$(command -v "$tool")"
    printf '#!/bin/sh\necho "%s" >> "%s"\nexec "%s" "$@"\n' "$tool" "$log" "$real" > "$stubs/$tool"
    chmod +x "$stubs/$tool"
  done
  small="$(mktemp -d "$tmp_root/small.XXXXXX")"; _plain_cards "$small" 8
  big="$(mktemp -d "$tmp_root/big.XXXXXX")"; _plain_cards "$big" 40
  : > "$log"; _run_hook "$small" "topic3 plain" "$stubs" > /dev/null
  starts_small_awk="$(grep -c '^awk$' "$log" || true)"; starts_small_tr="$(grep -c '^tr$' "$log" || true)"
  : > "$log"; _run_hook "$big" "topic3 plain" "$stubs" > /dev/null
  starts_big_awk="$(grep -c '^awk$' "$log" || true)"; starts_big_tr="$(grep -c '^tr$' "$log" || true)"
  if (( starts_big_awk <= starts_small_awk + 1 && starts_big_tr <= starts_small_tr + 1 && starts_big_awk < 20 )); then
    pass "$name"
  else
    fail "$name" "awk starts: 8 cards=$starts_small_awk, 40 cards=$starts_big_awk; tr starts: 8 cards=$starts_small_tr, 40 cards=$starts_big_tr"
  fi
}

# Behavior: a keyword that appears only on a later line of a multi-line prompt still ranks a card. The hook
# reads the working directory and the prompt from the payload in one jq call, with a NUL between them, because
# a prompt holds newlines.
# Steps: 15 plain cards, so the last one is outside the budget; a prompt whose second line names that card's
# topic; the card must be printed.
test_keyword_on_a_later_prompt_line_ranks_the_card() {
  local name="memory-hook/keyword-on-a-later-prompt-line-ranks-the-card"
  should_run "$name" || return 0
  local dir_with dir_without with without
  # two directories: a hit is recorded as usage, and a card with usage history ranks higher on the next run
  dir_with="$(mktemp -d "$tmp_root/multi-with.XXXXXX")"; _plain_cards "$dir_with" 15
  dir_without="$(mktemp -d "$tmp_root/multi-without.XXXXXX")"; _plain_cards "$dir_without" 15
  with="$(_run_hook "$dir_with" "$(printf 'first line of the request\nthen the topic15 line')")"
  without="$(_run_hook "$dir_without" "$(printf 'first line of the request\nnothing relevant here')")"
  if [[ "$with" == *"[c15](p15.md)"* && "$without" != *"[c15](p15.md)"* ]]; then
    pass "$name"
  else
    fail "$name" "with the keyword: $(printf '%s' "$with" | grep -c 'c15') line(s) for c15; without: $(printf '%s' "$without" | grep -c 'c15')"
  fi
}

# Behavior: the episode reminder follows the last valid record of episodes.jsonl: "No episode logged" when
# its summary is blank (absent, spaces only, a newline only, false), "Last episode" when it has one (also a
# whitespace mix, a tab, a number), nothing when it is less than a day old, not an object, or has no usable
# date; lines that are not JSON or are blank are skipped. The log is read by one jq call.
# Steps: for each kind of last record, append it to a log under 10 plain cards and read the reminder line.
test_episode_reminder_branches() {
  local name="memory-hook/episode-reminder-branches"
  should_run "$name" || return 0
  local dir now line bad="" variant record want
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local -a table=(
    'blank|{"date":"2026-10-20T10:00:00Z","summary":"   "}|No episode logged since 2026-10-20'
    'absent|{"date":"2026-10-20T10:00:00Z"}|No episode logged since 2026-10-20'
    'newline|{"date":"2026-10-20T10:00:00Z","summary":"\n"}|No episode logged since 2026-10-20'
    'false|{"date":"2026-10-20T10:00:00Z","summary":false}|No episode logged since 2026-10-20'
    'text|{"date":"2026-10-20T10:00:00Z","summary":"x"}|Last episode: 2026-10-20'
    'spaces-newline|{"date":"2026-10-20T10:00:00Z","summary":" \n "}|Last episode: 2026-10-20'
    'tab|{"date":"2026-10-20T10:00:00Z","summary":"\t"}|Last episode: 2026-10-20'
    'number|{"date":"2026-10-20T10:00:00Z","summary":5}|Last episode: 2026-10-20'
    'zone|{"date":"2026-10-20T10:00:00+09:00","summary":"tz"}|Last episode: 2026-10-20'
    'fraction|{"date":"2026-10-20T10:00:00.123Z","summary":"f"}|Last episode: 2026-10-20'
    "recent|{\"date\":\"$now\",\"summary\":\"now\"}|"
    'not-an-object|5|'
    'bad-date|{"date":"not a date","summary":"x"}|'
    'number-date|{"date":5,"summary":"x"}|'
  )
  for entry in "${table[@]}"; do
    variant="${entry%%|*}"; record="${entry#*|}"; want="${record##*|}"; record="${record%|*}"
    dir="$(mktemp -d "$tmp_root/ep.XXXXXX")"
    _plain_cards "$dir" 10
    printf '%s\n' '{"date":"2026-10-19T09:00:00Z","summary":"older"}' 'not json at all' '' '   ' "$record" > "$dir/episodes.jsonl"
    line="$(_run_hook "$dir" "plain" | grep '💡' || true)"
    if [[ -z "$want" ]]; then
      [[ -z "$line" ]] || bad="$bad $variant:unexpected[$line]"
    else
      [[ "$line" == *"$want"* ]] || bad="$bad $variant:want[$want]got[$line]"
    fi
  done
  if [[ -z "$bad" ]]; then pass "$name"; else fail "$name" "$bad"; fi
}

test_edge_cards_print_what_the_hook_always_printed
test_process_count_does_not_grow_with_the_cards
test_keyword_on_a_later_prompt_line_ranks_the_card
test_episode_reminder_branches

th_summary
