# iRiS — Design Contract

iRiS is iNiR's Island family and its next flagship. It is a separate product language: not a
Material II theme, not a Waffle variant, and not a replica of anyone else's system. It borrows
*principles* from Apple's Dynamic Island guidance (§1a) and nothing else: no vendor logos,
glyphs, wording or trade dress. The family's own insignia is `IrisMark` (iris ring, pupil and
orange satellite); wherever the shell identifies itself — Settings footer, the shell's own
notifications — it uses that mark. The Island is the only design: the early compact-bar
"Classic" design and its variants of every surface were removed.
`IrisStyle.island` stays a constant `true` only so SDK modules written against it keep loading.

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

## 1a. Direction: Dynamic Island fidelity

The reference for every iRiS decision from here on is Apple's *Design dynamic Live Activities*
(WWDC23, session 10194), adapted to a desktop shell on Niri. These are rules, not inspiration:

**Fit and shape**
- **Concentric or nothing.** A shape placed near a rounded perimeter nests with an even margin
  all the way round: `inner radius = outer radius − inset` (floor 6·d). Non-round content is
  placed by its visual mass — if a blurred copy would not sit concentric, move it.
- **Keep off the corners.** Content keeps a concentric margin from the perimeter; push it inward
  or round its container. Separate blocks with an inset shape or a hairline, never a fill drawn to
  the chassis edge (the only exception is material that bleeds *and* melts back into the surface at
  the attached edge: wallpaper hero, artwork vibrancy).
- **No forehead.** Attached (notch) surfaces hug their edge; nothing reserves empty height at the
  attached side to "make room" for the edge.
- **Extra-rounded, thick, legible.** Heavier shapes, large easy-to-read figures, tabular numerals.

**Size classes**
- The Island has three classes: *minimal* (satellite bubbles when activities compete), *compact*
  (as narrow as its content, no wasted width; shorten units before growing) and *expanded* (the
  essence of the activity plus its essential controls — a tiny version of the app).
- Keep relative placement between compact and expanded: what sits leading/trailing in compact
  stays leading/trailing when it blooms.
- Heights are dynamic: surfaces hug their content and change height as information comes and
  goes (side panels hug their sections; the configured height is a ceiling). Avoid heights that sit
  ambiguously between a pill and a tall card.
- Minimal is never just a logo; it keeps conveying state (progress ring, record dot, timer glyph).

**Identity and colour**
- Each activity looks and moves distinctly while belonging to one family. Colour carries identity:
  artwork tint for media, the highlight (orange unless `iris.appearance.highlight` picks yellow, red, pink, green or the accent) for timers, red for recording, category tints for sections and
  notification tiles. Colours do not change between light and dark contexts.
- Controls only where they operate something essential; information wins the space otherwise.

**Motion**
- The Island is organic: surfaces grow out of the part that opened them and collapse back into
  it; side panels slide out of their own edge; menus grow from the icon.
- Numbers that change count (numeric transition, `IrisNumber`: only the changed characters roll,
  up for growing values, down for countdowns); replaced content cross-fades with a small scale
  (content replace). When list rows move, animate only the moving row; fade the rest.
- Updates that need attention *expand the Island* (or drop a banner out of it) instead of appearing
  somewhere unrelated; the expanded state emphasises what caused it.
- Transient states leave on their own: ended activities and feedback retire quickly.

**Layering**
- The Island floats above apps as its own layer; other surfaces never point at it or depend on
  stacking order to receive input (see §4).

Every change is judged against this section, the rendered surface and the anti-patterns in
`AGENTS.md`.

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

The system accent is selectable in Appearance: Blue (default), Mint, Rose, Lilac or Wallpaper.
Accent containers derive from it; text on the accent remains dark. The accent marks what is
selected or on, never decoration: `IrisButton` selection (`accent@0.20`, accent foreground), the
Island's current page, active workspace dot and on-state status discs, the Dock's focused-app
capsule, keyboard focus rings (Session, tray), sliders and switches. Activity colours (timer,
recording, success) retain their identity. Widgets in iRiS colour mode follow the system accent;
Wallpaper mode uses the same shared legibility transform.

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

Three voices, each a user choice in Appearance → Typography (only faces iNiR ships):
`IrisStyle.fontMain` for text (Noto Sans), `fontTitle` for titles (Readex Pro) and
`fontNumbers` for figures — clocks, timers, levels, counts (Rubik, rounded like a Live Activity's
numbers). `figureWeight` (light/regular/bold) sets `IrisClock`. Typeface choices render in the face
they name; colour choices carry a swatch. Numbers use
tabular figures (`font.features: { "tnum": 1 }`). Sentence case everywhere — no uppercase
eyebrows or letter-spaced labels.

**Accents.** Hierarchy comes from contrast inside one line, not from more lines:
- Time is `IrisClock`: heavy tabular hours/minutes, the separator in `secondaryAccent`, seconds
  and AM/PM at ~58 % size and 55 % alpha. Use it wherever the shell shows the clock as a figure.
- Dates put the accent on the part that is glanced: compact `DateMark` (weekday muted, day number
  orange); the Desktop hero leads with the weekday in orange over the figure.
- Metrics set their unit small and quiet (`50` + `%`, `12` + `°C`); status tiles are glyph,
  muted label, bold value.
