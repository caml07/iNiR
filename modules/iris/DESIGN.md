# iRiS — Design Contract

iRiS is iNiR's Apple-inspired shell family and its next flagship. It is a separate product
language: not a Material II theme, not a Waffle variant. `island` is the default design;
`classic` remains the alternate compact-bar design and must keep working.

This document is the contract for iRiS presentation and interaction. Read `AGENTS.md` in this
directory for the working method (render → capture → inspect loop) before changing anything here.

## 1. Product principles

1. **One object, many shapes.** The Island is the origin of the system. Surfaces the user opens
   from it (Control Center, Settings, Spotlight) grow out of the exact shape that opened them and
   collapse back into what the Island looks like when they close. Only one shape is ever on screen.
2. **Wallpaper-first.** Chrome frames the desktop. No full-screen dimming except where the task
   demands attention (Session, Lock).
3. **Glanceable, then deep.** Compact states answer "what's happening" in one look; expanded
   states offer the next action without another window.
4. **Direct motion.** Fast, front-loaded, with a short settle. No bounce except launch feedback.
   Reversing mid-flight stays one coherent shape.
5. **Truthful controls.** Every visible option drives a real runtime consumer. No speculative knobs.
6. **Reuse iNiR.** Services, models and providers are shared; iRiS owns presentation only.
7. **Family isolation.** iRiS adaptations of shared code are gated on the active family
   (`panelFamily === "iris"` and, where relevant, `IrisStyle.island`). Material II and Waffle must
   render byte-for-byte the same when iRiS is not active.

## 2. Visual grammar

### Palette (owned by `IrisStyle.qml`)

```text
surface             #000000   Island, Dock, panels
surface high        #1c1c1e   grouped cards, sidebars, widget plates
surface highest     #2c2c2e   raised tiles, launcher tile
text                #f5f5f7
secondary text      #aeaeb2
muted text          #8e8e93
accent              #a8c7fa   selection, on-state switches, sliders
secondary accent    #ff9f0a   timers
danger              #ff6961   recording, destructive confirmation, badges
hairline            #262628
strong hairline     #48484a
```

Consumers use tokens, never literals. Two documented exceptions: Settings section badges use a
fixed category tint per section, and Lock/Session text over wallpaper uses pure white with alpha.

Translucent fills inside black surfaces are expressed as `applyAlpha(text, n)`:
`0.07` quiet tile, `0.10–0.14` control track / resting disc, `0.20–0.26` hover / selected segment.
Keyboard/list selection inside Spotlight and Settings uses `applyAlpha(accent, 0.20–0.22)`.

### Shape

| Element | Radius |
| --- | --- |
| Compact Island, satellites, capsule controls, chips | height / 2 |
| Expanded Island | `max(IrisStyle.radius, 30·d)` |
| Control Center, Settings frame | `30·d` |
| Spotlight | `26·d` |
| Desktop widget plates | `22·d` |
| Grouped cards (Settings), status tiles | `14–16·d` |
| Sidebar rows, dock menu rows | `10–12·d` |
| App-icon-like tiles (dock launcher) | `26 %` of the tile |

No nested cards: a card inside a black surface is a `surface high` or `text@0.07` fill, never a
second bordered container. Separators are 1px hairlines inset to the text column.

### Typography

`IrisStyle.fontMain` (Noto Sans unless the user sets `iris.appearance.fontFamily`). Numbers use
tabular figures (`font.features: { "tnum": 1 }`). Sentence case everywhere — no uppercase
eyebrows or letter-spaced labels in Island design (Classic may keep them). Scale follows the
shell typography scale (`IrisStyle.typeScale`); density scales geometry only.

| Role | Size |
| --- | --- |
| Lock clock | 112 |
| Session clock | 64 |
| Desktop page clock | 36 |
| Page title (Settings) | 21 bold |
| Spotlight field | 21 |
| Body / row label | 13–13.5 |
| Metadata / section header | 11.5–12, muted, demibold for headers |

### Icons

`MaterialSymbol` is the glyph engine; filled for state, outline for affordance. App identity
always uses `SmartAppIcon`. Glyph badges are plain circles — never Material expressive shapes.

## 3. Motion

- **Curve:** `IrisStyle.morphCurve` = `cubic-bezier(0.16, 1, 0.3, 1)`.
- **Durations:** morph `iris.appearance.motionDuration` (default 220 ms); surface morph ×1.35;
  feedback 100 ms; hover/colour 110–140 ms; content cross-fades 150–160 ms.
