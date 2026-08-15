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

# retrieval_extract_terms <text>
#   Print unique lowercase terms, one per line, sorted.
#   ASCII: [a-z0-9_]+ of length >= 3, minus the shared English stop list.
#   CJK: overlapping 2-grams from each contiguous CJK/Hiragana/Katakana/Hangul
#   run of length >= 2. Single-character runs are dropped (too noisy).
#   FTS5 tokenization is intentionally not handled here.
if ! declare -F retrieval_extract_terms >/dev/null 2>&1; then
retrieval_extract_terms() {
  local text="${1-}"
  local stopwords=" ${RETRIEVAL_TERM_STOPWORDS} "
  local nbytes
  nbytes="$(printf '%s' "$text" | wc -c)"
  nbytes="${nbytes#"${nbytes%%[![:space:]]*}"}"
  nbytes="${nbytes%"${nbytes##*[![:space:]]}"}"
  if [[ "${nbytes:-0}" -gt "$RETRIEVAL_TERM_MAX_BYTES" ]]; then
    printf 'retrieval-terms: input truncated from %s bytes to %s bytes\n' \
      "$nbytes" "$RETRIEVAL_TERM_MAX_BYTES" >&2
    text="$(printf '%s' "$text" | head -c "$RETRIEVAL_TERM_MAX_BYTES")"
  fi
  # ASCII-only: keep the pre-CC-465 tr/awk pipeline (hook-critical path).
  if ! LC_ALL=C printf '%s' "$text" | LC_ALL=C grep -q $'[\200-\377]'; then
    printf '%s\n' "$text" \
      | tr '[:upper:]' '[:lower:]' \
      | tr -cs 'a-z0-9_' '\n' \
      | awk -v sw="$stopwords" 'length($0) >= 3 && index(sw, " " $0 " ") == 0' \
      | LC_ALL=C sort -u
    return 0
  fi
  # Byte-walk UTF-8 under LC_ALL=C so mawk/gawk agree on substr. od is the
  # same hex helper already used by state-writer / pmctl-task.
  printf '%s' "$text" \
    | tr '[:upper:]' '[:lower:]' \
    | od -An -tx1 -v \
    | LC_ALL=C awk -v sw="$stopwords" '
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
               (cp >= 12352 && cp <= 12543) ||
               (cp >= 44032 && cp <= 55215)
      }
      function flush_ascii() {
        if (length(ascii) >= 3 && index(sw, " " ascii " ") == 0)
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
