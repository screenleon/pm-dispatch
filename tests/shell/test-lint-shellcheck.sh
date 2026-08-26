#!/usr/bin/env bash
# Regression tests for canonical ShellCheck domain coverage and ignore ratchets.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-shellcheck.sh"
BOOTSTRAP="$REPO_ROOT/tools/lint/bootstrap-shellcheck.sh"

# shellcheck source=tests/lib/test-harness.sh
# Resolved from SCRIPT_DIR at runtime.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

fixture_repo() {
  local name="$1" root
  # shellcheck disable=SC2154  # tmp_root is initialized by th_init.
  root="$tmp_root/$name"
  mkdir -p "$root/tools/lint" "$root/runtime" "$root/tests" "$root/ops" \
    "$root/hosts" "$root/scripts"
  cp "$LINTER" "$root/tools/lint/lint-shellcheck.sh"
  cp "$BOOTSTRAP" "$root/tools/lint/bootstrap-shellcheck.sh"
  cp "$REPO_ROOT/.shellcheck-version" "$root/.shellcheck-version"
  cp "$REPO_ROOT/tools/lint/shellcheck-assets.tsv" "$root/tools/lint/"
  cp "$REPO_ROOT/tools/lint/shellcheck-domains.tsv" "$root/tools/lint/"
  printf 'path\tcodes\treason\n' > "$root/tools/lint/shellcheck-ignores.tsv"
  printf '#!/usr/bin/env bash\nset -euo pipefail\nprintf "ok\\n"\n' > "$root/runtime/pass.sh"
  printf '%s\n' "$root"
}

# The asset platform key for this host, or empty where no pinned asset is
# published — cases that need a cache path or an asset row skip on empty.
# Mirrors detect_platform in tools/lint/bootstrap-shellcheck.sh; kept here so a
# test never sources the script it is verifying.
fixture_platform() {
  case "$(uname -s):$(uname -m)" in
    Linux:x86_64) printf 'linux.x86_64\n' ;;
    Linux:aarch64|Linux:arm64) printf 'linux.aarch64\n' ;;
    Darwin:x86_64) printf 'darwin.x86_64\n' ;;
    Darwin:arm64|Darwin:aarch64) printf 'darwin.aarch64\n' ;;
    *) printf '\n' ;;
  esac
}