- Spotlight emphasises the matched part of each result name and dims the rest; a calculator top
  hit is a 28 px figure with an orange `=`; mode prefixes are accent keycaps. Scale follows the
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
- **Settle and hop:** geometry that opens or closes a shape (Island expand/collapse, morph surfaces,
  side panels, desktop menu) runs `settleDuration` = morph ×1.8 on the same front-loaded curve, so the
  extra time is only the liquid tail. Changing between shapes already open (page switches, sections
  resizing) *hops* on the plain morph duration. On-demand close graces follow `settleDuration`.
- **Durations:** morph `iris.appearance.motionDuration` (default 220 ms);
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
  Handing off the chassis fades the whole Island, never the chassis item: an opacity animated on
  the clipping chassis left it and the notch unpainted after hand-offs.
- The chassis is visible from the open request (so fields can take focus) but transparent until
  armed (so the fallback rect never paints).
- Layer surfaces never resize per frame: windows are stable canvases, input is limited by `mask`.
- The chassis snaps to whole pixels in scene space: a clipping chassis draws its content through a
  texture, and a half-pixel offset or size resamples it soft (text, glyphs and edges blur).

## 4. Layer-shell rules (hard-won)

- **Never change a surface's anchors at runtime to catch outside clicks.** A layer anchored to two
  opposite edges loses its exclusive zone and every tiled window resizes.
- **Dismiss layers never rely on stacking order.** Niri has been observed mapping an owner
  *before* its `*-dismiss` layer, which puts the catch-all above it. The catch-all region
  subtracts the owner's geometry (Island; Dock hit area and menu) so pointer and hover over the
  owner always reach it.
- **Full-screen canvases catch outside clicks only while presented.** Overlay surfaces
  (Control Center, Spotlight, Settings, side panels) set `mask` to the whole output only when the
  morph is open *and armed*; while loading, arming or collapsing the mask is the surface itself,
  so an invisible canvas can never swallow the desktop's pointer and hover. Strip surfaces (OSD)
  always mask to their plate.
- **Never re-anchor a live surface to move it to another edge** (Dock following the Island): unload
  it and load it again on the new edge in a later event-loop turn. A `Timer` declared inside a
  `LazyLoader` is taken as its component and never exists.
- **Never switch a live surface's layer to get above something.** The surface is recreated and its
  content flashes (menus "open and close"). Outside-click dismissal uses a transparent full-screen
  `*-dismiss` layer (`ExclusionMode.Ignore`, Top) that is declared and mapped *before* its owner,
  stays mapped, and only enables input through its `mask` while needed — so it always stacks
  below the owner on the same layer.
- **A surface in use never moves its controls out from under the pointer.** A size change caused by
  interacting with it (page switch, customizing, a section growing) keeps the part the pointer is
  on in place and reshapes the far side; realignment waits until the pointer really leaves.
  Controls that change a surface's height live on its fixed edge. Input regions keep what the
  surface covered under a still pointer until the pointer moves (Island canvas, side panel zone).
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

- **Live activities**, prioritised `record > timer > media`. A paused cover dims under a pause glyph in its
  satellite and stays: it is the way into the player page, which lists the other players (paused
  ones too; a chip hands the page to that player) and each app's level (slider + mute, up to four). Finished timers, Pomodoro phase changes and stopped
  recordings take the event shape (below). The primary fills the chassis; a
  second detaches as a satellite that slides out from behind the edge.
- **Compositions:** Unified (one chassis) or Cluster (clock chassis + activity satellite + controls
  satellite).
- **Feedback HUD:** volume/brightness/mic morph into glyph + level capsule + value.
- **Badges:** Caps Lock and keyboard layout never take the Island over: a small black pill (glyph +
  short text) drops out from behind its far edge, centred, for 1.6 s.
- **Open / close:** the two layers never show through each other. Opening clears the compact
  content first (70 ms) and fades the page in after a 70 ms hold; closing clears the page, and the
  compact content and satellites wait 30 % of the settle until the chassis is nearly resting.
  **Shared parts** travel instead of fading: the cover (satellite or compact row ↔ player) and the
  clock (resting ↔ Desktop hero) fly as one live copy on the chassis curve, following the moving
  destination every frame; both real parts hide while it flies, and page switches never fly.
- **System events** (`iris.bar.events`): charger plugged/unplugged (level, time to full/empty), low
  battery, a Bluetooth device connecting (battery when known) or disconnecting, Do Not Disturb, a finished countdown, a Pomodoro phase change and a stopped
  recording (its length) take the resting shape
  for 2.6 s: identity-coloured glyph disc concentric with the capsule, title, detail, and a level
  figure + ring when the event has one. Priority below the HUD, above desktop editing. Silent for the
  first 4 s after load, on other outputs and over fullscreen. The keyboard daemon is only referenced
  while events are on.