- `IrisStyle.duration()` gates everything so the global animation policy and the iRiS motion
  switch are respected.
- One geometry animation per transition. Never animate width, height, radius, scale and opacity
  independently to fake richness.
- Idle UI has no decorative animation. Waveform, recording pulse and similar only run while that
  state is real and visible.

### Morph surfaces (`IrisMorphSurface`)

- One `presentation` value (0→1) interpolates a clipping chassis from the origin rect to the
  surface's resting rect. Content fades in after 35 % and scales from 0.965.
- Origins: `GlobalStates.irisMorphOrigin` (published by the Island), or `originItem` (Dock icon).
- The Island publishes **on open and on close**; the surface re-captures on close so it collapses
  into the Island's current shape.
- `GlobalStates.irisMorphHandoff` is true while an Island-origin morph is in flight; the Island
  hides the published part (chassis or controls satellite) on that frame and fades back in after.
- The chassis is visible from the open request (so fields can take focus) but transparent until
  armed (so the fallback rect never paints).
- Layer surfaces never resize per frame: windows are stable canvases, input is limited by `mask`.

## 4. Layer-shell rules (hard-won)

- **Never change a surface's anchors at runtime to catch outside clicks.** A layer anchored to two
  opposite edges loses its exclusive zone and every tiled window resizes.
- **Never switch a live surface's layer to get above something.** The surface is recreated and its
  content flashes (menus "open and close"). Outside-click dismissal uses a transparent full-screen
  `*-dismiss` layer (`ExclusionMode.Ignore`, Top) that is declared and mapped *before* its owner,
  stays mapped, and only enables input through its `mask` while needed — so it always stacks
  below the owner on the same layer.
- Items that accept hover block `HoverHandler`s on **sibling** items beneath them. Track pointer
  presence with a handler on a common ancestor (window content) and let the input mask decide
  where it counts.
- `forceActiveFocus()` is ignored on invisible subtrees and inside unfocused `Loader` scopes.
  Give loaders `focus: true` and re-claim focus when a morph settles.
- Escape is handled with a window-level `Shortcut`, never only in a child's `Keys` handler.
- Content that scales up (Dock magnification) is rasterised at its largest size and scaled down at
  rest; scaling a small bitmap up pixelates it.
- A blur that fills a clipped surface is drawn past its bounds (overscan) so its transparent,
  darkened edges never show as rims.

## 5. Surfaces

### Island (`bar/IrisIsland.qml`)

One black `ClippingRectangle` chassis owns the silhouette; everything is clipped by it.

- **Live activities**, prioritised `record > timer > media`. The primary fills the chassis; a
  second detaches as a satellite that slides out from behind the edge.
- **Compositions:** Unified (one chassis) or Cluster (clock chassis + activity satellite + controls
  satellite).
- **Feedback HUD:** volume/brightness/mic morph into glyph + level capsule + value.
- **Expanded pages** with a shared nav row (media · activities · desktop | Control Center · Settings):
  - *Now playing*: cover, title/artist, tinted waveform, scrubber with elapsed/remaining,
    transport, full-chassis blurred artwork.
  - *Live activities*: recording (stop) and timer (pause/resume/stop) rows.
  - *Desktop*: clock + date + weather (when enabled), workspace page dots for this output
    (click to switch), focused app card (read from the workspace's last-focused window because a
    pinned Island holds keyboard focus), status tiles (network, sound, Bluetooth, battery when
    present — each opens Control Center), and any `custom:` bar modules.
- **Interaction:** intent hover (pointer settles ≤6 px for `iris.bar.hoverDelay`), never opens a
  panel by hover; any press inside pins; pinned closes on outside click (dismiss layer) or Escape;
  middle click toggles playback; scroll adjusts volume/brightness (Shift swaps).
- **Fullscreen:** resting Island fades out and releases input; HUD and explicit opens appear on
  Overlay.
- **Notch:** chassis overflows the edge by its radius plus concave fillets; no per-corner radii.
- Hover preloads Control Center; expansion preloads Settings.

### Dock (`dock/IrisDock.qml`)

- Centred on the edge opposite the Island; stable anchors and exclusive zone while visible.
- **Visibility:** always visible, or auto-hide with reveal-by-intent (edge held ~110 ms, hide
  ~420 ms after leaving). `iris.dock.revealOnEmpty` keeps it shown on an empty workspace.
- **Pointer tracking** lives on the window content; the input region grows to include magnified
  icons while hovered so the pointer never falls off an enlarged icon.