# Point a fixture's asset manifest at $2 as the trusted binary for $3 (platform),
# so a stub standing in for the pinned release can pass digest verification.
# $4 overrides the archive URL/sha columns when a case does not exercise install.
write_fixture_manifest() {
  local root="$1" binary="$2" platform="$3" url="${4:-file:///nonexistent.tar.gz}"
  local archive_sha="${5:-$(printf '%064d' 0)}" digest
  digest="$(sha256_of "$binary")"
  {
    printf 'version\tplatform\turl\tsha256\tbinary_sha256\n'
    printf '0.11.0\t%s\t%s\t%s\t%s\n' "$platform" "$url" "$archive_sha" "$digest"
  } > "$root/tools/lint/shellcheck-assets.tsv"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

expect_fail() {
  local name="$1" root="$2" needle="$3" output status=0
  output="$(bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$output" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status expected=$needle output=$output"
  fi
}

# Behavior: the checked-in inventory covers every canonical implementation and compatibility shim.
# Steps: list the shared linter input; require every migrated shell target and retained shim.
test_moved_path_parity() {
  local name="lint-shellcheck/moved-path-parity" listed path target disposition missing=""
  should_run "$name" || return 0
  listed="$(bash "$LINTER" --list)"
  while IFS=$'\t' read -r path _ _ target disposition _; do
    [[ "$path" != current_path ]] || continue
    if [[ "$target" == *.sh ]] && ! grep -Fxq "$target" <<< "$listed"; then
      missing+="target:$target "
    fi
    if [[ "$disposition" == move-with-shim && "$path" == *.sh ]] \
        && ! grep -Fxq "$path" <<< "$listed"; then
      missing+="shim:$path "
    fi
  done < "$REPO_ROOT/docs/architecture/script-domain-inventory.tsv"
  if [[ -z "$missing" ]]; then
    pass "$name"
  else
    fail "$name" "missing from ShellCheck input: $missing"
  fi
}

# Behavior: a new violation in any canonical domain or the shim domain is checked by default.
# Steps: inject one SC2034 violation under every inventory root; require one run to report all paths.
test_domain_injection_fails() {
  local name="lint-shellcheck/domain-injection-fails" root domain output status=0 missing=""
  should_run "$name" || return 0
  root="$(fixture_repo injection)"
  for domain in runtime tests tools ops hosts scripts; do
    mkdir -p "$root/$domain/nested"
    printf '#!/usr/bin/env bash\nunused_value=1\n' > "$root/$domain/nested/injected.sh"
  done
  output="$(bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  for domain in runtime tests tools ops hosts scripts; do
    [[ "$output" == *"$domain/nested/injected.sh"* ]] || missing+="$domain "
  done
  if [[ "$status" -ne 0 && -z "$missing" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status missing=$missing output=$output"
  fi
}

# Behavior: migration-era basename ignores cannot silently survive after a move.
# Steps: add a nonexistent canonical ignore path; require the stale-path diagnostic.
test_stale_ignore_fails() {
  local name="lint-shellcheck/stale-ignore-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo stale-ignore)"
  printf 'runtime/lib/moved-away.sh\tSC2034\tlegacy-warning\n' >> "$root/tools/lint/shellcheck-ignores.tsv"
  expect_fail "$name" "$root" "stale ignore path does not exist"
}

# Behavior: every explicit exception carries reviewable provenance and applies only to canonical code.
# Steps: add a reasonless row and a compatibility-shim row; require both forms to fail.
test_ignore_contract_fails_closed() {
  local name="lint-shellcheck/ignore-contract-fails-closed" root output status=0
  should_run "$name" || return 0
  root="$(fixture_repo ignore-contract)"
  printf 'runtime/pass.sh\tSC2034\t\n' >> "$root/tools/lint/shellcheck-ignores.tsv"
  output="$(bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -eq 0 || "$output" != *"exact path with codes and one reason"* ]]; then
    fail "$name" "reasonless row was accepted: status=$status output=$output"
    return
  fi
  printf 'path\tcodes\treason\n' > "$root/tools/lint/shellcheck-ignores.tsv"
  printf '#!/usr/bin/env bash\nunused_value=1\n' > "$root/scripts/shim.sh"
  printf 'scripts/shim.sh\tSC2034\tlegacy-warning\n' >> "$root/tools/lint/shellcheck-ignores.tsv"
  expect_fail "$name" "$root" "ignore is not a canonical shell path"
}

# Behavior: a baseline suppresses only named legacy codes, not future findings in that file.
# Steps: suppress SC2034, inject SC2086 in the same path, and require the new code to fail.
test_suppression_is_code_scoped() {
  local name="lint-shellcheck/suppression-is-code-scoped" root
  should_run "$name" || return 0
  root="$(fixture_repo code-scope)"
  printf 'runtime/pass.sh\tSC2034\tlegacy-unused-value\n' >> \
    "$root/tools/lint/shellcheck-ignores.tsv"
  cat > "$root/runtime/pass.sh" <<'SCRIPT'
#!/usr/bin/env bash
value="$*"
echo $value
SCRIPT
  expect_fail "$name" "$root" "SC2086"
}

# Behavior: CI installs and local lint enforces the repository-pinned
# ShellCheck contract rather than trusting an ambient runner or package-manager version.
# Steps: inspect the CI bootstrap, version report, local exact-version check, and
# retired action surfaces; assert every entrypoint uses the repository-owned pin.
test_ci_local_entrypoint_parity() {
  local name="lint-shellcheck/ci-local-entrypoint-parity" output status=0
  should_run "$name" || return 0
  output="$(PM_DISPATCH_SHELLCHECK_JOBS=9 \
    bash "$REPO_ROOT/tools/lint/lint-scripts.sh" --hygiene-only 2>&1)" || status=$?
  # shellcheck disable=SC2016  # Match literal maintainer commands documented for later shell evaluation.
  if [[ "$status" -eq 0 && "$output" != *"lint-shellcheck: OK"* ]] \
      && grep -Fq './tools/lint/lint-shellcheck.sh' "$REPO_ROOT/.github/workflows/lint.yml" \
      && grep -Fq 'bootstrap-shellcheck.sh --cache-dir' "$REPO_ROOT/.github/workflows/lint.yml" \
      && grep -Fq 'run: shellcheck --version' "$REPO_ROOT/.github/workflows/lint.yml" \
      && grep -Fq 'bootstrap-shellcheck.sh' "$LINTER" \
      && grep -Fq '.shellcheck-version' "$BOOTSTRAP" \
      && grep -Fq 'shellcheck_bin_dir="$(bash tools/lint/bootstrap-shellcheck.sh)" &&' \
        "$REPO_ROOT/CONTRIBUTING.md" \
      && grep -Fq 'export PATH="$shellcheck_bin_dir:$PATH"' "$REPO_ROOT/CONTRIBUTING.md" \
      && ! grep -Fq 'export PATH="$(bash tools/lint/bootstrap-shellcheck.sh)' \
        "$REPO_ROOT/CONTRIBUTING.md" \
      && ! grep -Fq 'export PATH="$(bash tools/lint/bootstrap-shellcheck.sh)' "$BOOTSTRAP" \
      && grep -Fq 'tools/lint/lint-shellcheck.sh' "$REPO_ROOT/tools/lint/lint-scripts.sh" \
      && grep -Fq 'run: ./tools/lint/lint-scripts.sh --hygiene-only' "$REPO_ROOT/.github/workflows/lint.yml" \
      && ! grep -Fq 'ignore_names:' "$REPO_ROOT/.github/workflows/lint.yml" \
      && ! grep -Fq 'action-shellcheck' "$REPO_ROOT/.github/workflows/lint.yml" \
      && ! grep -Eq 'apt(-get)?[^[:cntrl:]]+install[^[:cntrl:]]+shellcheck' \
        "$REPO_ROOT/.github/workflows/lint.yml"; then
    pass "$name"
  else
    fail "$name" "CI/local ShellCheck entrypoints diverged or legacy action config remains"
  fi
}

# Write a ShellCheck stub at $1 reporting version $2. Each invocation appends
# `version` or `lint` to the log at $3 (default: discarded), so a test can tell
# which binary ran and what it was asked to do.
write_shellcheck_stub() {
  local path="$1" version="$2" calls="${3:-/dev/null}"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<STUB
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == --version ]]; then
  printf 'version\n' >> '$calls'
  printf 'ShellCheck\nversion: $version\n'
  exit 0
fi
printf 'lint\n' >> '$calls'
STUB
  chmod +x "$path"
}

# Behavior: lint fails before scanning when neither PATH nor the tool cache can
# supply the pinned ShellCheck, and names both probes plus the fix.
# Steps: Arrange a 0.10.0 PATH stub and an empty tool cache; Act by running the
# linter; Assert exit 2, the expected/actual versions, the exact cache path
# probed, and the bootstrap command that populates it.
test_wrong_shellcheck_version_fails_closed() {
  local name="lint-shellcheck/wrong-version-fails-closed" root output status=0
  should_run "$name" || return 0
  root="$(fixture_repo wrong-version)"
  write_shellcheck_stub "$root/bin/shellcheck" 0.10.0
  # An empty cache: this case is about having no usable binary anywhere. The
  # maintainer's real cache would otherwise rescue the run and this assertion
  # would silently stop testing the failure it names.
  output="$(PATH="$root/bin:$PATH" PM_DISPATCH_TOOL_CACHE="$root/empty-cache" \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -eq 2 \
      && "$output" == *"expected 0.11.0, got 0.10.0"* \
      && "$output" == *"$root/empty-cache/shellcheck/0.11.0/"*"/bin/shellcheck"* \
      && "$output" == *"bootstrap-shellcheck.sh"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status output=$output"
  fi
}

# Behavior: --check and --resolve cannot be combined, so neither contract can be
# selected by accident.
# Steps: Arrange a fixture; Act by invoking bootstrap with both flags; Assert
# exit 2, the mutual-exclusion diagnostic, and that no bin directory was printed.
test_check_and_resolve_are_mutually_exclusive() {
  local name="lint-shellcheck/check-and-resolve-mutually-exclusive" root out err status=0
  should_run "$name" || return 0
  root="$(fixture_repo check-resolve)"
  out="$root/both.out"
  err="$root/both.err"
  bash "$root/tools/lint/bootstrap-shellcheck.sh" --repo "$root" --check --resolve \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 2 \
      && "$(cat "$err")" == *"--check and --resolve are mutually exclusive"* \
      && ! -s "$out" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status stdout=$(cat "$out") stderr=$(cat "$err")"
  fi
}

# Behavior: when PATH holds a non-pinned ShellCheck but the tool cache already
# holds the pinned one, lint scans with the cached binary instead of stopping.
# Steps: Arrange a 0.8.0 PATH stub and a cache containing a pinned stub, both
# instrumented; Act by running the linter; Assert exit 0, that the cached binary
# performed the lint invocations, and that the PATH binary linted nothing.
test_cached_pin_used_when_path_version_wrong() {
  local name="lint-shellcheck/cached-pin-used-when-path-wrong" root platform
  local cache_bin path_calls cache_calls output status=0
  should_run "$name" || return 0
  root="$(fixture_repo cached-pin)"
  platform="$(fixture_platform)"
  [[ -n "$platform" ]] || { pass "$name"; return; }
  # Each stub logs to its own file, so the assertion below can tell which
  # binary actually performed the scan.
  path_calls="$root/path-calls.log"
  cache_calls="$root/cache-calls.log"
  cache_bin="$root/cache/shellcheck/0.11.0/$platform/bin/shellcheck"
  write_shellcheck_stub "$root/bin/shellcheck" 0.8.0 "$path_calls"
  write_shellcheck_stub "$cache_bin" 0.11.0 "$cache_calls"
  # The cache is authenticated by content, so the fixture must declare this stub
  # as its trusted binary — the same requirement a real cached release meets.
  write_fixture_manifest "$root" "$cache_bin" "$platform"
  : > "$path_calls"
  : > "$cache_calls"

  output="$(PATH="$root/bin:$PATH" PM_DISPATCH_TOOL_CACHE="$root/cache" \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  local cache_lints path_lints
  cache_lints="$(grep -c '^lint$' "$cache_calls" || true)"
  path_lints="$(grep -c '^lint$' "$path_calls" || true)"
  if [[ "$status" -eq 0 && "$cache_lints" -ge 1 && "$path_lints" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status cache_lints=$cache_lints path_lints=$path_lints output=$output"
  fi
}

# Behavior: a cached binary that does not match the repository's trusted digest
# is never executed at all — not to lint, and not even to ask its version.
# Steps: Arrange a cache stub whose --version says 0.11.0 while the manifest
# records a different digest; Act by running the linter and the installer reuse
# path; Assert exit 2, a digest diagnostic, and zero invocations of the stub.
test_tampered_cache_binary_is_rejected() {
  local name="lint-shellcheck/tampered-cache-binary-rejected" root platform
  local cache_bin cache_calls output status=0
  should_run "$name" || return 0
  root="$(fixture_repo tampered-cache)"
  platform="$(fixture_platform)"
  [[ -n "$platform" ]] || { pass "$name"; return; }
  cache_bin="$root/cache/shellcheck/0.11.0/$platform/bin/shellcheck"
  cache_calls="$root/cache-calls.log"
  # Record the digest of the legitimate binary, then swap in an impostor that
  # still self-reports the pinned version — the exact shape a version probe
  # alone cannot catch.
  write_shellcheck_stub "$cache_bin" 0.11.0 "$cache_calls"
  write_fixture_manifest "$root" "$cache_bin" "$platform"
  write_shellcheck_stub "$cache_bin" 0.11.0 "$cache_calls"
  printf '# tampered\n' >> "$cache_bin"
  write_shellcheck_stub "$root/bin/shellcheck" 0.8.0
  : > "$cache_calls"

  output="$(env -u HOME XDG_CACHE_HOME="$root/xdg" PM_DISPATCH_TOOL_CACHE="$root/cache" \
    PATH="$root/bin:$PATH" \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  # Any line at all means the impostor ran: the version probe is an execution
  # too, and it is the one an attacker reaches first.
  if [[ "$status" -ne 2 || "$output" != *"does not match the trusted digest"* ]]; then
    fail "$name" "lint accepted the tampered cache: status=$status output=$output"
    return
  fi
  if [[ -s "$cache_calls" ]]; then
    fail "$name" "tampered binary was executed before authentication: $(<"$cache_calls")"
    return
  fi

  # The installer's reuse-an-existing-cache fast path must hold the same order.
  status=0
  output="$(env -u HOME XDG_CACHE_HOME="$root/xdg" PM_DISPATCH_TOOL_CACHE="$root/cache" \
    PATH="$root/bin:$PATH" \
    bash "$root/tools/lint/bootstrap-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ -s "$cache_calls" ]]; then
    fail "$name" "installer reuse path executed the tampered binary: $(<"$cache_calls")"
    return
  fi
  if [[ "$status" -eq 0 ]]; then
    fail "$name" "installer reuse path accepted the tampered cache: $output"
    return
  fi
  pass "$name"
}

# Behavior: an archive whose checksum matches but whose extracted binary does not
# match the manifest digest is rejected before that binary is run or published.
# Steps: Arrange a valid local archive with a deliberately wrong binary_sha256;
# Act by bootstrapping it; Assert exit 2, the digest diagnostic, and no binary
# installed into the cache.
test_bootstrap_rejects_wrong_binary_digest() {
  local name="lint-shellcheck/bootstrap-rejects-wrong-binary-digest" root payload archive
  local platform sha output status=0
  should_run "$name" || return 0
  root="$(fixture_repo bad-binary-digest)"
  platform="$(fixture_platform)"
  [[ -n "$platform" ]] || { pass "$name"; return; }
  payload="$root/payload/shellcheck-v0.11.0"
  archive="$root/shellcheck-v0.11.0.test.tar.gz"
  write_shellcheck_stub "$payload/shellcheck" 0.11.0
  tar -czf "$archive" -C "$root/payload" shellcheck-v0.11.0
  sha="$(sha256_of "$archive")"
  # Archive checksum honest, binary digest wrong: the shape where a supplier or
  # a mirror ships a correctly-checksummed archive with different contents than
  # the one this repository reviewed.
  printf 'version\tplatform\turl\tsha256\tbinary_sha256\n' \
    > "$root/tools/lint/shellcheck-assets.tsv"
  printf '0.11.0\t%s\tfile://%s\t%s\t%s\n' \
    "$platform" "$archive" "$sha" "$(printf 'a%.0s' {1..64})" \
    >> "$root/tools/lint/shellcheck-assets.tsv"

  output="$(env -u HOME XDG_CACHE_HOME="$root/xdg" \
    PM_DISPATCH_TOOL_CACHE="$root/cache" \
    bash "$root/tools/lint/bootstrap-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -ne 2 || "$output" != *"does not match the trusted digest"* ]]; then
    fail "$name" "wrong binary digest accepted: status=$status output=$output"
    return
  fi
  if [[ -e "$root/cache/shellcheck/0.11.0/$platform/bin/shellcheck" ]]; then
    fail "$name" "a rejected binary was published into the cache"
    return
  fi
  pass "$name"
}

