# iRiS

iRiS is iNiR's Island family. It uses the same Niri, services, wallpaper state and application models as the rest of iNiR, but owns a separate visual and interaction system through `IrisStyle`.

It first ships publicly in 2.31.0.

## The Island

The Island is the family's main edge object. It can rest on the top, bottom, left or right edge and grow inward into Media, Activity, Desktop, Tray and Tools pages.

```bash
inir iris edge top
inir iris edge left
inir iris page media
inir iris close
```

On a side edge, the resting Island becomes a vertical compact capsule with a stacked clock. The same page/content model is kept; only the edge geometry changes.

Set `iris.bar.layout` to `full` to turn that edge into a full-width/full-height bar. Its start, center and end zones can contain the live Island, workspaces, the focused window, time or any enabled piece:

```bash
inir iris layout full
inir iris zone start workspaces+window
inir iris zone center island
inir iris zone end tray+notifications+sound+controls
```

## Pieces and the Dock

Weather, notifications, controls, sound, microphone, tools, media, tray and app bubbles are pieces. A piece can:

- live in the Island;
- sit on a screen edge;
- join the Island or Dock when it shares their edge;
- float freely on the desktop.

The Dock supports all four edges. `auto` keeps it opposite the Island; explicitly moving one edge owner onto the other's edge swaps their positions instead of stacking them on top of each other.

```bash
inir iris dockEdge auto
inir iris dockEdge left
inir iris bubble weather edge:right:0.35
inir iris appBubble kitty top-right
```

## Themes, glass and Studio

iRiS Themes are whole-family redesigns, not just color palettes. 2.31 ships 14 curated Themes and also supports user Themes as JSON files in:

```text
~/.config/inir/iris/themes
```

Use Studio to edit the material, color, type, motion and individual surfaces live:

```bash
inir iris studio on
inir iris studio themes
inir iris theme list
inir iris theme apply:liquid-glass
inir iris theme save:my-theme
```

Wallpaper glass samples the wallpaper beneath iRiS surfaces and raises its tint where needed to keep text readable. Niri compositor blur can blur windows below a surface too, but it is intentionally marked experimental because moving/transient surfaces can still expose compositor artifacts.

## Desktop widgets

iRiS reuses the shared desktop-widget canvas and persistence. It adds family-specific faces and materials rather than creating another widget system.

The iRiS widget gallery covers the everyday desktop set, including clock, weather, calendar/agenda, media, notes, todo, timers, battery, vitals, profile, world clock, uptime, Controls and Screen Time. Widgets can use iRiS glass/transparent/solid/tinted presentation and keep their placement across family changes.

## Wallpaper gallery

The iRiS wallpaper picker can browse the local library, Wallhaven and live anime scenery. It supports showcase, strip and wall layouts, pinned folders and one-at-a-time muted live previews.

```bash
inir wallpaperSelector browse library -
inir wallpaperSelector browse wallhaven mountains
inir wallpaperSelector browse live -
```

The normal wallpaper service still owns apply/preview state. iRiS does not keep a second wallpaper database.

## Editing and scripting

Edit pieces directly on the desktop:

```bash
inir iris edit on
inir iris arrange on
```

Scripts can publish progress into the Island as live activities:

```bash
inir iris activity start build "Building"
inir iris activity progress build 42%
inir iris activity end build "Done"
```

For the complete command surface, see [IPC](IPC.md#iris).

## Runtime model

iRiS keeps the background and chassis available early, then loads expensive pages and transient surfaces on demand. The family reuses iNiR services for Niri windows/workspaces, media, tray, notifications, widgets and system controls. Closing a page or panel can keep a short warm cache to avoid rebuilding it during normal back-and-forth navigation.

This is why feature cost depends heavily on what is enabled and open. The base family is not supposed to keep every Studio preview, page, floating bubble and Control Center body resident just because iRiS is selected.