- **Icons:** launcher is an app-icon-shaped tile (not a bare glyph) and magnifies like apps;
  cosine magnification pushes neighbours; name bubble rides above the hovered icon including its
  magnification; running dot (brighter when focused); pinned/running separator; notification
  badge (`iris.dock.badges`); launch bounce.
- **Actions:** click activates/cycles, middle click opens a new window, scroll cycles an app's
  windows, right click morphs a menu out of the icon (windows, New window, Keep/Unpin, Close).
  Each button's hit area grows upward with its magnified icon.
- **Icons** are rasterised at the magnified size (`iconOversample`) and scaled down at rest.
- **Menu:** the canvas permanently reserves menu space (no resize on open); magnification freezes
  where it was at the right click so the icon and menu stay aligned; an always-mapped dismiss layer
  below the dock catches outside clicks.
- Notch mode flattens the edge side; blur is optional and off by default.

### Spotlight (`palette/IrisPalette.qml`)

- Morphs out of the Island into a floating capsule at 20 % screen height; results extend it
  downward with an animated height. No scrim.
- Borderless field (search glyph + 21 px input) — never a box inside the box.
- **Empty query:** Suggestions row (Dock apps: pinned then running, running dot) and search-mode
  chips that type their prefix (clipboard, calculator, actions, emoji, web, command).
- **Query:** "Top hit" (large row with description) followed by grouped sections; sliding accent
  selection; the selected row shows its verb and ↵. Calculator fallback only for numeric queries.
- **Clipboard mode** (query starts with the clipboard prefix; `Super+V` opens it): "Clipboard
  history" list, image entries show decoded thumbnails (`CliphistImage`) with dimensions, Enter
  copies, Delete removes the selected entry; history refreshes when the mode opens.
- **Keys:** ↑/↓/Tab move (←/→ in suggestions), Enter runs, Escape clears then closes.

### Control Center (`control/IrisQuickPanel.qml`)

Grows from the controls satellite (Cluster) or chassis (Unified). Header with date and
Lock/Settings/Power; connectivity discs; now-playing card; capsule sliders with output picker;
quick tiles; notifications grouped by app.

### Settings (`settings/IrisSettings.qml`, `IrisSetting.qml`)

- macOS-style two-pane window morphing out of the Island.
- **Sidebar** (`surface high`): search capsule, sections with tinted rounded-square badges, iRiS
  identity footer.
- **Content:** large title + subtitle, then grouped cards. Rows put the label (and optional
  description) left and the control right: switch (accent track, white knob), inline segmented
  control for ≤3 short choices, value + full-width slider for ranges. Wider choices wrap below.
- The Island section starts with a live miniature preview that follows composition, edge, notch,
  height, gap and Dock options with the morph curve.
- Search spans all sections and groups results by section. Page changes slide in 10 px.
- Keys: Escape clears search → leaves an advanced page → closes; Ctrl+F focuses search.
- "All Settings" lists the shared iNiR pages as chevron rows.

### Session (`session/IrisSessionScreen.qml`)

Dimmed desktop (black 58 %), large clock and long date, one row of 76 px discs with labels:
Sleep, Restart, Shut Down, Lock, Log Out. Restart/Shut Down/Log Out arm on first press (disc turns
danger, label "Confirm", hint line explains) and expire after 5 s. ←/→/Tab move a visible focus
ring, Enter/Space activates, Escape cancels the armed action then closes, clicking outside closes.

### Lock (`lock/IrisLockSurface.qml`)

Blurred wallpaper (MultiEffect, desaturated, respects `lock.blur.enable`) with a top/bottom
gradient; date over a 112 px clock; now-playing card only while media plays; avatar (user avatar
paths with initial fallback), display name, password capsule with submit arrow, shake on failure,
status line. PAM/context behaviour is shared and untouched.

### Notifications (`notificationPopup/IrisNotificationPopup.qml`)

Island design shows banners centred under the Island, newest first, up to three:

- black plate, `22·d` radius, critical urgency adds a danger hairline;
- artwork: notification image with the app icon as a corner badge, the app icon alone, or a quiet
  glyph disc when the sender has no resolvable icon (never the missing-icon texture);
- summary + relative time ("now", "5m"), body (2 lines, 8 on hover), app name, action capsules;
- drop in from the Island (morph curve, short travel, slight scale);
- click runs the default action or focuses the sender's window; hover cancels the timeout and shows
  a close button; horizontal swipe past 30 % dismisses;
- the window's input mask covers only the banners.