# Behavior: a relative tool cache resolves against the caller's directory and
# still works once lint changes into the repository to scan.
# Steps: Arrange a cached pinned stub and a relative PM_DISPATCH_TOOL_CACHE; Act
# by running the linter from a different CWD with an explicit --repo; Assert the
# scan completes using the cached binary.
test_relative_cache_survives_repo_chdir() {
  local name="lint-shellcheck/relative-cache-survives-chdir" root platform
  local cache_bin cache_calls output status=0 lint_calls
  should_run "$name" || return 0
  root="$(fixture_repo relative-cache)"
  platform="$(fixture_platform)"
  [[ -n "$platform" ]] || { pass "$name"; return; }
  # The cache lives under the CALLER's directory, not the repository — otherwise
  # a relative path would resolve correctly by coincidence once lint chdirs, and
  # this case would prove nothing.
  local caller="$root/caller"
  mkdir -p "$caller"
  cache_bin="$caller/cache/shellcheck/0.11.0/$platform/bin/shellcheck"
  cache_calls="$root/cache-calls.log"
  write_shellcheck_stub "$cache_bin" 0.11.0 "$cache_calls"
  write_fixture_manifest "$root" "$cache_bin" "$platform"
  write_shellcheck_stub "$root/bin/shellcheck" 0.8.0
  : > "$cache_calls"

  output="$(cd "$caller" && env -u HOME XDG_CACHE_HOME="$root/xdg" \
    PM_DISPATCH_TOOL_CACHE=cache PATH="$root/bin:$PATH" \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  lint_calls="$(grep -c '^lint$' "$cache_calls" || true)"
  if [[ "$status" -eq 0 && "$lint_calls" -ge 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status lint_calls=$lint_calls output=$output"
  fi
}

# Behavior: a matching ShellCheck is version-probed once and then used for the
# normal canonical-domain scan.
# Steps: Arrange an instrumented 0.11.0 stub; Act by running the fixture linter;
# Assert success, one version probe, and at least one lint invocation.
test_matching_shellcheck_version_scans() {
  local name="lint-shellcheck/matching-version-scans" root calls output status=0
  local version_calls lint_calls
  should_run "$name" || return 0
  root="$(fixture_repo matching-version)"
  calls="$root/calls.log"
  write_shellcheck_stub "$root/bin/shellcheck" 0.11.0 "$calls"
  : > "$calls"
  output="$(PATH="$root/bin:$PATH" \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  version_calls="$(grep -c '^version$' "$calls" || true)"
  lint_calls="$(grep -c '^lint$' "$calls" || true)"
  if [[ "$status" -eq 0 && "$version_calls" -eq 1 && "$lint_calls" -ge 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status version_calls=$version_calls lint_calls=$lint_calls output=$output"
  fi
}

# Behavior: a missing or multi-line repository pin cannot silently fall back to
# the ambient ShellCheck version.
# Steps: Arrange missing then malformed pin files; Act by running the linter for
# each; Assert both fail with their distinct repository-contract diagnostics.
test_version_pin_shape_fails_closed() {
  local name="lint-shellcheck/version-pin-shape-fails-closed" root output status=0
  should_run "$name" || return 0
  root="$(fixture_repo pin-shape)"
  rm -f "$root/.shellcheck-version"
  output="$(bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -ne 2 || "$output" != *"missing repository version pin"* ]]; then
    fail "$name" "missing pin accepted: status=$status output=$output"
    return
  fi
  printf '0.11.0\n0.10.0\n' > "$root/.shellcheck-version"
  status=0
  output="$(bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$output" == *"exactly one semantic version"* ]]; then
    pass "$name"
  else
    fail "$name" "malformed pin accepted: status=$status output=$output"
  fi
}

# Behavior: bootstrap installs only a checksum-matching asset and publishes an
# executable whose reported version matches the repository pin.
# Steps: Arrange a local release archive and matching manifest; Act by bootstrapping
# it and then corrupting the archive; Assert the first install works and the second is rejected.
test_bootstrap_verifies_asset_checksum() {
  local name="lint-shellcheck/bootstrap-verifies-asset-checksum" root payload archive
  local platform sha bin_dir output status=0
  should_run "$name" || return 0
  root="$(fixture_repo bootstrap-checksum)"
  payload="$root/payload/shellcheck-v0.11.0"
  archive="$root/shellcheck-v0.11.0.test.tar.gz"
  platform="$(fixture_platform)"
  [[ -n "$platform" ]] || { pass "$name"; return; }
  write_shellcheck_stub "$payload/shellcheck" 0.11.0
  tar -czf "$archive" -C "$root/payload" shellcheck-v0.11.0
  if command -v sha256sum >/dev/null 2>&1; then
    sha="$(sha256sum "$archive" | awk '{ print $1 }')"
  else
    sha="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
  fi
  write_fixture_manifest "$root" "$payload/shellcheck" "$platform" \
    "file://$archive" "$sha"
  bin_dir="$(env -u HOME XDG_CACHE_HOME="$root/xdg-cache" \
    PM_DISPATCH_TOOL_CACHE="$root/cache-good" \
    bash "$root/tools/lint/bootstrap-shellcheck.sh" --repo "$root")" || status=$?
  if [[ "$status" -ne 0 || ! -x "$bin_dir/shellcheck" \
      || "$bin_dir" != "$root/cache-good/"* \
      || "$("$bin_dir/shellcheck" --version)" != *"version: 0.11.0"* ]]; then
    fail "$name" "verified fixture did not install: status=$status bin_dir=$bin_dir"
    return
  fi
  printf 'corrupt\n' >> "$archive"
  status=0
  output="$(bash "$root/tools/lint/bootstrap-shellcheck.sh" --repo "$root" \
    --cache-dir "$root/cache-bad" 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$output" == *"checksum mismatch"* ]]; then
    pass "$name"
  else
    fail "$name" "corrupt asset accepted: status=$status output=$output"
  fi
}

