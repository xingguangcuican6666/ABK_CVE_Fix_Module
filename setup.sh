#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$MODULE_DIR/module.conf" ]; then
  # shellcheck disable=SC1091
  source "$MODULE_DIR/module.conf"
fi

# shellcheck disable=SC1091
source "$MODULE_DIR/scripts/libabk.sh"

abk_require_env KERNEL_ROOT CUSTOM_EXTERNAL_MODULE_STAGE

abk_log "module: ${ABK_MODULE_NAME:-ABK CVE Patcher}"
abk_log "version: ${ABK_MODULE_VERSION:-unknown}"
abk_log "stage: $CUSTOM_EXTERNAL_MODULE_STAGE"
abk_log "config: ${CONFIG:-unknown}"
abk_log "kernel root: $KERNEL_ROOT"

# ---------------------------------------------------------------------------
# Options (set as environment variables, e.g. through workflow env):
#   ABK_CVE_SKIP     comma-separated CVE ids to skip, e.g. "CVE-2026-0038"
#   ABK_CVE_ONLY     comma-separated CVE ids; when set, apply only these
#   ABK_CVE_NONFATAL "true" to continue on patch failure instead of aborting
# ---------------------------------------------------------------------------
ABK_CVE_SKIP="${ABK_CVE_SKIP:-}"
ABK_CVE_ONLY="${ABK_CVE_ONLY:-}"
ABK_CVE_NONFATAL="${ABK_CVE_NONFATAL:-false}"

COMMON_DIR="$(abk_common_dir)"
abk_require_dir "$COMMON_DIR"

detect_series_name() {
  local android="${ABK_BUILD_ANDROID_VERSION:-}"
  local kver="${ABK_BUILD_KERNEL_VERSION:-}"

  if [ -z "$kver" ]; then
    local version patchlevel
    version="$(abk_kernel_make_value VERSION)"
    patchlevel="$(abk_kernel_make_value PATCHLEVEL)"
    kver="${version}.${patchlevel}"
  fi

  if [ -n "$android" ]; then
    printf '%s-%s\n' "$android" "$kver"
  else
    printf '%s\n' "$kver"
  fi
}

find_series_dir() {
  local name="$1"
  local dir="$MODULE_DIR/patches/$name"

  if [ -d "$dir" ]; then
    printf '%s\n' "$dir"
    return 0
  fi

  # Fall back to a kernel-line match (e.g. "6.1" -> patches/android14-6.1)
  # so the module still works when ABK_BUILD_* variables are not exported.
  local kver="${name##*-}"
  local candidate
  for candidate in "$MODULE_DIR/patches/"*"-$kver"; do
    if [ -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

in_cve_list() {
  local cves="$1"
  local list="$2"
  local cve
  local item
  IFS=',' read -r -a _cves <<< "$cves"
  IFS=',' read -r -a _list <<< "$list"
  for cve in "${_cves[@]}"; do
    for item in "${_list[@]}"; do
      if [ "$cve" = "$item" ]; then
        return 0
      fi
    done
  done
  return 1
}

SERIES_NAME="$(detect_series_name)"
if ! SERIES_DIR="$(find_series_dir "$SERIES_NAME")"; then
  abk_warn "no CVE patch series for kernel line '$SERIES_NAME'"
  available=""
  for d in "$MODULE_DIR/patches"/*/; do
    [ -d "$d" ] && available="$available$(basename "$d") "
  done
  abk_warn "available series: ${available:-none}"
  abk_warn "nothing to do, exiting cleanly"
  exit 0
fi

SERIES_FILE="$SERIES_DIR/series.tsv"
abk_require_file "$SERIES_FILE"
abk_log "patch series: $SERIES_DIR"

applied=0
already=0
skipped=0
failed=0
failed_cves=""

# guard_file/guard_string identify one line added by the fix. They are the
# primary "already fixed" detector: on trees where the fix landed through a
# different cherry-pick, context drift makes `git apply --reverse --check`
# fail even though the fix is present, and a blind 3-way apply could then
# duplicate code. The guard is also asserted after every successful apply.
guard_present() {
  local guard_file="$1"
  local guard_string="$2"
  [ -n "$guard_file" ] || return 1
  [ -f "$COMMON_DIR/$guard_file" ] || return 1
  grep -qF "$guard_string" "$COMMON_DIR/$guard_file"
}

while IFS=$'\t' read -r patch_name cves guard_file guard_string subject; do
  case "$patch_name" in
    ''|'#'*) continue ;;
  esac

  patch_file="$SERIES_DIR/$patch_name"
  abk_require_file "$patch_file"

  if [ -n "$ABK_CVE_ONLY" ] && ! in_cve_list "$cves" "$ABK_CVE_ONLY"; then
    abk_log "SKIP  ($cves) not in ABK_CVE_ONLY: $patch_name"
    skipped=$((skipped + 1))
    continue
  fi

  if [ -n "$ABK_CVE_SKIP" ] && in_cve_list "$cves" "$ABK_CVE_SKIP"; then
    abk_log "SKIP  ($cves) listed in ABK_CVE_SKIP: $patch_name"
    skipped=$((skipped + 1))
    continue
  fi

  if guard_present "$guard_file" "$guard_string"; then
    abk_log "OK    ($cves) fix already present: $subject"
    already=$((already + 1))
    continue
  fi

  if git -C "$COMMON_DIR" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
    abk_log "OK    ($cves) already applied: $subject"
    already=$((already + 1))
    continue
  fi

  ok=""
  if git -C "$COMMON_DIR" apply --check "$patch_file" >/dev/null 2>&1; then
    git -C "$COMMON_DIR" apply "$patch_file"
    ok="plain"
  elif git -C "$COMMON_DIR" rev-parse --git-dir >/dev/null 2>&1 &&
       git -C "$COMMON_DIR" apply -3 "$patch_file" >/dev/null 2>&1; then
    # Three-way merge against the blob ids recorded in the patch. This
    # absorbs small context drift between sublevels.
    ok="3-way"
  fi

  if [ -n "$ok" ]; then
    if guard_present "$guard_file" "$guard_string"; then
      abk_log "APPLY ($cves) [$ok] $subject"
      applied=$((applied + 1))
      continue
    fi
    abk_warn "FAIL  ($cves) patch applied ($ok) but guard line is missing: $patch_name"
  else
    abk_warn "FAIL  ($cves) patch does not apply: $patch_name"
  fi
  failed=$((failed + 1))
  failed_cves="${failed_cves:+$failed_cves,}$cves"
done < "$SERIES_FILE"

abk_log "summary: applied=$applied already=$already skipped=$skipped failed=$failed"

if [ "$failed" -gt 0 ]; then
  abk_warn "failed CVE patches: $failed_cves"
  abk_warn "set ABK_CVE_SKIP=\"<cve-ids>\" to skip them, or ABK_CVE_NONFATAL=true to ignore all failures"
  if [ "$ABK_CVE_NONFATAL" != "true" ]; then
    abk_die "one or more CVE patches failed to apply"
  fi
  abk_warn "ABK_CVE_NONFATAL=true, continuing despite failures"
fi

abk_log "done"
