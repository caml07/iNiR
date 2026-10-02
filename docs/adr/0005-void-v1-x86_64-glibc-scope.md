# ADR-0005: Void V1 targets x86_64 glibc

- Status: Accepted
- Date: 2026-10-01
- Scope: Void Linux release support

## Context

iNiR's Void support is a capability contract, not only a compositor launch
check. A supported installation must provision and maintain the shell, its
selected dependency profiles, session supervision, system services, optional
provider boundaries, update/repair flows and repeatable validation.

Void publishes both glibc and musl variants, and important core packages such
as Niri and Quickshell can exist on musl. That is not sufficient to claim the
whole iNiR port is supported there. Several providers and fallback artifacts
need separate libc qualification, and proprietary/prebuilt software can be
explicitly glibc-only. Cloudflare WARP is one such optional provider. The
current release evidence (clean VM plus physical external-disk install) is also
for x86_64 glibc.

Supporting musl in the same release claim would therefore expand the test and
maintenance matrix without evidence that every exposed capability has reached
the same provider/provisioning/activation/operation/verification standard.

## Decision

The V1 Void release target is:

```text
Void Linux x86_64 glibc
+ runit
+ elogind
+ Turnstile/runsvdir session supervision
+ a working Niri-compatible graphics stack supplied by the base OS
```

The following are compatibility/experimental profiles, not release targets:

- Void musl;
- non-x86_64 Void;
- seatd-only sessions without elogind.

The installer and public documentation must not imply that those profiles have
release parity merely because the core packages are available.

Optional providers may be narrower than the base release target. For example,
the Cloudflare WARP Extra is x86_64 glibc-only and must remain optional; its
absence cannot make a normal Void install or Doctor unhealthy.

## Consequences

- Release qualification stays bounded to one reproducible Void libc/
  architecture profile.
- Hardware-specific GPU drivers remain the responsibility of the base Void
  installation; VirGL is only a requirement of the validated VirtIO VM path.
- musl-specific package notes can be retained as research/history, but they do
  not count as support evidence.
- A future musl port should use a dedicated branch/VM and re-run the provider
  matrix instead of inheriting the glibc claim.
- Adding musl support later does not require redesigning the runit/session
  architecture, but it does require explicit provider audits, fallback-binary
  audits, clean-install/update/reboot validation and documentation updates.

## Revisit criteria

Reconsider musl support when there is a clean x86_64-musl validation image and
all required profiles pass the same release gates as glibc. Providers that
cannot support musl must be either replaced or explicitly optional/degraded
without breaking the base shell.
