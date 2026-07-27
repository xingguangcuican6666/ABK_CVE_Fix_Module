# ABK CVE Patcher

ABK external module that backports the kernel CVE fixes from the Android
Security Bulletins (December 2025 – July 2026) plus selected upstream kernel
CVE fixes published after the last kernel bulletin into the GKI kernel source tree
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
- otherwise reported as failed, which aborts the build (see options below).

Validated against a clean `android14-6.1` (6.1.118) checkout: first run
applies what is missing, second run reports 14/14 already applied.

## Options

Set as environment variables in a fork of the workflow, or export them from
another external module that runs earlier:

| Variable | Meaning |
| --- | --- |
| `ABK_CVE_SKIP` | Comma-separated CVE ids to skip, e.g. `CVE-2026-0038` |
| `ABK_CVE_ONLY` | Apply only the listed CVE ids |
| `ABK_CVE_NONFATAL` | `true` = log patch failures but do not abort the build |

## Covered CVEs (android14-6.1)

15 CVEs are covered by 14 patches (F2FS, af_unix, EPoll, XFRM, vsock, TLS,
KVM/pKVM, Hypervisor, rtmutex/futex). For `CVE-2026-43499`, the module carries the public
stable/upstream `remove_waiter()` fix; if a third-party probe still keys off a generic
`FUTEX_CMP_REQUEUE_PI -> EDEADLK` observation, that probe/result must be validated separately.
See [CVES.md](CVES.md) for the full table, including
the bulletin CVEs that are intentionally **not** covered: fixes that do not
apply to the 6.1 kernel line, Arm Mali / Qualcomm vendor components that are
not part of the GKI source tree, and CVEs whose fixes have not been published
upstream yet.

## License

GPL-3.0 for the module scripts. The patches under `patches/` are taken from
the Linux kernel / AOSP common kernel and are GPL-2.0.
