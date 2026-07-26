# ABK CVE Patcher

ABK external module that backports the kernel CVE fixes from the Android
Security Bulletins (December 2025 – July 2026) into the GKI kernel source tree
while ABK builds it.

The patches are taken from the matching AOSP common kernel branch
(`android14-6.1-2026-06`), so they are the exact fixes Google shipped for this
kernel line — not hand-written approximations.

## Usage

Add the module to the ABK build ("custom external modules"):

App / catalog:

```text
https://github.com/xingguangcuican6666/ABK_CVE_Fix_Module.git
```

GitHub Actions input (`custom_external_modules`):

```text
module:https://github.com/xingguangcuican6666/ABK_CVE_Fix_Module.git;after_patch
```

`after_patch` is the recommended stage: it runs after ABK's built-in source
integrations (SUSFS, ZRAM, KernelSU, …) and before compilation. `before_build`
also works — the patcher is idempotent, so it can even run at both stages.

## Supported kernel lines

| Series | Source branch | Status |
| --- | --- | --- |
| `android14-6.1` | `aosp/android14-6.1-2026-06` | Supported |

Builds of other kernel lines (5.10, 5.15, 6.6, 6.12) are detected and skipped
with a warning — the module never fails a build it has no patches for. To add
a line, see [docs/development.md](docs/development.md).

## Behavior

For the active kernel line, `setup.sh` applies the patch series in
`patches/<series>/series.tsv` in order. Each patch is:

- skipped when the tree already contains the fix — detected by a per-patch
  guard line plus `git apply --reverse --check`, so newer sublevels and
  re-runs are safe;
- applied with `git apply`, falling back to a three-way merge for small
  context drift between sublevels, with the guard line asserted afterwards;
- otherwise reported as failed and skipped — any partially applied changes
  are rolled back, the build continues without that fix, and the summary
  lists the affected CVE ids. Set `ABK_CVE_STRICT=true` to abort the build
  instead (see options below).

Validated against a clean `android14-6.1` (6.1.118) checkout: first run
applies what is missing, second run reports 13/13 already applied.

## Options

Set as environment variables in a fork of the workflow, or export them from
another external module that runs earlier:

| Variable | Meaning |
| --- | --- |
| `ABK_CVE_SKIP` | Comma-separated CVE ids to skip, e.g. `CVE-2026-0038` |
| `ABK_CVE_ONLY` | Apply only the listed CVE ids |
| `ABK_CVE_STRICT` | `true` = abort the build when a patch fails to apply. Default: failed patches are skipped with a warning |

`ABK_CVE_NONFATAL` (the old opposite of `ABK_CVE_STRICT`) is still accepted:
any explicit value other than `true` behaves like `ABK_CVE_STRICT=true`,
exactly as it did in 1.0.x. When both are set, `ABK_CVE_STRICT` wins.

## Covered CVEs (android14-6.1)

14 CVEs are covered by 13 patches (F2FS, af_unix, EPoll, XFRM, vsock, TLS,
KVM/pKVM, Hypervisor). See [CVES.md](CVES.md) for the full table, including
the bulletin CVEs that are intentionally **not** covered: fixes that do not
apply to the 6.1 kernel line, Arm Mali / Qualcomm vendor components that are
not part of the GKI source tree, and CVEs whose fixes have not been published
upstream yet.

## License

GPL-3.0 for the module scripts. The patches under `patches/` are taken from
the Linux kernel / AOSP common kernel and are GPL-2.0.
