# CVE Coverage — android14-6.1

Source archive: Android Security Bulletins 2025-12 through 2026-07 and selected upstream kernel CVE fixes published after the last kernel bulletin.
Bulletins 2026-01, 2026-02, 2026-04, 2026-05, and 2026-07 contain no kernel
CVEs, so coverage spans the 2025-12, 2026-03, and 2026-06 bulletins.

All patches are the exact commits from the AOSP
`android14-6.1-2026-06` / `android14-6.1-lts` branches (via LTS merges or
Google cherry-picks), extracted with `git format-patch`, plus one post-bulletin
stable 6.1 backport for CVE-2026-43499. The series was
validated against a clean `android14-6.1` 6.1.118 checkout: every patch
either applies cleanly or is detected as already present, and a second run
reports 14/14 already applied (idempotent).

## Patched by this module (15 CVEs, 14 patches)

| CVE | Bulletin | Subsystem | Severity | Patch |
| --- | --- | --- | --- | --- |
| CVE-2024-43859 | 2026-03 | F2FS | Critical | 0001 (in AOSP since 6.1.109 — usually already present) |
| CVE-2025-38236 | 2025-12 | Net (af_unix) | High | 0002 (prerequisite) + 0003 |
| CVE-2025-38349 | 2025-12 | EPoll | High | 0004 |
| CVE-2025-48610 | 2025-12 | KVM (pvmfw) | High | 0005 |
| CVE-2025-38500 | 2025-12 | XFRM | Moderate | 0006 |
| CVE-2025-38618 | 2026-03 | vsock | High | 0007 |
| CVE-2025-39682 | 2026-03 | TLS | High | 0008 |
| CVE-2025-39946 | 2026-03 | TLS | High | 0009 |
| CVE-2025-40266 | 2026-03 | pKVM (FF-A) | High | 0010 |
| CVE-2026-0028 | 2026-03 | pKVM | Critical | 0011 |
| CVE-2026-0030 | 2026-03 | pKVM | Critical | 0011 (same fix as CVE-2026-0028) |
| CVE-2026-0031 | 2026-03 | pKVM | Critical | 0011 (same fix as CVE-2026-0028) |
| CVE-2026-0029 | 2026-03 | pKVM | High | 0012 |
| CVE-2026-0038 | 2026-03 | Hypervisor | Critical | 0013 (**partial**, see note) |
| CVE-2026-43499 | upstream post-bulletin | rtmutex / futex_requeue | High | 0014 |

## Not applicable to the android14-6.1 GKI tree

Verified against Google's own fixed branches (`android14-6.1-2026-03` and
`android14-6.1-2026-06`): none of these fixes exist there, because the
affected code is not part of this kernel line.

| CVE | Bulletin | Component | Reason |
| --- | --- | --- | --- |
| CVE-2025-38616 | 2026-03 | TLS | Fix targets the reworked TLS strparser; not backported to 6.1 by Google nor by stable `linux-6.1.y` |
| CVE-2026-0027 | 2026-03 | pKVM SMMU | `drivers/iommu/arm/arm-smmu-v3/pkvm/` does not exist in 6.1 |
| CVE-2026-0032 | 2026-03 | pKVM | Fix ("Prevent memory sharing outside of RAM") absent from all android14-6.1 branches |
| CVE-2026-0037 | 2026-03 | pKVM (FF-A) | Fix ("split the host ffa handle store") absent from all android14-6.1 branches |

## Not fixable in kernel source (vendor components)

| CVE | Bulletin | Component | Reason |
| --- | --- | --- | --- |
| CVE-2025-6349 | 2025-12 | Arm Mali GPU | Vendor driver, not in the GKI source tree |
| CVE-2025-8045 | 2025-12 | Arm Mali GPU | Vendor driver, not in the GKI source tree |
| CVE-2025-47351 | 2025-12 | Qualcomm DSP | Vendor kernel (msm), not in the GKI source tree |
| CVE-2025-47354 | 2025-12 | Qualcomm DSP | Vendor kernel (msm), not in the GKI source tree |
| CVE-2025-47388 | 2026-03 | Qualcomm | Vendor component |
| CVE-2025-47394 | 2026-03 | Qualcomm | Vendor component |
| CVE-2025-47396 | 2026-03 | Qualcomm | Vendor component |
| CVE-2025-47397 | 2026-03 | Qualcomm | Vendor component |
| CVE-2025-47398 | 2026-03 | Qualcomm | Vendor component |
| CVE-2025-59600 | 2026-03 | Qualcomm | Vendor component |
| CVE-2026-21385 | 2026-03 | Qualcomm Graphics | Vendor component — **actively exploited**; apply the vendor firmware update |
| CVE-2025-47392 | 2026-06 | Qualcomm closed-source | Requires vendor firmware update |
| CVE-2026-25276 | 2026-06 | Qualcomm closed-source | Requires vendor firmware update |
| CVE-2026-25277 | 2026-06 | Qualcomm closed-source | Requires vendor firmware update |

## Pending upstream

| CVE | Bulletin | Reason |
| --- | --- | --- |
| CVE-2025-40214 | 2026-06 | No fix commits published upstream yet — re-check later |

### Note on CVE-2026-0038

The bulletin references seven fix commits; six are not reachable on
android.googlesource.com or git.kernel.org (unpublished when this module was
assembled). The one published commit ("arm64: Disable MTE at EL1 and EL0 when
not supported") is included as patch 0013, so coverage is partial. Re-check
the remaining commits when AOSP publishes them.