- **Expanded pages** with a shared nav row (media · activities · desktop | Control Center · Settings)
  on the attached edge (under the notch for a top Island, at the bottom for a bottom one): pages
  hug their content and grow away from it, so switching pages never moves the row under the pointer.
  On the Desktop page the hero bleeds up behind the row, which stays on the black part of the melt.
  Switching pages is a content replace on the chassis morph: the old page clears in 80 ms, the new
  one fades in 50 ms later from 97 % scale; material that bleeds to the chassis edges (wallpaper
  hero, artwork vibrancy) only fades, never scales or moves.
  - *Now playing*: cover, title/artist, waveform and scrubber in the artwork tint (plain text
    for greyscale covers, as is the compact progress hairline), elapsed/remaining,
    transport, full-chassis blurred artwork.
  - *Live activities*: recording (stop) and timer (pause/resume/stop) rows.
  - *Desktop*: a hero with clock, date and weather over this output's wallpaper
    (`iris.bar.desktopBanner`; the image bleeds to the chassis edges, melts into the black body
    and starts in black under a notch so the fillets stay continuous); a profile row with the
    avatar (click to choose a picture through AccountsService — the same `set-avatar.sh` path as
    Material — hover shows an edit mark), `user@distro · uptime`, Lock and Session
    (`iris.bar.desktopProfile`); one context row — the workspace's active app (read from the
    workspace's last-focused window because a pinned Island holds keyboard focus) as icon, title
    and `app · workspace`, with this output's workspaces as page dots trailing (click to switch);
    one inset vitals strip — CPU, memory, heat and disk as small rings with bold figures (danger past
  each warning level; sensors kept alive only while the page is on screen); and any `custom:` bar modules.
- **Resting clock** (`iris.bar.clockStyle`): time, date + time, or weather + time, in both
  Unified (idle) and Cluster. **Trailing bubble** (`iris.bar.trailing`, Cluster): controls (opens
  Control Center), notifications (bell + count, opens Today, hides when empty), weather (opens the
  Desktop page), sound or microphone (level ring + state glyph; the wheel adjusts that level without
  the HUD retiring the bubble, click mutes, a muted microphone is red) or none. The utility
  satellite offers the same Sound and Microphone bubbles.
- **Static scene inside the chassis:** the clipping chassis has stopped painting its children after
  live structural changes inside it (opacity animated on the chassis, layers toggled on and off,
  clip or visibility toggled per frame). Content inside it changes by opacity, position and text,
  with `clip`/`layer` fixed; figures that count (`IrisNumber`) keep `clip` on and only fade.
- **Press feedback:** the resting content dips to 93 % under the pointer; satellites dip to 88 %.
  Never transform the clipping chassis itself — a live `scale` on the `ClippingRectangle` has left
  it unpainted while satellites and fillets stayed on screen.
- **Interaction:** intent hover (pointer settles ≤6 px for `iris.bar.hoverDelay`) only peeks the
  Desktop page — the player and live activities open on click, since the wheel adjusts them; never
  opens a panel by hover; scrolling over a peeking (unpinned) Island folds it into the level HUD;
  Ctrl+scroll adjusts the microphone; any press inside pins; pinned closes on outside click (dismiss layer) or Escape;
  middle click toggles playback; scroll adjusts volume/brightness (Shift swaps).
- **Fullscreen:** resting Island fades out and releases input; HUD and explicit opens appear on
  Overlay.
- **Notch:** the chassis overflows the edge by its radius; body and concave fillets are painted
  by **one** `Shape` path (the clipping chassis paints the same opaque black on top — a
  transparent `ClippingRectangle` hanging past the top edge stopped painting its children) and
  the fillet radius is bound to
  the animated chassis radius (×0.62), so the join grows with the morph. Separate corner items
  read as a different component (different size, snap, antialiasing seam). Anything painted inside
  the chassis (wallpaper hero, artwork vibrancy) is solid `surface` across the off-screen overflow
  plus the fillet height, so the vibrancy never meets the fillets at a seam.
- **Edge changes** recycle the bar surface (unload, remap on the new edge a turn later), like the
  Dock; the Island reads its edge from the bar window that owns it, not from the live option.
- **Desktop editing** (`GlobalStates.widgetEditMode`) is a modal live state on the focused
  output: the resting shape becomes accent pencil · "Editing desktop" · **Done**, and a click ends
  editing. A resting shape that is itself an action must not expand on intent hover, or it moves
  out from under the pointer before the click lands — hover-expand is suppressed while editing.
- Hover preloads Control Center; expansion preloads Settings.

### Media bubble card (`bubbles/IrisMediaBubbleCard.qml`)

In Cluster, the media bubble can float out as a card instead of expanding the Island
(`iris.player.bubbleOpens`: `card` | `island`). The Island publishes the bubble's screen-local rect
(`GlobalStates.irisMediaBubble`, only once the bubble has fully emerged); the card morphs out of that
rect, grows away from the Island with its top edge level with the bubble, and collapses back into
it. While the card is on screen the bubble hides (`GlobalStates.irisMediaCardShown`), so only one
shape exists. Content is `IrisMediaCard` over the artwork vibrancy, with a *keep* toggle and *open in
the Island* (the player page with other players and app levels).

- Opened from the bubble it is transient: outside click, Escape, or the Island expanding closes it
  (Exclusive keyboard, full-output mask only while presented and armed).
- Pinned (`iris.player.cardPinned`) it stays while a player is active, yields all input but its own,
  and tucks into its bubble while the Island is expanded.
- `inir iris card open|close|toggle|pin
inir iris bubble left|right|utility|weather|notifications|controls|sound|mic|tools|media|tray \
          island|off|top-left|top-right|left|right|bottom-left|bottom-right|x,y
inir iris settings bar|player|bubbles|dock|appearance|desktop|sidebars|surfaces|system`.

