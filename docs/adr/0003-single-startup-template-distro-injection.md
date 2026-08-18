# ADR-0003: Single startup template with per-distro injection

`defaults/niri/config.d/50-startup.kdl` must render differently per
supervisor, but keeping one file per distro would diverge from Arch. Instead
the template stays the single source and setup injects/removes marked blocks
per distro and predicate — the same sed-patching mechanism `3.files.sh`
already uses for the polkit agent (`sdata/subcmd-install/3.files.sh:307-341`).

Today the template carries three systemd-hard facts:

- line 12: `systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6`
- lines 29-31: the "managed by inir.service, do not add a startup entry"
  comment
- no `runsvdir`/`inir` entry (Void needs one)

The injection is idempotent: re-running setup must not duplicate blocks, and
must respect the supervisor selected by the predicate (ADR-0002). The
startup-entry removal logic in migration 021 (`_remove_inir_startup_lines`,
regex on `spawn-at-startup.*inir`) must be extended to the runsvdir line so
the systemd and non-systemd paths stay mutually exclusive.

Status: proposed