# Behavior: explicit concurrency tuning cannot exceed the supported eight-worker ceiling.
# Steps: request nine workers in a fixture and require the range validation to fail before execution.
test_worker_override_ceiling() {
  local name="lint-shellcheck/worker-override-ceiling" root output status=0
  should_run "$name" || return 0
  root="$(fixture_repo worker-ceiling)"
  output="$(PM_DISPATCH_SHELLCHECK_JOBS=9 \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$output" == *"integer from 1 to 8"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status output=$output"
  fi
}

# Behavior: the local linter does not turn host CPU count into unbounded parallelism.
# Steps: use an instrumented ShellCheck stub whose invocations register at a
# shared counter (guarded by the repo's own serialize_with_lock, so this stays
# on the same portable-locking primitive production code already depends on)
# and block on a blocking FIFO read -- never a sleep loop -- until a second
# concurrent worker signals release. This makes the two-way overlap a
# deterministic property of the barrier protocol rather than a hope that a
# fixed sleep window lines up with host scheduling. If the real cap ever
# collapses to one, no second worker ever arrives to signal release, so the
# lone worker's bounded FIFO read times out and fails with a clear message
# instead of hanging.
test_default_worker_cap() {
  local name="lint-shellcheck/default-worker-cap" root events barrier output status=0 max_active
  should_run "$name" || return 0
  root="$(fixture_repo worker-cap)"
  events="$root/events.log"
  barrier="$root/barrier"
  mkdir -p "$root/bin" "$barrier"
  printf '0' > "$barrier/count"
  mkfifo "$barrier/release.fifo"
  # The barrier pairs workers strictly by arrival order, so the fixture's
  # total shell-file count (these five plus the three fixture_repo already
  # creates) must be even -- an odd file out would have no partner to
  # release it.
  for n in 1 2 3 4 5; do
    printf '#!/usr/bin/env bash\nset -euo pipefail\n' > "$root/tests/worker-$n.sh"
  done
  cat > "$root/bin/shellcheck" <<STUB
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == --version ]]; then
  printf 'ShellCheck\nversion: 0.11.0\n'
  exit 0