### Bubbles off the Island (`bubbles/IrisBubbleLayer.qml`)

A bubble is one black disc with the minimal presentation of its kind (`IrisBubbleFace`), wherever
it lives. The Island's three bubble slots — `left` (Cluster activity), `right` (Cluster trailing
bubble or Unified secondary activity) and `utility` — can be carried off it.

- **Carry:** holding a bubble (or pulling it away) lifts it (`IrisBubbleGrip`); the press keeps its
  implicit grab, so `GlobalStates.irisBubbleDrag` follows the pointer past the Island's canvas. The
  bubble layer draws the lifted bubble (12 % larger, deeper shadow) and quiet rings on the places it
  can land; the ring under it answers in the accent.
- **Land:** near its slot on the resting Island it glides back in and the Island's satellite takes
  over on the same frame (the carried bubble hides it until then); near a corner or edge zone
  (`top-left`, `top-right`, `left`, `right`, `bottom-left`, `bottom-right`) it snaps there; anywhere
  else it stays free (centre as fractions of the output). Placement persists per slot in
  `iris.bubbles.<slot>.place` (`island`, a zone or `free` with `fx`/`fy`); `iris.bubbles.snap` turns
  zone snapping off and `iris.bubbles.edgeGap` sets how far floating bubbles rest from the edges
  (the top row also keeps clear of the Island's band). Settings › Bubbles exposes all of it.
- **Floating bubbles** rest on a per-output Top layer (`quickshell:iris-bubbles`, mapped only while
  something floats or is carried, input masked to one fixed item per slot — a slot that is not
  floating has no size, so the surface never covers the desktop — never the keyboard) with a soft
  shadow. Tapping does what the bubble does on the Island; surfaces grow out of the floating bubble
  where they can (media card, Control Center), and the media card grows away from the nearest screen
  edge. The Island closes the gap a floating bubble leaves.
- Each Island publishes its slot kinds and resting geometry per output
  (`GlobalStates.irisBubbleKinds`, `irisIslandGeometry`) for the layer.
- **Extra bubbles** (`iris.bubbles.extras.<kind>`: weather, notifications, controls, sound, mic,
  tools, media, tray) live off the Island only: each has its own switch and place, is carried like
  the slots (no Island target), and hides while it has nothing to show (media without a player, an
  empty tray). Bubbles sharing a zone line up — inward along the edge from a corner, centred on a
  side edge — in slot order, then extras.
- **Settings › Bubbles:** Placement (the three slots), Extra bubbles (a switch each; its place row
  appears while it is on, via the rows' `visibleWhen`), Floating (edge gap, snapping).
- **Carrying the Island:** holding the resting Island lifts a ghost of it; dropped on the other half
  of the screen it moves the Island to that edge (`iris.bar.position`). The Island reserves its edge,
  so it rests on an edge rather than anywhere.
- `inir iris bubble left|right|utility island|<zone>|x,y`.

### Dock (`dock/IrisDock.qml`)

- Centred on the edge opposite the Island; stable anchors and exclusive zone while visible.
- **Visibility:** always visible, or auto-hide with reveal-by-intent (edge held ~110 ms, hide
  ~420 ms after leaving). `iris.dock.revealOnEmpty` keeps it shown on an empty workspace.
- **Pointer tracking** lives on the window content; the input region grows to include magnified
  icons while hovered so the pointer never falls off an enlarged icon.
- **Plate:** black with a 1 px `text@0.13` hairline just inside the edge (off in notch and blur
  modes) so the silhouette holds over dark wallpapers.
- **Icons:** the optional Applications button (`iris.dock.launcher`) has no tile: a 3×3 grid of round dots
  on the Dock's black at an icon's footprint (a cross while Spotlight is open) and magnifies like apps; cosine magnification pushes neighbours; without
  magnification, hover is a quiet platter plus a 2 px lift; name bubble rides above the hovered icon
  including its magnification and shows the window count in orange when more than one.
- **Indicators**, one vocabulary under the icon: focused app (Niri's focused window, not the
  Wayland handle's lagging `activated`) is a capsule, each other open window a dot up to three,
  an app whose windows are all minimised a hollow ring, a window asking for attention
  (`is_urgent`) pulses orange; pinned/running separator; unread badge counted from the whole notification
  list, not live banners, without ever dismissing anything: the focused app shows none (what
  arrives while you are in it is seen), leaving an app or opening Today / Control Center marks what
  came before as seen, and notifications already present when the shell starts count as seen
  (`iris.dock.badges`);
  launch bounce.
- **Actions:** click activates/cycles, middle click opens a new window, scroll cycles an app's
  windows, right click morphs a menu out of the icon (windows, New window, Keep/Unpin, Close).
  Each button's hit area grows upward with its magnified icon.
- **Icons** are rasterised once at the magnified size (`iconOversample`) and only scaled
  (mipmapped layer); resizing a theme icon per frame re-renders and blanks it.
- **Delegates are keyed by app id** (`ScriptModel`): `TaskbarApps` rebuilds every entry on any
  window event (a title spinner, focus), and recreating delegates flashed every icon and dropped
  clicks between press and release. Live window state is read from `liveApps`, never from the
  first snapshot. Spotlight suggestions follow the same rule.
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
- **Mode token:** a recognised prefix shows its mode as an accent token at the end of the field.
- Suggestion selection is placed by index (a highlight bound to `Repeater.itemAt()` never updates).
- **Keys:** ↑/↓/Tab move (←/→ in suggestions), Enter runs, Escape clears then closes.
- **Pointer handoff:** opening Spotlight, typing or navigating by keyboard disarms result hover.
  A stationary cursor may sit over a row without changing selection; hover becomes authoritative
  only after real pointer motion, while a click always activates immediately.

### Wallpaper picker (`wallpaper/IrisWallpaperPicker.qml`)

Replaces the shared grid selector's presentation under iRiS (`GlobalStates.wallpaperSelectorOpen`;
the carousel launcher and coverflow stay shared). Morphs out of the Island and hangs under it as a
compact black strip (`28·d`), sized by `iris.wallpaper.width` and `thumbnailSize`:

- **Where:** back and forward (`FolderListModelWithHistory`, also Alt+←/→, Alt+↑ and Backspace on an
  empty search go up) and the path as breadcrumbs — quiet places under Home, the current folder in a
  capsule with its wallpaper count in orange — each a way back; a wallpaper-frame disc returns to the
  wallpapers folder when elsewhere. Wallhaven replaces the path with its title and discovery chips.
- **Search** capsule ("Search in <folder>"), the live-preview eye and shuffle (a random wallpaper
  from this folder).
- **Subfolders** as one row of folder chips above the gallery, apart from the wallpapers (the gallery
  is a `ScriptModel` of files keyed by path; the folder model is read once per settle).
- **Gallery:** two rows scrolling sideways, 16:10 tiles inside a concentric accent selection ring,
  the name melting in on hover/selection, a check badge on the applied wallpaper. The empty state
  says why (no matches, nothing here, or wallpapers living in the folders above).
- **Selection line:** name and a hint (applying, previewing, previews being prepared, or the online
  resolution), the target display as a quiet chip, Esc keycap and the only accent button, Apply.
- **Live preview** (`iris.wallpaper.livePreview`): once the selection is moved, the highlighted
  wallpaper shows on the desktop through `Wallpapers.previewWallpaper`; closing without applying
  cancels it, applying adopts it — the shared launcher's rules.

Browsing, thumbnails and applying are the shared `Wallpapers` service; Wallhaven results download into
the wallpapers folder before applying the same way. A click selects, double-click or Enter applies;
Tab/Shift+Tab switch between Library and Wallhaven; Escape clears the search, then closes. The
Island's Desktop hero has a wallpaper disc that opens it for that output.

### Control Center (`control/IrisQuickPanel.qml`)

Grows from the controls satellite (Cluster) or chassis (Unified). Toggles and levels share one row: a 3×2 grid of glyph tiles (Dark, Night light, Stay awake, Capture, Record in danger tint, Sound devices) whose names show in the header while hovered (no popup tooltips), beside three vertical capsules of the grid's height (brightness, volume, microphone; glyph at the foot mutes). Sound devices unfolds outputs then inputs. Once presented, height changes
(output picker, notifications) glide on the morph curve; hanging from a bottom bar, the header holds
under the pointer and the panel rests on its edge again once the pointer leaves. Header with date and
Lock/Settings/Power; connectivity discs; now-playing card; capsule sliders with output picker;
quick tiles; notifications grouped by app.

### Side panels (`sidebar/IrisSidebar.qml`)

Focus (left) and Today (right) use the existing `sidebarLeft` and `sidebarRight` commands.
Headers lead with identity: Today shows the day number in calendar red with weekday and month;
Focus greets the signed-in user with their avatar. Sections carry category badges (Tasks orange,
Notes yellow, Calendar red, Weather sky, Notifications pink); the weather card wears a day, night
or overcast sky gradient; notifications are inset plates. *Keep open* docks the panel: an empty
strip on its edge (`quickshell:iris-sidebar-reserve-*`) reserves the panel's width so tiled
windows make room, and the header reads "Kept open".
Focus starts with media, tasks and persistent notes; Today starts with a browsable calendar (today is always the
solid accent disc, another chosen day an accent tint),
weather and actionable notifications. The calendar adds events to the shared events store for the chosen day (title + optional 24 h time, reminded 15 min before) and removes them; synced calendars stay read-only. Both use the same iNiR services as Material.

**Sections rest compact and morph open.** Each card is a header (category badge, title, a quiet
detail such as a count or temperature, and a chevron) over a glance: Weather in one line, the week
as a strip with today's red disc and event dots, the first two open tasks, the note's title and
first lines, the latest notification, the focus timer's ring and time, the apps playing sound. A
click on the header morphs the card open in place (one height on the morph curve; the glance
clears as the full content arrives; header actions appear only while open) and remembers it in
`iris.sidebars.<side>.expanded`. While a card morphs, the panel follows its height directly
instead of animating it a second time. The media card opens from its cover and titles and folds
from its corner. Sections: Now playing, Tasks, Notes, Calendar, Weather, Notifications, Focus
timer (the shared Pomodoro), Sound mixer (per-app volume and mute) and System (CPU, memory, heat
and disk gauges; sensors only while shown). The month grid has seven equal columns with round
days; *New event* unfolds a sheet in the card — a centred name, the time on two wheels (drag,
flick or scroll; minutes in 5s; starts at the next hour), an alert choice and Cancel · Add.

Each side independently chooses its sections and order, width, height, vertical alignment and
whether it stays pinned. Customize is available from the header or Ctrl+E; Settings → Side Panels
also exposes layout and section order. Disabled panels do not load. Unpinned panels dismiss on
outside click or Escape; pinned panels yield input outside their bounds and never peek-close.
Opening Settings from a panel leaves the panel in place (a peek becomes a real open).
Once the pointer has been on a panel its top edge (the header) holds for the rest of that open, and the panel closes from there: customizing or a section
changing height moves the bottom, and size/alignment changes glide on the morph curve once it is
presented. In the editor rows keep their place when a section is switched on or off. Escape leaves the
editor before closing the panel. Opening an unpinned panel closes its unpinned counterpart.

Panels slide out of their own screen edge on one progress value, without claiming the Island's
handoff: the origin is the resting shape parked just past that edge (followed live, since a fresh
surface does not know its size yet), content travels with the chassis (`contentTravels`), and the
slide waits until the sections' layout has settled so nothing reflows mid-motion.

- **Attach to the screen edge** (`notch`): the panel overflows its edge by its radius (flat edge
  side, no per-corner radii) with concave fillets above and below that fade in as it settles.
- **Reveal on hover** (`hoverReveal`): a resident 1 px strip per enabled side (`IrisSidebarEdge`)
  opens the panel after the pointer rests ~140 ms. A peek (`GlobalStates.irisSidebarPeek`) masks
  input to the panel plus the strip to its edge, keeps keyboard on demand and closes 320 ms after
  the pointer leaves; a press inside commits it to a normal open panel.
- Notes are one sheet: title as the first line, hairline, body.
 They use stable full-output canvases with no exclusive zone and unload after collapse.
Section content remains clipped and scrollable at smaller panel sizes. The Island exposes Focus
and Today in its expanded navigation.

### Settings (`settings/IrisSettings.qml`, `IrisSetting.qml`)

- macOS-style two-pane window morphing out of the Island.
- **Guide** at the top of every section: tinted badge beside jump chips that scroll to each group,
  and one single-line tip. It never repeats the title/subtitle.
- **Sidebar** (`surface high`): search capsule, sections with tinted rounded-square badges, iRiS
  identity footer.
- **Content:** large title + subtitle, then grouped cards. Rows put the label (and optional
  description) left and the control right: switch (accent track, white knob), inline segmented
  control for ≤3 short choices, value + full-width slider for ranges. Wider choices wrap below.
- The Island section starts with a live miniature preview, over this output's wallpaper, that follows composition, edge, notch,
  height, gap and Dock options with the morph curve.
- Range rows use `IrisScrubber`: no outline (focus thickens the track and knob), a drag never
  scrolls the page (`preventStealing`), and the wheel steps the value. Every iRiS slider
  (Control Center capsules, media scrubbers) takes the wheel the same way; touchpad deltas accumulate.
- Opened from a side panel (Panel size and position), Settings grows out of that button and collapses
  back into it: the panel publishes the origin and sets `GlobalStates.irisMorphOwner`, which the
  Island respects (no overwrite, no hand-off hide) until the morph has fully collapsed.
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
gradient; date over a 112 px clock; now-playing card only while media plays; recording and timer plates (glyph disc, label, counting
figure in the activity colour, progress hairline for countdowns) while those activities run; avatar (user avatar
paths with initial fallback), display name, password capsule with submit arrow, shake on failure,
status line. PAM/context behaviour is shared and untouched.

### Notification identity (`components/IrisNotificationIcon.qml`)

Banners, Control Center and Today share one resolver: the notification image (a theme icon URL
passed as an image counts as an icon, never artwork) with the app as a corner badge → the app's
real icon (theme name, path or desktop entry) → an app-icon-shaped iRiS tile (26 % radius, tint
gradient, white filled glyph) chosen from what the notification is about (screenshot, recording,
battery, network, updates, chat, calendar, music…). The shell's own notifications always use the
tile. Tile tints are the documented fixed category palette, like Settings badges.

### Notifications (`notificationPopup/IrisNotificationPopup.qml`)

Island design shows banners centred under the Island, newest first, up to three. Banners are bubbles
of the Island: a new one arrives as its sender's icon in a disc just under the Island and blooms into
the banner (width, height and radius on one progress, the text arriving once the shape has formed);
when it times out it folds back into that disc, rises into the resting Island and melts there. A
swiped banner slides away instead. The surface is a stable canvas sized for three expanded banners
(input limited to the list by `mask`), the list is a `ListView` over a `ScriptModel` keyed by
`notificationId` (a new banner never recreates the others), and a leaving banner plays through the
view's `remove` transition while the panel's close grace keeps the surface alive.

- on screen for `iris.notifications.duration` (4 s) unless the app sets a timeout; critical keeps the
  shared policy;
- black plate, `22·d` radius, critical urgency adds a danger hairline;
- artwork: notification image with the app icon as a corner badge, the app icon alone, or a quiet
  glyph disc when the sender has no resolvable icon (never the missing-icon texture);
- summary + relative time ("now", "5m"), body (2 lines, 8 on hover), app name, action capsules;
- click runs the default action or focuses the sender's window; hover cancels the timeout and shows
  a close button; horizontal swipe past 30 % dismisses;
- the window's input mask covers only the banners.

### Overview backdrop

On Niri, iRiS loads the shared iNiR `Background/Backdrop.qml` (namespace `quickshell:iiBackdrop`,
placed within Niri's overview backdrop by the shipped layer rule) when `background.backdrop.enable`
is on. Settings › Desktop exposes enable, blur, dim and vignette.

### Other transient surfaces

OSD fallback, Polkit and Close Confirm follow the same grammar: black surface, grouped content
without nested cards, sentence case, disciplined radii, visible keyboard focus. Close Confirm is a
centred alert (app icon, question, context, Cancel · destructive Close). Polkit is the same alert:
accent lock disc, the action as the question, the message, a capsule secret field with an accent
focus rim, Cancel · Authenticate.

### Desktop widgets

The shared `Background` canvas hosts widgets; iRiS adapts presentation centrally:

- `WidgetSurface`: black plate, `22·d` radius, no glass.
- Colour (`iris.widgets.tint`): *Wallpaper* lifts the generated primary/tertiary hues into a
  range that reads on black (greyscale seeds fall back to iRiS blue/orange); *iRiS* keeps the
  system accents. Plate (`iris.widgets.material`): *Solid* black or *Tinted* (18 % wallpaper hue).
  Titles and figures (`iris.widgets.weight`): Light, Regular or Bold with −0.4 tracking.
  Instrument presentations keep mixed case under iRiS.
- Type and case tokens on `AbstractBackgroundWidget`: `widgetBodyFamily` / `widgetNumbersFamily`
  resolve to the iRiS typeface (other families keep the shell fonts); `widgetCase()` and
  `widgetCapitalization` turn Material/Instrument caps into sentence case, with metadata tracking
  removed. Monospace, expressive and reading faces stay the widget's own choice.
- Plates in *auto* colour mode are always the iRiS material (black or tinted), never a widget's own
  semantic fill; explicit light/dark modes are respected.
- Media Controls renders the native iRiS player for full, classic, compact and minimal presets;
  compact/minimal is one live-activity row (small cover, titles over a hairline of progress,
  transport).
- Editing wears the shell: the Dock steps aside and the edit toolbar takes the edge opposite the
  Island (never the Island's edge) as a real attached notch, not a floating pill. It touches the
  physical screen edge, uses the same black material, and paints body + concave fillets as one
  `Shape` path; the fillet radius follows the body radius at ×0.62, matching the Island rule.
  Tooltips always open **inward** from that attached edge, never over the hovered control/pointer;
  snap state keeps one stable grid glyph and communicates on/off through the iRiS control state.
  Its widget rail is app-icon tiles (26 % radius) — grey when off, category tint plus the Dock's
  running dot when on. `ShellLayoutController` reports iRiS bar/Dock insets for zone placement.
  Each widget's action bar is a black capsule with quiet translucent states and the accent reserved
  for *Done*/selection; the quick-controls
  popover and the widget library are black `22·d` plates; choice buttons are translucent with an
  accent selection. The widget library restores its persisted geometry while transparent, then
  reveals in place with iRiS motion — it never flashes at `(0,0)` before moving. `inir background
  toggleWidgetManager` opens the library from IPC.
- **Desktop menu** (`components/IrisDesktopMenu.qml`, right click on the bare desktop): grows out
  of the pointer as one shape into an `18·d` black plate with a hairline; a row of quick-action
  tiles (Wallpaper · Widgets · Search; while editing Widgets · Snap · **Done** in the accent),
  then rows with a sliding accent highlight and an optional muted trailing value (grid size).
  Only actions that drive something under iRiS (no shell-layout editing). No hover-lost timer;
  outside click, Escape, ↑/↓/←/→/Tab + Enter/Space. Same model shape as the shared `ContextMenu`
  plus `{ type: "quick", items }` and `detail`.
- `AbstractBackgroundWidget.widgetSemanticSet()`: iRiS tokens for roles; card radius `22·d`,
  control radius `12·d`, title family `IrisStyle.fontMain`.
- Per-widget, gated on `widgetIris`: plain circular glyph badges and Noto numerals (System
  Monitor); mixed-case labels instead of forced uppercase (Uptime, Day Progress, Battery, Timers,
  Weather, Date Badge, World Clock); native iRiS media player for full/compact presets.
- User-chosen widget shapes/styles stay the user's choice.
- `iris.modules.desktopWidgets = false` unloads the canvas and its providers.

### Utility satellite and expanded tools

An optional utility satellite (`iris.bar.auxiliary`: Tray, Timers, Sound, Microphone or None) emerges behind the
chassis using the activity satellites' single progress. Tray displays the live app count and
retires when empty. Its expanded page uses the shared SystemTray items and TrayService actions:
left click activates, middle click invokes the secondary action, right click opens the app's
platform menu, and scrolling is forwarded to the app. App names, passive filtering and columns
are independent preferences. Overflow scrolls inside the Island.

Timers (config value `tools`) is one row of round dials (neutral face, orange arc for the share of an
hour a preset holds, closed and tinted while that kind runs; the wheel or a vertical drag changes a
preset's minutes — 1-min steps to 10, then 5, up to 3 h — kept in `Persistent` timer state) — 5/15/30-minute countdowns, Focus and
Stopwatch through TimerService — that hands off to the existing activity page; an active countdown cannot be overwritten by the presets. It holds nothing that
lives elsewhere: clipboard is Spotlight, wallpaper is the Desktop hero and desktop menu, widgets are
the desktop menu, and a running activity is already the navigation's activity button.
Both pages are available from expanded navigation even when the utility satellite is hidden.

## 6. Composition and residency

```text
shell.qml
  -> modules/iris/critical/ShellIrisCriticalPanels.qml
       -> IrisBar (+ dismiss layer while pinned)
       -> IrisBackground            (when desktop widgets are disabled)
  -> ShellIrisPanels.qml -> modules/iris/ShellIrisPanelsImpl.qml
       -> IrisDock (+ dismiss layer) (deferred, if enabled)
       -> IrisSidebarEdge ×2         (1 px strips, only while hoverReveal is on)
       -> Background/Backdrop       (deferred, Niri, if background.backdrop.enable)
       -> Background                (deferred, if desktop widgets are enabled)
       -> on-demand: Spotlight, Control Center, Settings, Session, notifications, wallpaper picker,
          media bubble card (while opened or pinned)
       -> IrisBubbleLayer ×outputs     (while a bubble floats or is carried)
       -> Lock, Polkit              (deferred)
```

On-demand morph surfaces keep a close grace of `morphDuration × 1.35 + 120 ms` so the collapse is
never cut. Disabled features must not keep timers, processes, decoders or visual trees alive.

## 7. Configuration

`modules/common/Config.qml` (schema) + `defaults/config.json` (fresh installs) +
`modules/iris/settings/IrisSettings.qml` (UI). Current keys:

```text
iris.appearance.accent, highlight, expandedRadius, motion, motionDuration, density, fontFamily,
         titleFontFamily, numbersFontFamily, figureWeight
iris.bar.position, composition, notch, height, margin, reserveSpace, events, scrollBubbles,
         hoverExpand, hoverDelay, scrollAction, clockStyle, trailing, auxiliary, desktopBanner,
         desktopProfile, screenList, left/center/rightModules (custom modules only)
iris.dock.enable, autoHide, revealOnEmpty, notch, blur, iconSize, magnification, badges, launcher
iris.tray.hidePassive, labels, columns
iris.wallpaper.width, thumbnailSize, livePreview
iris.player.roundCover, artworkBackground, bubbleOpens, cardPinned
iris.sidebars.left|right.enable, width, height, alignment, pinned, notch, hoverReveal, sections, expanded
iris.widgets.radius, opacity, tint, material, weight
iris.palette.width, maxResults, showHints
iris.notifications.width, duration
iris.bubbles.left|right|utility.place, fx, fy; iris.bubbles.extras.<kind>.enable, place, fx, fy;
         iris.bubbles.edgeGap, snap
iris.controlCenter.width
iris.modules.desktopWidgets, palette, controlCenter, notificationPopup, osd, sessionScreen, lock, polkit
```

New defaults apply to fresh installs; no migrations unless explicitly requested. Every iRiS
Settings row carries its default as `fallback` (kept equal to `defaults/config.json`); a section
whose `iris.*` rows differ offers *Restore defaults*, which never touches shared iNiR keys.

## 8. Island modules and extensibility

`custom:<widget-id>` modules (`CustomWidgets` discovery) appear on the Island's Desktop page in
list order; the module lists hold nothing else. User components consume `IrisStyle` and `qs.modules.iris.components`
(see `defaults/widgets/IRIS-SDK.md`).

## 9. Multi-output

Bar, Island and Dock are per-output. Singular surfaces follow `GlobalStates.focusedScreen`; only
the focused output publishes morph origins. Lock and Session are session-wide.

## 10. IPC

```bash
inir iris open | close
inir iris page media|activity|desktop|tray|tools
inir iris toggle
inir iris dock reveal|hide|toggle   # "reveal" stays until hidden or an app is chosen
inir iris card open|close|toggle|pin
inir iris pin left|right            # keep Focus/Today open beside windows
inir iris accent blue|mint|rose|lilac|wallpaper
inir iris utility tray|tools|sound|mic|none
inir iris status                    # JSON: island, dock, Control Center, Spotlight, panels
```

Shared targets cover the rest (`controlPanel`, `sidebarLeft`, `sidebarRight`, `settings`,
`session`, `overview`, `clipboard`, `lock`). Every iRiS surface must be reachable from IPC so it
can be bound in Niri; avoid argument words the IPC CLI reserves (`show`).
`docs/IPC.md` and the generated registry stay in sync with this contract.

## 11. Acceptance

A change to iRiS is acceptable only when:

- it cold-starts without QML/type/binding/loader warnings (`inir logs`);
- the affected surface was exercised in the real runtime and inspected from a `grim` capture —
  for motion, intermediate frames were captured;
- Escape and outside click close every transient surface it touches;
- pinning the Island or opening a Dock menu does not change tiled window geometry
  (`niri msg -j windows`);
- Material II and Waffle are unaffected;
- every Settings row still drives a real consumer;
- anything that needs pointer or keyboard input the agent must not inject is listed as untested.
