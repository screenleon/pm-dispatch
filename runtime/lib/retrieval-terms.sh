#!/usr/bin/env bash
# Shared retrieval term extraction for memory injection and context scans.
#
# This file is a library: sourcing it must not change the caller's shell
# policy, spawn a process, or write to disk. Callers already have tr, od,
# awk, and sort — the same tools used elsewhere in runtime/.

# Space-delimited English stop list used by the ASCII token filter.
RETRIEVAL_TERM_STOPWORDS="a an and are as at be been by do for from has have he in is it its of on or that the to was were will with"

# UserPromptSubmit runs this synchronously. Bound the CJK byte-walk so a
# huge paste cannot stall the hook. ASCII-only input stays on the cheap
# tr/awk path and still respects the same cap for ranking keywords.
# Crossing the cap still extracts from the prefix only; emit one stderr
# line so CLI callers (reuse-scan / prompt-scan) can tell a silent miss
# from a genuine empty index.
RETRIEVAL_TERM_MAX_BYTES=16384

# retrieval_extract_terms <text> [ascii_min] [use_stopwords]
#   Print unique lowercase terms, one per line, sorted.
#   ASCII default (context / reuse-scan): [a-z0-9_]+ of length >= 3, minus
#   the shared English stop list.
#   Optional ascii_min (positive integer, default 3) and use_stopwords
#   (1/0, default 1) let the memory hook keep its pre-CC-465 English
#   policy (min 4, no stop list) while sharing CJK extraction.
#   CJK: overlapping 2-grams from each contiguous CJK/Hiragana/Katakana/Hangul
#   run of length >= 2. Single-character runs are dropped (too noisy).
#   FTS5 tokenization is intentionally not handled here.
if ! declare -F retrieval_extract_terms >/dev/null 2>&1; then
retrieval_extract_terms() {
  local text="${1-}"
  local ascii_min="${2:-3}"
  local use_stopwords="${3:-1}"
  local stopwords=" ${RETRIEVAL_TERM_STOPWORDS} "
  local nbytes saved_lc
  [[ "$ascii_min" =~ ^[1-9][0-9]*$ ]] || ascii_min=3
  [[ "$use_stopwords" == 0 || "$use_stopwords" == 1 ]] || use_stopwords=1
  if [[ "$use_stopwords" -eq 0 ]]; then
    stopwords=" "
  fi
  # Byte semantics for the size check, the truncation and the ASCII test. Bash does all three itself:
  # a process start costs 0.3 to 2.5 s on the host that reported issue #741, and this runs per prompt.
  saved_lc="${LC_ALL-}"
  LC_ALL=C
  nbytes=${#text}
  if [[ "$nbytes" -gt "$RETRIEVAL_TERM_MAX_BYTES" ]]; then
    printf 'retrieval-terms: input truncated from %s bytes to %s bytes\n' \
      "$nbytes" "$RETRIEVAL_TERM_MAX_BYTES" >&2
    text="${text:0:$RETRIEVAL_TERM_MAX_BYTES}"
  fi
  # ASCII-only: lower-case, split and de-duplicate in bash, no process. Still under LC_ALL=C, so the
  # comparison below orders bytes the way `LC_ALL=C sort` does.
  if [[ "$text" != *[$'\200'-$'\377']* ]]; then
    local -A seen=()
    local -a toks=() sorted=()
    local tok i
    text="${text,,}"
    text="${text//[^a-z0-9_]/ }"
    IFS=' ' read -r -a toks <<<"$text" || true
    for tok in "${toks[@]+"${toks[@]}"}"; do
      [[ "${#tok}" -ge "$ascii_min" && "$stopwords" != *" $tok "* ]] && seen[$tok]=1
    done
    if [[ "${#seen[@]}" -gt 64 ]]; then
      printf '%s\n' "${!seen[@]}" | LC_ALL=C sort
    elif [[ "${#seen[@]}" -gt 0 ]]; then
      for tok in "${!seen[@]}"; do
        i=${#sorted[@]}
        while [[ "$i" -gt 0 && "${sorted[i-1]}" > "$tok" ]]; do
          sorted[i]="${sorted[i-1]}"
          i=$((i - 1))
        done
        sorted[i]="$tok"
      done
      printf '%s\n' "${sorted[@]}"
    fi
    if [[ -n "$saved_lc" ]]; then LC_ALL="$saved_lc"; else unset LC_ALL; fi
    return 0
  fi
  if [[ -n "$saved_lc" ]]; then LC_ALL="$saved_lc"; else unset LC_ALL; fi
  # Byte-walk UTF-8 under LC_ALL=C so mawk/gawk agree on substr. od is the
  # same hex helper already used by state-writer / pmctl-task.
  printf '%s' "$text" \
    | tr '[:upper:]' '[:lower:]' \
    | od -An -tx1 -v \
    | LC_ALL=C awk -v sw="$stopwords" -v min="$ascii_min" '
      function hexval(h,    n, i, c, v) {
        n = 0
        for (i = 1; i <= length(h); i++) {
          c = substr(h, i, 1)
          if (c >= "0" && c <= "9") v = c + 0
          else if (c >= "a" && c <= "f") v = 10 + index("abcdef", c) - 1
          else if (c >= "A" && c <= "F") v = 10 + index("ABCDEF", c) - 1
          else continue
          n = n * 16 + v
        }
        return n
      }
      function is_cjk(cp) {
        return (cp >= 13312 && cp <= 19903) ||
               (cp >= 19968 && cp <= 40959) ||
               (cp >= 63744 && cp <= 64255) ||
               (cp >= 12353 && cp <= 12438) ||
               (cp >= 12445 && cp <= 12446) ||
               (cp >= 12449 && cp <= 12538) ||
               (cp >= 12540 && cp <= 12542) ||
               (cp >= 44032 && cp <= 55215)
      }
      function flush_ascii() {
        if (length(ascii) >= min && index(sw, " " ascii " ") == 0)
          seen[ascii] = 1
        ascii = ""
      }
      function flush_cjk(    n, i) {
        n = length(cjk)
        if (n >= 6) {
          for (i = 1; i <= n - 5; i += 3)
            seen[substr(cjk, i, 6)] = 1
        }
        cjk = ""
      }
      {
        for (i = 1; i <= NF; i++) bytes[++nb] = $i
      }
      END {
        i = 1
        while (i <= nb) {
          b1 = hexval(bytes[i])
          if (b1 < 128) {
            flush_cjk()
            ch = sprintf("%c", b1)
            if (ch ~ /[a-z0-9_]/) ascii = ascii ch
            else flush_ascii()
            i++
            continue
          }
          flush_ascii()
          if (b1 >= 224 && b1 < 240 && i + 2 <= nb) {
            b2 = hexval(bytes[i + 1])
            b3 = hexval(bytes[i + 2])
            if (b2 >= 128 && b2 < 192 && b3 >= 128 && b3 < 192) {
              cp = (b1 - 224) * 4096 + (b2 - 128) * 64 + (b3 - 128)
              if (is_cjk(cp)) {
                cjk = cjk sprintf("%c", b1) sprintf("%c", b2) sprintf("%c", b3)
                i += 3
                continue
              }
            }
          }
          flush_cjk()
          if (b1 >= 192 && b1 < 224 && i + 1 <= nb) i += 2
          else if (b1 >= 224 && b1 < 240 && i + 2 <= nb) i += 3
          else if (b1 >= 240 && b1 < 248 && i + 3 <= nb) i += 4
          else i++
        }
        flush_ascii()
        flush_cjk()
        for (t in seen) print t
      }
    ' \
    | LC_ALL=C sort -u
}
fi
