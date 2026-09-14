# iRiS — Apple Design Contract

iRiS is iNiR's Apple-inspired shell family. It is a separate product language, not a Material II
theme and not a Waffle variant. The default presentation is `island`; `classic` remains available
as a compatibility/fallback layout while the Apple direction expands.

This document describes the direction that must constrain new iRiS work and records the current
baseline introduced by the first Island/Dock pass.

## Product direction

- **Apple-inspired desktop composition.** Prefer calm neutral surfaces, continuous rounded
  silhouettes, strong spatial hierarchy, a centered Dock and a compact morphing Island.
- **Wallpaper-first.** Chrome should frame the desktop rather than cover it. Desktop widgets may
  participate, but they must read as part of the same family instead of importing Material II's
  visual dialect.
- **One visual family.** Palette, Control Center, notifications, OSD, session, lock, auth, Dock,
  Island and desktop widgets must feel like one system.
- **System-like behavior over decoration.** Interaction, hierarchy, motion and spacing matter more
  than ornamental shapes. Avoid adding visual elements merely to make a surface look "designed".
- **Preserve iNiR capability.** Apple aesthetics are the presentation contract; shared iNiR
  services and mature behavior primitives remain the implementation foundation where appropriate.

## Current baseline

The Apple branch currently establishes these pieces:

- `appearance.design = "island"` as the default iRiS design;
- a morphing top/bottom `IrisIsland` owned by `IrisBar`;
- integrated media state and volume/brightness/microphone feedback in the Island;
- an auto-hiding centered `IrisDock` using iNiR taskbar/app services;
- shared desktop widgets through `Background`, with iRiS semantic tokens and surfaces;
- iRiS Palette, Control Center, notification popup, OSD fallback, Session, Lock, Polkit and close
  confirmation surfaces;
- `classic` bar support retained as an alternate design;
- configurable density, motion, bar geometry, Dock behavior, module slots and surface sizing.

This is a **foundation**, not the final Apple pass. Some surfaces still contain visual vocabulary
from the earlier technical iRiS direction (for example uppercase technical section labels, accent
rails and older action-row composition). Those are transitional. New work should move them toward
the Apple grammar below rather than extending that older language.

## Apple visual grammar

### Surfaces

- Prefer one continuous surface per interaction region instead of cards nested inside cards.
- Island/Dock silhouettes use large continuous radii. The current Island radius resolves to
  `28px * density`; compact controls use smaller derived radii.
- Separators are quiet hairlines. Borders are not the primary way to create hierarchy.
- Avoid Material-specific ornamental shapes such as `MaterialCookie` as default containers.
- Avoid heavy drop shadows and permanent full-screen effects. If translucency/vibrancy is added,
  it must remain readable without blur and must have a measured runtime cost.
- Rounded geometry must be intentional: a capsule is for Island/Dock/control chrome, not a generic
  answer for every row.

### Baseline palette

The current Island implementation intentionally starts from an Apple-like neutral dark chassis:

```text
surface             #000000
surface high        #1c1c1e
surface highest     #2c2c2e
text                #f5f5f7
secondary text      #aeaeb2
muted text          #8e8e93
accent              #a8c7fa
secondary accent    #ff9f0a
danger              #ff6961
hairline            #262628
strong hairline     #48484a
```

These are semantic tokens owned by `IrisStyle.qml`; consumers must not copy the literals. A later
light appearance or wallpaper-adaptive variant belongs in `IrisStyle`, not in individual panels.

### Typography

- iRiS should read like a system UI: clean sans-serif body text, restrained weights, compact
  metadata and clear numeric/status hierarchy.
- Do **not** bundle Apple proprietary fonts. `fontFamily` and `titleFontFamily` remain user
  overrides; Island currently falls back to `Noto Sans` when no iRiS font is configured.
- Respect the shell-wide typography scale independently from iRiS density. Density controls
  geometry; typography scale controls text.
- Avoid making uppercase technical labels or letter-spaced eyebrows a defining Apple motif. They
  may remain during migration but should not spread to new surfaces.

### Icons

- Use `MaterialSymbol` only as iNiR's available semantic glyph engine, not as an excuse to copy
  Material component composition.
- Prefer simple monochrome glyphs with state conveyed by fill/weight, opacity or surrounding
  control material.
- Application identity uses `SmartAppIcon`; do not replace real app artwork with generic symbols.

### Motion

- Motion should feel direct and physical: short opacity, scale, radius and geometry transitions.
- Current Island geometry uses ~240ms `OutQuint`; Dock reveal uses ~180ms `OutCubic`; app hover
  scale is ~110ms.
- No persistent decorative animation in idle UI.
- `IrisStyle.duration()` remains the gate so global animation policy and the iRiS motion switch are
  respected.

## Island

`modules/iris/bar/IrisIsland.qml` is the signature iRiS surface.

Compact state should communicate only the most useful context:

- current media / system feedback;
- time;
- a small semantic status glyph.

Expanded state may expose:

- artwork and track metadata;
- media transport and seek controls;
- configured bar modules;
- a route to Quick Controls.

The Island should morph as one object. Do not simulate expansion by stacking unrelated cards or
opening another popup on top of it. Opening Palette/Control Center or a notification may collapse
the Island when those surfaces need priority.

## Dock

