# ABK CVE Patcher Development

This module follows the standard ABK external module contract: ABK clones the
repository during the build and runs `bash setup.sh` at the configured stage
(`after_patch` or `before_build`). See the
[ABK External Module Template](https://github.com/zzh20188/ABK_Externel_Module)
for the full contract.

## How the patcher works

1. `setup.sh` resolves the target patch series from the build parameters:
   `patches/${ABK_BUILD_ANDROID_VERSION}-${ABK_BUILD_KERNEL_VERSION}`
   (for example `patches/android14-6.1`). When those variables are missing it
   falls back to `VERSION.PATCHLEVEL` from `common/Makefile` and matches any
   `patches/*-<version>` directory.
2. If no series exists for the kernel line, the module logs a warning and
   exits `0` — it never breaks builds of kernel lines it has no patches for.
3. Otherwise it walks `series.tsv` in order and, for every patch:
   - if the **guard line** is already present in the tree → counted as
     **already fixed** (this catches trees where the fix landed through a
     different cherry-pick and reverse-apply would fail on context drift);
   - `git apply --reverse --check` → counted as **already applied**;
   - `git apply --check` + `git apply` → applied normally;
   - `git apply -3` → three-way fallback that absorbs small context drift
     between sublevels;
   - after any successful apply the guard line is asserted — if it is still
     missing the patch is treated as failed;
   - failures abort the build unless `ABK_CVE_NONFATAL=true`.

## series.tsv format

Tab-separated, one patch per line, applied top to bottom:

```text
<patch-file-name>	<CVE id>[,...]	<guard-file>	<guard-string>	<subject>
```

`guard-file` is a path relative to `common/`; `guard-string` is one line of
code added by the fix, unique enough to prove the fix is present. Pick it
from the patch's `+` lines and verify it does not occur in the pre-fix file.

Lines that are empty or start with `#` are ignored. Order matters: several
pKVM fixes touch the same files (`mem_protect.c`, `ffa.c`), so the series is
ordered exactly like the commits on the upstream `android14-6.1` branch.

## Adding a new bulletin month

1. Find the fix commits on the matching ACS branch
   (`android14-6.1-<YYYY-MM>` or newer), not on mainline — branch-native
   patches apply cleanly, mainline versions usually do not.
2. Export them with `git format-patch -1 --no-signature <sha>`.
3. Copy the files into `patches/<series>/` with the next sequence numbers and
   append matching lines to `series.tsv`.
4. Re-run the validation below.

## Adding a new kernel line

Create `patches/<androidNN-K.V>/` with its own `series.tsv` and patches taken
from the matching ACS branch (for example `android15-6.6-2026-06`). No change
to `setup.sh` is needed.

## Validating locally

Run the module against a kernel checkout the same way ABK does:

```bash
export KERNEL_ROOT=/path/to/kernel_root      # directory that contains common/
export DEFCONFIG=$KERNEL_ROOT/common/arch/arm64/configs/gki_defconfig
export CUSTOM_EXTERNAL_MODULE_STAGE=after_patch
export ABK_BUILD_ANDROID_VERSION=android14
export ABK_BUILD_KERNEL_VERSION=6.1
bash setup.sh
```

Run it twice: the second run must report every patch as `already applied`
(idempotence check). The current `android14-6.1` series contains 14 patches.
To restore the tree afterwards:

```bash
git -C "$KERNEL_ROOT/common" reset --hard && git -C "$KERNEL_ROOT/common" clean -fd
```

## Runtime options

| Variable | Meaning |
| --- | --- |
| `ABK_CVE_SKIP` | Comma-separated CVE ids to skip |
| `ABK_CVE_ONLY` | When set, apply only these CVE ids |
| `ABK_CVE_NONFATAL` | `true` = log failures but never abort the build |