fi
# shellcheck source=/dev/null
. "$REPO_ROOT/runtime/lib/portable.sh"
events="\${SHELLCHECK_EVENTS:?}"
barrier="\${SHELLCHECK_BARRIER_DIR:?}"
counter="\$barrier/count"
mine="\$barrier/count.\$\$"

register_arrival() {
  local count
  count=\$(<"\$counter")
  count=\$((count + 1))
  printf '%s' "\$count" > "\$counter"
  printf 'active %s\n' "\$count" >> "\$events"
  printf '%s' "\$count" > "\$mine"
}
serialize_with_lock "\$barrier/lock" register_arrival
count="\$(<"\$mine")"
rm -f "\$mine"

exec {relfd}<>"\$barrier/release.fifo"
if [[ "\$count" -eq 1 ]]; then
  if ! read -r -t 5 -u "\$relfd" _; then
    printf 'shellcheck-stub: timed out waiting for a second concurrent worker\n' >&2
    exit 1
  fi
else
  printf '\n' >&"\$relfd"
fi

deregister() {
  local count
  count=\$(<"\$counter")
  count=\$((count - 1))
  printf '%s' "\$count" > "\$counter"
}
serialize_with_lock "\$barrier/lock" deregister
STUB
  chmod +x "$root/bin/shellcheck"
  # Assert the built-in default, not an override inherited from the caller.
  output="$(env -u PM_DISPATCH_SHELLCHECK_JOBS PATH="$root/bin:$PATH" SHELLCHECK_EVENTS="$events" \
    SHELLCHECK_BARRIER_DIR="$barrier" \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  max_active="$(awk '
    $1 == "active" && $2 > max { max = $2 }
    END { print max + 0 }
  ' "$events")"
  if [[ "$status" -eq 0 && "$max_active" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status max_active=$max_active output=$output"
  fi
}

test_moved_path_parity
test_domain_injection_fails
test_stale_ignore_fails
test_ignore_contract_fails_closed
test_suppression_is_code_scoped
test_ci_local_entrypoint_parity
test_wrong_shellcheck_version_fails_closed
test_check_and_resolve_are_mutually_exclusive
test_cached_pin_used_when_path_version_wrong
test_tampered_cache_binary_is_rejected
test_bootstrap_rejects_wrong_binary_digest
test_relative_cache_survives_repo_chdir
test_matching_shellcheck_version_scans
test_version_pin_shape_fails_closed
test_bootstrap_verifies_asset_checksum
test_default_worker_cap
test_worker_override_ceiling
th_summary