`modules/iris/dock/IrisDock.qml` is the Apple-style application anchor.

- centered on the active edge;
- auto-hide is configurable and enabled by default;
- real application icons come from iNiR's taskbar/app services;
- hover scale is subtle;
- running/active state uses a minimal indicator;
- secondary click exposes window/new-window/pin actions;
- Dock behavior must work independently of whether the bar is top or bottom.

Do not turn the Dock into another Material taskbar. Its primary hierarchy is icon, activity state
and spatial continuity.

## Desktop widgets

Island mode may reuse the existing iNiR `Background` widget canvas instead of maintaining a second
widget framework.

`AbstractBackgroundWidget.qml` and `WidgetSurface.qml` adapt shared widgets to `IrisStyle` when the
active family is iRiS/Island. That adaptation must remain presentation-only: widget behavior and
data providers stay shared.

Current Island widget surfaces are opaque. Any future glass/vibrancy treatment must be introduced
centrally and measured; do not independently enable wallpaper blur in every widget.

The `iris.modules.desktopWidgets` switch owns whether this shared canvas is loaded. When disabled,
the lightweight `IrisBackground` owns the wallpaper again.

## Controls and transient surfaces

Palette, Control Center, notifications, OSD, Session, Lock, Polkit and Close Confirm must converge
on the same Apple family vocabulary:

- strong title/content hierarchy;
- grouped controls without excessive nested cards;
- quiet separators;
- large but disciplined corner radii;
- clear selected/disabled/destructive states;
- keyboard focus that remains visible without adding a permanent outline to every control.

The current components reuse mature iNiR behavior primitives (`RippleButton`, `StyledSlider`,
`MaterialTextField`, `SmartAppIcon`, `MaterialSymbol`) while iRiS owns their composition and tokens.

## Composition and residency

```text
shell.qml
  -> modules/iris/critical/ShellIrisCriticalPanels.qml
       -> IrisBar
       -> IrisBackground            (when desktop widgets are disabled)
  -> ShellIrisPanels.qml
       -> modules/iris/ShellIrisPanelsImpl.qml
            -> IrisDock             (deferred, if enabled)
            -> shared Background    (deferred, if desktop widgets are enabled)
            -> transient/on-demand iRiS surfaces
```

The Apple direction is allowed to be richer than the original ultra-light iRiS experiment, but
cost must stay explicit. Enabling the shared desktop widget canvas can instantiate providers used
by those widgets; that is a deliberate tradeoff, not a reason to make every iRiS surface resident.

Palette, Control Center, Session and other user-action surfaces should still unload after close.
Disabled features must not keep timers, subprocesses, media decoders or large visual trees alive.

## Bar modules and extensibility

The classic bar and expanded Island share the existing three logical slots:

```text
bar.left    bar.center    bar.right
```

Built-ins are `brand`, `workspaces`, `activeWindow`, `status`, `clock`, and `controls`.
`iris.bar.{leftModules,centerModules,rightModules}` owns placement/order.

Custom modules continue to use `custom:<widget-id>` and the existing `CustomWidgets` discovery
service. User components should consume `IrisStyle` and `qs.modules.iris.components`, keep a small
implicit size, accept `targetScreen`/`irisSlot` where useful, and fail locally.

The user-facing extension contract lives in `defaults/widgets/IRIS-SDK.md`.

## Multi-output contract

- Bar, Island and Dock are per-output surfaces.
- `iris.bar.screenList` controls where the bar/Island appears; an empty list means all outputs.
- Singular transient surfaces follow `GlobalStates.focusedScreen`.
- Island IPC expansion targets the focused output.
- Lock and Session remain session-wide and must not assume screen index zero.
- Shared desktop widgets retain the existing Background multi-output ownership model.

## Configuration contract

`modules/settings/IrisConfig.qml` owns iRiS-specific settings.

Current top-level iRiS configuration:

```text
iris.appearance.design        island | classic
iris.appearance.density
iris.appearance.radius
iris.appearance.motion
iris.bar.*
iris.dock.enable
iris.dock.autoHide
iris.dock.iconSize
iris.modules.desktopWidgets
iris.modules.*
iris.palette.*
iris.controlCenter.*
iris.notifications.*
iris.osd.*
```

Existing installs are not migrated into iRiS automatically. Material II remains the fresh-install
family unless product policy explicitly changes.

## IPC

The iRiS bar exposes:

```bash
inir iris open
inir iris close
inir iris design island
inir iris design classic
```

`docs/IPC.md` and the generated IPC registry must stay synchronized whenever this contract changes.

## Acceptance for this baseline

Before treating an iRiS Apple change as a stable checkpoint:

- iRiS cold-starts without QML/type/binding/loader errors;
- Island opens/closes through IPC and only expands on the focused output;
- Dock loads when enabled and does not steal keyboard focus while idle;
- desktop widgets use iRiS tokens in Island mode and are absent when disabled;
- Palette, Controls and Session open/close without leaving stale layer surfaces;
- `classic` remains selectable without breaking the family;
- direct/cycled family switches do not leave stale iRiS layers;
- Settings exposes the options actually consumed by runtime;
- `git diff --check`, IPC registry freshness and local distribution tests pass;
- performance/residency changes are measured when a new persistent provider or visual tree is
  introduced.