Classic keeps its compact right-aligned cards.

### Overview backdrop

On Niri, iRiS loads the shared iNiR `Background/Backdrop.qml` (namespace `quickshell:iiBackdrop`,
placed within Niri's overview backdrop by the shipped layer rule) when `background.backdrop.enable`
is on. Settings › Desktop exposes enable, blur, dim and vignette.

### Other transient surfaces

OSD fallback, Polkit and Close Confirm follow the same grammar: black surface, grouped content
without nested cards, sentence case, disciplined radii, visible keyboard focus. Polkit and Close
Confirm still use the earlier card composition and are the next alert-style pass.

### Desktop widgets

The shared `Background` canvas hosts widgets; iRiS adapts presentation centrally:

- `WidgetSurface`: black plate, `22·d` radius, no glass.
- `AbstractBackgroundWidget.widgetSemanticSet()`: iRiS tokens for roles; card radius `22·d`,
  control radius `12·d`, title family `IrisStyle.fontMain`.
- Per-widget, gated on `widgetIris`: plain circular glyph badges and Noto numerals (System
  Monitor); mixed-case labels instead of forced uppercase (Uptime, Day Progress, Battery, Timers,
  Weather, Date Badge, World Clock); native iRiS media player for full/compact presets.
- User-chosen widget shapes/styles stay the user's choice.
- `iris.modules.desktopWidgets = false` unloads the canvas and its providers.

## 6. Composition and residency

```text
shell.qml
  -> modules/iris/critical/ShellIrisCriticalPanels.qml
       -> IrisBar (+ dismiss layer while pinned)
       -> IrisBackground            (when desktop widgets are disabled)
  -> ShellIrisPanels.qml -> modules/iris/ShellIrisPanelsImpl.qml
       -> IrisDock (+ dismiss layer) (deferred, if enabled)
       -> Background/Backdrop       (deferred, Niri, if background.backdrop.enable)
       -> Background                (deferred, if desktop widgets are enabled)
       -> on-demand: Spotlight, Control Center, Settings, Session, notifications
       -> Lock, Polkit              (deferred)
```

On-demand morph surfaces keep a close grace of `morphDuration × 1.35 + 120 ms` so the collapse is
never cut. Disabled features must not keep timers, processes, decoders or visual trees alive.

## 7. Configuration

`modules/common/Config.qml` (schema) + `defaults/config.json` (fresh installs) +
`modules/iris/settings/IrisSettings.qml` (UI). Current keys:

```text
iris.appearance.design        island | classic
iris.appearance.expandedRadius, motion, motionDuration, density, radius, fontFamily, titleFontFamily
iris.bar.position, composition, notch, height, margin, reserveSpace,
         hoverExpand, hoverDelay, scrollAction, screenList, left/center/rightModules
iris.dock.enable, autoHide, revealOnEmpty, notch, blur, iconSize, magnification, badges
iris.player.roundCover, artworkBackground
iris.palette.width, maxResults, showHints
iris.controlCenter.width
iris.modules.desktopWidgets, palette, controlCenter, notificationPopup, osd, sessionScreen, lock, polkit
```

New defaults apply to fresh installs; no migrations unless explicitly requested.

## 8. Bar modules and extensibility

Built-ins: `brand`, `workspaces`, `activeWindow`, `status`, `clock`, `controls` (Classic bar).
`custom:<widget-id>` modules use `CustomWidgets` discovery and also appear on the Island's Desktop
page. User components consume `IrisStyle` and `qs.modules.iris.components`
(see `defaults/widgets/IRIS-SDK.md`).

## 9. Multi-output

Bar, Island and Dock are per-output. Singular surfaces follow `GlobalStates.focusedScreen`; only
the focused output publishes morph origins. Lock and Session are session-wide.

## 10. IPC

```bash
inir iris open | close
inir iris design island|classic
```

`docs/IPC.md` and the generated registry stay in sync with this contract.

## 11. Acceptance

A change to iRiS is acceptable only when:

- it cold-starts without QML/type/binding/loader warnings (`inir logs`);
- the affected surface was exercised in the real runtime and inspected from a `grim` capture —
  for motion, intermediate frames were captured;
- Escape and outside click close every transient surface it touches;
- pinning the Island or opening a Dock menu does not change tiled window geometry
  (`niri msg -j windows`);
- Classic, Material II and Waffle are unaffected;
- every Settings row still drives a real consumer;
- anything that needs pointer or keyboard input the agent must not inject is listed as untested.
