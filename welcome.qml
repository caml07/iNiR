//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property int currentStep: 0

    // ─── Responsive scale ───
    readonly property real screenWidth: focusedScreen?.width ?? 1920
    readonly property real screenHeight: focusedScreen?.height ?? 1080
    readonly property bool compact: screenHeight < 1000
    readonly property bool veryCompact: screenHeight < 720
    readonly property int screenPadding: veryCompact ? 12 : compact ? 24 : 60
    readonly property int cardPadding: compact ? 22 : 30
    readonly property real stepWidth: Math.min(1040,
        screenWidth - 2 * screenPadding - 2 * cardPadding)
    readonly property int totalSteps: 5
    property var focusedScreen: GlobalStates.primaryScreen

    // The first-run frame stays a stable Material surface while the shell itself
    // changes style. Onboarding chrome should never morph under the user's cursor.
    readonly property color welcomeSurfaceRaised: Appearance.m3colors.m3surfaceContainer
    readonly property color welcomeSurfaceHigh: Appearance.m3colors.m3surfaceContainerHigh
    readonly property color welcomeSurfaceHighest: Appearance.m3colors.m3surfaceContainerHighest
    readonly property color welcomeSurfaceRaisedHover: ColorUtils.mix(welcomeSurfaceRaised, welcomeOnSurface, 0.94)
    readonly property color welcomeOnSurface: Appearance.m3colors.m3onSurface
    readonly property color welcomeOnSurfaceVariant: Appearance.m3colors.m3onSurfaceVariant
    readonly property color welcomeOutline: Appearance.m3colors.m3outlineVariant
    readonly property color welcomeScrim: Appearance.m3colors.m3scrim
    readonly property color welcomePrimary: Appearance.m3colors.m3primary
    readonly property color welcomeOnPrimary: Appearance.m3colors.m3onPrimary
    readonly property color welcomePrimaryContainer: Appearance.m3colors.m3primaryContainer
    readonly property color welcomeOnPrimaryContainer: Appearance.m3colors.m3onPrimaryContainer
    readonly property color welcomeSecondary: Appearance.m3colors.m3secondary
    readonly property color welcomeSecondaryContainer: Appearance.m3colors.m3secondaryContainer
    readonly property color welcomeOnSecondaryContainer: Appearance.m3colors.m3onSecondaryContainer
    readonly property color welcomeTertiary: Appearance.m3colors.m3tertiary
    readonly property color welcomeTertiaryContainer: Appearance.m3colors.m3tertiaryContainer
    readonly property color welcomeOnTertiaryContainer: Appearance.m3colors.m3onTertiaryContainer
    // Welcome keeps a stable Material chassis while its accent follows the palette
    // generated from the active wallpaper. Global Style selection must not restyle
    // the wizard itself, but wallpaper colour is useful first-run feedback.
    readonly property color welcomeAccent: welcomePrimary
    readonly property color welcomeAccentAlt: welcomeTertiary
    readonly property color welcomeAccentContainer: welcomePrimaryContainer
    readonly property color welcomeAccentHover: ColorUtils.mix(welcomePrimaryContainer, welcomeOnPrimaryContainer, 0.90)
    readonly property color welcomeOnAccent: welcomeOnPrimary
    readonly property color welcomeOnAccentContainer: welcomeOnPrimaryContainer
    readonly property color welcomeGuideContainer: welcomeTertiaryContainer
    readonly property color welcomeGuideText: welcomeOnTertiaryContainer
    readonly property string welcomeFontMain: Config.options?.appearance?.typography?.mainFont ?? "Roboto Flex"
    readonly property string welcomeFontTitle: Config.options?.appearance?.typography?.titleFont ?? "Gabarito"
    readonly property string welcomeFontNumbers: "Rubik"
    readonly property string welcomeFontExpressive: "Space Grotesk"
    readonly property int welcomeFontMeta: Math.max(13, Appearance.font.pixelSize.smallest)
    readonly property int welcomeFontCaption: Math.max(14, Appearance.font.pixelSize.smaller)
    readonly property int welcomeFontBody: Math.max(15, Appearance.font.pixelSize.small)
    readonly property int welcomeFontSection: Math.max(17, Appearance.font.pixelSize.normal)
    readonly property color welcomeSecondaryText: ColorUtils.ensureReadable(
        welcomeOnSurfaceVariant, welcomeSurfaceRaised, 4.5)
    readonly property color welcomeTertiaryText: ColorUtils.ensureReadable(
        ColorUtils.applyAlpha(welcomeOnSurfaceVariant, 0.86), welcomeSurfaceRaised, 4.0)

    readonly property string selectedProfile: Config.options?.welcomeWizard?.profile ?? "balanced"
    readonly property string selectedStylePreset: Config.options?.welcomeWizard?.stylePreset ?? "material"
    readonly property string selectedPerformancePreset: Config.options?.welcomeWizard?.performancePreset ?? "balanced"
    property bool profileCustomized: false
    property bool initialProfileApplied: false
    property bool initialPerformanceApplied: false
    readonly property bool firstRunSetup: !(Config.options?.welcomeWizard?.completed ?? false)
        && !(Config.options?.welcomeWizard?.skipped ?? false)

    readonly property string selectedProfileTitle: selectedProfile === "minimum"
        ? Translation.tr("Minimum")
        : selectedProfile === "full" ? Translation.tr("Full") : Translation.tr("Balanced")
    readonly property string selectedProfileDescription: selectedProfile === "minimum"
        ? Translation.tr("Core bar, sidebars and local controls. No desktop widgets.")
        : selectedProfile === "full"
            ? Translation.tr("More local tools, richer sidebars and a small system monitor.")
            : Translation.tr("Useful sidebars, eight everyday toggles and one desktop clock.")
    readonly property var stylePresets: [
        {
            id: "material", name: Translation.tr("Flow"), icon: "category",
            globalStyle: "material",
            description: Translation.tr("Clean Material surfaces with the M3 bar and dock."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "m3",
                "bar.m3.borderless": "pills",
                "bar.m3.showBackground": true,
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "m3",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "cookie", name: Translation.tr("Expressive"), icon: "interests",
            globalStyle: "cookie",
            description: Translation.tr("Playful shapes, joined controls and a pill dock."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "pill",
                "bar.pill.barMode": false,
                "bar.pill.musicViz": false,
                "bar.pill.soul.enable": true,
                "bar.pill.soul.style": "orb",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "pill",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "aurora", name: Translation.tr("Glass"), icon: "blur_on",
            globalStyle: "aurora",
            description: Translation.tr("Translucent islands for the bar, dock and sidebars."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "islands",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "island",
                "dock.showBackground": true,
                "sidebar.style": "island"
            }
        },
        {
            id: "inir", name: "iNiR", icon: "terminal",
            globalStyle: "inir",
            description: Translation.tr("Sharp framed surfaces with a denser, technical feel."),
            values: {
                "appearance.iiMotionProfile": "classic",
                "bar.appearanceStyle": "frame",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "panel",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "cards", name: Translation.tr("Cards"), icon: "branding_watermark",
            globalStyle: "cards",
            description: Translation.tr("Soft rounded cards with familiar desktop structure."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "classic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "panel",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "angel", name: Translation.tr("Angel"), icon: "raven",
            globalStyle: "angel",
            description: Translation.tr("Scenic glass, strong accents and a pill dock."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "appearance.angelSubStyle": "frost",
                "bar.appearanceStyle": "scenic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "pill",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "regalia", name: Translation.tr("Regalia"), icon: "event_seat",
            globalStyle: "regalia",
            description: Translation.tr("Structured surfaces, a classic bar and a macOS-style dock."),
            values: {
                "appearance.iiMotionProfile": "classic",
                "bar.appearanceStyle": "classic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "macos",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "zzz", name: "ZZZ", icon: "bolt",
            globalStyle: "zzz",
            description: Translation.tr("Poster-like surfaces with bold graphic contrast."),
            values: {
                "appearance.iiMotionProfile": "classic",
                "bar.appearanceStyle": "classic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "panel",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "editorial", name: Translation.tr("Editorial"), icon: "auto_stories",
            globalStyle: "editorial",
            description: Translation.tr("Quiet paper-like surfaces led by typography."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "classic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "panel",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        }
    ]

    readonly property var performancePresets: [
        {
            id: "minimum", name: Translation.tr("Save power"), icon: "energy_savings_leaf",
            description: Translation.tr("Cuts heavy effects and reduces motion for battery-first or lower-end systems."),
            values: {
                "performance.lowPower": true,
                "performance.reduceAnimations": true,
                "performance.blurBackend": "auto",
                "performance.compositorBlur": false,
                "performance.blurAreas.bar": "inherit",
                "performance.blurAreas.dock": "inherit",
                "performance.blurAreas.panels": "inherit",
                "performance.blurAreas.islands": "inherit",
                "performance.blurAreas.widgets": "inherit"
            }
        },
        {
            id: "efficient", name: Translation.tr("Fewer effects"), icon: "speed",
            description: Translation.tr("Keeps normal motion while avoiding expensive blur."),
            values: {
                "performance.lowPower": false,
                "performance.reduceAnimations": false,
                "performance.blurBackend": "auto",
                "performance.compositorBlur": false,
                "performance.blurAreas.bar": "inherit",
                "performance.blurAreas.dock": "inherit",
                "performance.blurAreas.panels": "inherit",
                "performance.blurAreas.islands": "inherit",
                "performance.blurAreas.widgets": "inherit"
            }
        },
        {
            id: "balanced", name: Translation.tr("Full style"), icon: "tune",
            description: Translation.tr("Uses the selected style's full motion and effects. Game Mode can still scale them back."),
            values: {
                "performance.lowPower": false,
                "performance.reduceAnimations": false,
                "performance.blurBackend": "auto",
                "performance.compositorBlur": true,
                "performance.blurAreas.bar": "inherit",
                "performance.blurAreas.dock": "inherit",
                "performance.blurAreas.panels": "inherit",
                "performance.blurAreas.islands": "inherit",
                "performance.blurAreas.widgets": "inherit"
            }
        }
    ]

    function presetById(list: var, id: string): var {
        return list.find(preset => preset.id === id) ?? list[0]
    }

    function valuesMatch(values: var): bool {
        const keys = Object.keys(values ?? {})
        for (const key of keys) {
            const current = Config.getNestedValue(key, undefined)
            if (JSON.stringify(current) !== JSON.stringify(values[key]))
                return false
        }
        return true
    }

    function flowM3Layout(profile: string): var {
        if (profile === "minimum")
            return {
                "bar.m3.layoutMode": "custom",
                "bar.m3.layouts.leftLayout": ["leftSidebarButton", "workspaces"],
                "bar.m3.layouts.middleLayout": ["docktoPanel"],
                "bar.m3.layouts.rightLayout": ["clockWidget", "systemIcons", "rightSidebarButton"]
            }
        return {
            "bar.m3.layoutMode": "compact",
            "bar.m3.layouts.leftLayout": ["leftSidebarButton", "media", "workspaces"],
            "bar.m3.layouts.middleLayout": ["docktoPanel"],
            "bar.m3.layouts.rightLayout": ["utilButtons", "weatherBar", "clockWidget", "systemIcons", "rightSidebarButton"]
        }
    }

    function stylePresetMatches(id: string): bool {
        const preset = root.presetById(root.stylePresets, id)
        return (Config.options?.appearance?.globalStyle ?? "material") === preset.globalStyle
            && root.valuesMatch(preset.values)
            && (id !== "material" || root.valuesMatch(root.flowM3Layout(root.selectedProfile)))
    }

    function performancePresetMatches(id: string): bool {
        return root.valuesMatch(root.presetById(root.performancePresets, id).values)
    }

    readonly property string effectiveStylePreset: root.stylePresetMatches(root.selectedStylePreset)
        ? root.selectedStylePreset : "custom"
    readonly property string effectivePerformancePreset: root.performancePresetMatches(root.selectedPerformancePreset)
        ? root.selectedPerformancePreset : "custom"
    readonly property var currentStylePreset: root.presetById(root.stylePresets, root.selectedStylePreset)
    readonly property var currentPerformancePreset: root.presetById(root.performancePresets, root.selectedPerformancePreset)
    readonly property string currentStylePresetDescription: root.effectiveStylePreset === "custom"
        ? Translation.tr("Your current settings mix styles. Pick a preset to bring the shell back into sync.")
        : root.currentStylePreset.description
    readonly property string currentPerformancePresetDescription: root.effectivePerformancePreset === "custom"
        ? Translation.tr("Your effects settings are custom. Pick a mode to restore a matched setup.")
        : root.currentPerformancePreset.description

    // Every starting profile prepares shared services and the Material II
    // family. Waffle keeps its independent `waffles.*` configuration intact,
    // so switching families never erases or silently reconfigures it.
    readonly property var profileEssentials: ({
        "dock.enable": true,
        "dock.hoverToReveal": false,
        "dock.pinnedOnStartup": true,
        "dashboard.enable": true,
        "bar.weather.enable": true,
        "bar.modules.weather": true,
        "bar.modules.battery": true,
        "bar.modules.sysTray": true,
        "bar.modules.clock": true,
        "bar.modules.workspaces": true,
        "bar.modules.activeWindow": true,
        "bar.modules.leftSidebarButton": true,
        "bar.modules.rightSidebarButton": true,
        "sounds.notifications": true,
        "gameMode.autoDetect": true,
        "audio.protection.enable": true,
        "sidebar.collapseEmptyNotifications": false,
        "sidebar.collapseWidgetsTab": false,
        "sidebar.right.headerBanner": "wallpaper",
        "sidebar.right.sectionOrder": ["system", "sliders", "toggles", "notifications", "widgets"],
        "sidebar.quickToggles.style": "android",
        "sidebar.quickToggles.android.columns": 4,
        // Material II's embedded bar taskbar duplicates the Material II dock.
        // Waffle owns a separate taskbar under `waffles.bar.*` and is unaffected.
        "bar.modules.taskbar": false
    })

    // Ordering only; no profile enables a provider-backed tab.
    readonly property var profileTabOrder: [
        "widgets", "wallhaven", "news", "tools", "software",
        "ai", "translator", "anime", "animeSchedule", "ytmusic"
    ]

    // Desktop widgets all default to the same corner and "leastBusy" cannot see
    // a sibling, so a profile composing more than one must place them by hand.
    function profileComposition(profile: string): var {
        if (profile === "minimum")
            return {
                "bar.modules.resources": false,
                "bar.modules.utilButtons": false,
                "bar.modules.media": false,
                "bar.m3.layoutMode": "custom",
                "bar.m3.layouts.leftLayout": ["leftSidebarButton", "workspaces"],
                "bar.m3.layouts.middleLayout": ["docktoPanel"],
                "bar.m3.layouts.rightLayout": ["clockWidget", "systemIcons", "rightSidebarButton"],
                "sidebar.news.enable": false,
                "sidebar.wallhaven.enable": false,
                "sidebar.ytmusic.enable": false,
                "sidebar.tools.enable": false,
                "sidebar.software.enable": false,
                "sidebar.widgets.context": true,
                "sidebar.widgets.week": true,
                "sidebar.widgets.media": true,
                "sidebar.widgets.controls": false,
                "sidebar.widgets.status": false,
                "sidebar.widgets.wallpaper": true,
                "sidebar.widgets.note": false,
                "sidebar.widgets.launch": false,
                "sidebar.widgets.worldClock": false,
                "sidebar.right.enabledWidgets": ["calendar", "todo"],
                "sidebar.quickToggles.android.toggles": [
                    { "size": 1, "type": "network" },
                    { "size": 1, "type": "bluetooth" },
                    { "size": 1, "type": "audio" },
                    { "size": 1, "type": "mic" }
                ],
                "background.widgets.clock.enable": false,
                "background.widgets.clock.quote.enable": false,
                "background.widgets.visualizer.enable": false,
                "background.widgets.systemMonitor.enable": false,
                "background.widgets.weather.enable": false,
                "background.widgets.battery.enable": false,
                "background.widgets.mediaControls.enable": false,
                "background.widgets.calendarUpcoming.enable": false,
                "mascot.enable": false
            }
        if (profile === "full")
            return {
                "bar.modules.resources": true,
                "bar.modules.utilButtons": true,
                "bar.modules.media": true,
                "bar.m3.layoutMode": "compact",
                "bar.m3.layouts.leftLayout": ["leftSidebarButton", "media", "workspaces"],
                "bar.m3.layouts.middleLayout": ["docktoPanel"],
                "bar.m3.layouts.rightLayout": ["utilButtons", "weatherBar", "clockWidget", "systemIcons", "rightSidebarButton"],
                "sidebar.news.enable": true,
                "sidebar.wallhaven.enable": true,
                "sidebar.ytmusic.enable": true,
                "sidebar.tools.enable": true,
                "sidebar.software.enable": true,
                "sidebar.widgets.context": true,
                "sidebar.widgets.week": true,
                "sidebar.widgets.media": true,
                "sidebar.widgets.controls": true,
                "sidebar.widgets.status": true,
                "sidebar.widgets.wallpaper": true,
                "sidebar.widgets.note": true,
                "sidebar.widgets.launch": true,
                "sidebar.widgets.worldClock": true,
                "sidebar.right.enabledWidgets": [
                    "calendar", "events", "todo", "notepad",
                    "calculator", "sysmon", "weather", "timer"
                ],
                "sidebar.quickToggles.android.toggles": [
                    { "size": 1, "type": "network" },
                    { "size": 1, "type": "bluetooth" },
                    { "size": 1, "type": "audio" },
                    { "size": 1, "type": "mic" },
                    { "size": 1, "type": "nightLight" },
                    { "size": 1, "type": "screenSnip" },
                    { "size": 1, "type": "colorPicker" },
                    { "size": 1, "type": "idleInhibitor" }
                ],
                "background.widgets.clock.enable": true,
                "background.widgets.clock.placementStrategy": "topRight",
                "background.widgets.clock.quote.enable": false,
                "background.widgets.visualizer.enable": false,
                "background.widgets.clock.backgroundOpacity": 0,
                "background.widgets.clock.borderOpacity": 0.08,
                "background.widgets.systemMonitor.enable": true,
                "background.widgets.systemMonitor.placementStrategy": "bottomRight",
                "background.widgets.weather.enable": false,
                "background.widgets.battery.enable": false,
                "background.widgets.mediaControls.enable": false,
                "background.widgets.calendarUpcoming.enable": false,
                "mascot.enable": false
            }
        return {
            "bar.modules.resources": true,
            "bar.modules.utilButtons": true,
            "bar.modules.media": true,
            "bar.m3.layoutMode": "compact",
            "bar.m3.layouts.leftLayout": ["leftSidebarButton", "media", "workspaces"],
            "bar.m3.layouts.middleLayout": ["docktoPanel"],
            "bar.m3.layouts.rightLayout": ["utilButtons", "weatherBar", "clockWidget", "systemIcons", "rightSidebarButton"],
            "sidebar.news.enable": true,
            "sidebar.wallhaven.enable": true,
            "sidebar.ytmusic.enable": false,
            "sidebar.tools.enable": false,
            "sidebar.software.enable": false,
            "sidebar.widgets.context": true,
            "sidebar.widgets.week": true,
            "sidebar.widgets.media": true,
            "sidebar.widgets.controls": true,
            "sidebar.widgets.status": true,
            "sidebar.widgets.wallpaper": true,
            "sidebar.widgets.note": false,
            "sidebar.widgets.launch": false,
            "sidebar.widgets.worldClock": false,
            "sidebar.right.enabledWidgets": [
                "calendar", "events", "todo", "notepad", "weather"
            ],
            "sidebar.quickToggles.android.toggles": [
                { "size": 1, "type": "network" },
                { "size": 1, "type": "bluetooth" },
                { "size": 1, "type": "audio" },
                { "size": 1, "type": "mic" },
                { "size": 1, "type": "nightLight" },
                { "size": 1, "type": "screenSnip" },
                { "size": 1, "type": "colorPicker" },
                { "size": 1, "type": "idleInhibitor" }
            ],
            // One widget is enough for a fresh desktop, and a named zone keeps
            // the placement deterministic across common output sizes.
            "background.widgets.clock.enable": true,
            "background.widgets.clock.placementStrategy": "topRight",
            "background.widgets.clock.quote.enable": false,
            "background.widgets.clock.backgroundOpacity": 0,
            "background.widgets.clock.borderOpacity": 0.08,
            "background.widgets.visualizer.enable": false,
            "background.widgets.systemMonitor.enable": false,
            "background.widgets.weather.enable": false,
            "background.widgets.battery.enable": false,
            "background.widgets.mediaControls.enable": false,
            "background.widgets.calendarUpcoming.enable": false,
            "mascot.enable": false
        }
    }

    function applyProfile(profile: string): void {
        Config.setNestedValues(Object.assign({},
            root.profileEssentials,
            root.profileComposition(profile), {
                "sidebar.left.tabOrder": root.profileTabOrder,
                "welcomeWizard.profile": profile
            }))
        root.profileCustomized = false
    }

    function applyStylePreset(id: string): void {
        const preset = root.presetById(root.stylePresets, id)
        ThemeService.setGlobalStyle(preset.globalStyle)
        const flowLayout = id === "material" ? root.flowM3Layout(root.selectedProfile) : {}
        Config.setNestedValues(Object.assign({}, preset.values, flowLayout, {
            "welcomeWizard.stylePreset": preset.id
        }))
    }

    function applyPerformancePreset(id: string): void {
        const preset = root.presetById(root.performancePresets, id)
        Config.setNestedValues(Object.assign({}, preset.values, {
            "welcomeWizard.performancePreset": preset.id
        }))
    }

    function setProfileFeature(path: string, value: var): void {
        root.profileCustomized = true
        if (path === "panelFamily") {
            Quickshell.execDetached([
                Quickshell.shellPath("scripts/inir"),
                "panelFamily", "set", String(value)
            ])
            return
        }
        Config.setNestedValue(path, value)
    }

    onCurrentStepChanged: {
        if (!root.firstRunSetup)
            return
        if (root.currentStep === 1) {
            if (!root.initialProfileApplied) {
                root.initialProfileApplied = true
                root.applyProfile(root.selectedProfile)
            }
            if (!root.initialPerformanceApplied) {
                root.initialPerformanceApplied = true
                root.applyPerformancePreset(root.selectedPerformancePreset)
            }
        }
    }

    // ─── Entry/exit animation state (gate pattern) ───
    property bool _entryReady: false
    property bool _contentReady: false
    property bool _closing: false

    // The starting point runs before Appearance and Layout: a profile writes
    // composition keys wholesale and would overwrite anything refined earlier.
    readonly property var steps: [
        {
            icon: "waving_hand", title: Translation.tr("Welcome"),
            headline: Translation.tr("Welcome to iNiR"),
            subtitle: Translation.tr("Five quick steps. You can change everything later in Settings.")
        },
        {
            icon: "tune", title: Translation.tr("Starting point"),
            headline: Translation.tr("Choose your starting setup"),
            subtitle: Translation.tr("Start simple, balanced or with more tools. You can change every module later.")
        },
        {
            icon: "palette", title: Translation.tr("Appearance"),
            headline: Translation.tr("Make it yours"),
            subtitle: Translation.tr("Wallpaper sets the colors. Style sets the shape and feel.")
        },
        {
            icon: "dashboard", title: Translation.tr("Layout"),
            headline: Translation.tr("Arrange the desktop"),
            subtitle: Translation.tr("Choose your shell family and where the bar and dock go.")
        },
        {
            icon: "celebration", title: Translation.tr("Ready"),
            headline: Translation.tr("You're all set"),
            subtitle: Translation.tr("A few shortcuts and actions to get you moving.")
        }
    ]

    function finish(skipped: bool): void {
        if (root._closing) return
        root._closing = true
        // Write config keys
        Config.setNestedValue("welcomeWizard.completed", !skipped)
        Config.setNestedValue("welcomeWizard.skipped", skipped)
        // Reverse the entry animation
        root._contentReady = false
        root._entryReady = false
        _exitTimer.start()
    }

    Timer {
        id: _exitTimer
        interval: Appearance.animationsEnabled ? 400 : 0
        repeat: false
        onTriggered: {
            // first_run.txt is already written by FirstRunExperience before launching us
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Welcome to inir"), Translation.tr("Press Super+/ for all keyboard shortcuts."), "-a", "Shell"])
            Qt.quit()
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0
        // Staggered entry: scrim first, then card content
        if (Appearance.animationsEnabled) {
            _entryTimer.start()
        } else {
            root._entryReady = true
            root._contentReady = true
        }
    }

    Timer {
        id: _entryTimer
        interval: 80
        repeat: false
        onTriggered: {
            root._entryReady = true
            _contentEntryTimer.start()
        }
    }
    Timer {
        id: _contentEntryTimer
        interval: 120
        repeat: false
        onTriggered: root._contentReady = true
    }

    component WelcomeText: StyledText {
        defaultFont: root.welcomeFontMain
        font.letterSpacing: 0
        font.variableAxes: ({})
    }

    component WelcomeActionButton: RippleButton {
        id: actionButton

        property string label: ""
        property string materialIcon: ""
        property bool primary: false

        implicitWidth: actionContent.implicitWidth + 24
        implicitHeight: 42
        buttonRadius: 12
        rippleEnabled: true
        cookieMorphing: false
        colBackground: primary ? root.welcomeAccent : "transparent"
        colBackgroundHover: primary
            ? ColorUtils.mix(root.welcomeAccent, root.welcomeOnAccent, 0.88)
            : root.welcomeSurfaceHigh
        colRipple: primary
            ? ColorUtils.applyAlpha(root.welcomeOnAccent, 0.22)
            : root.welcomeSurfaceHighest

        contentItem: RowLayout {
            id: actionContent
            anchors.centerIn: parent
            spacing: actionButton.materialIcon.length > 0 ? 6 : 0

            MaterialSymbol {
                visible: actionButton.materialIcon.length > 0
                text: actionButton.materialIcon
                iconSize: 17
                color: actionButton.primary ? root.welcomeOnAccent : root.welcomeAccent
            }

            WelcomeText {
                text: actionButton.label
                font.family: root.welcomeFontTitle
                font.pixelSize: root.welcomeFontBody
                font.weight: actionButton.primary ? Font.Bold : Font.Medium
                color: actionButton.primary ? root.welcomeOnAccent : root.welcomeOnSurface
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    component WelcomeStepMark: Item {
        id: stepMark

        property string icon: "category"
        property string indexText: "01"

        implicitWidth: 104
        implicitHeight: 58

        WelcomeText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: stepMark.indexText
            font.family: root.welcomeFontNumbers
            font.pixelSize: 44
            font.weight: Font.DemiBold
            color: ColorUtils.applyAlpha(root.welcomeAccent, 0.105)
        }

        MaterialCookie {
            anchors.right: parent.right
            anchors.rightMargin: 48
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 42
            sides: 8
            color: ColorUtils.applyAlpha(root.welcomeAccentContainer, 0.92)

            MaterialSymbol {
                anchors.centerIn: parent
                text: stepMark.icon
                iconSize: 21
                color: root.welcomeAccent
            }
        }
    }

    component WelcomeMetric: Item {
        id: metric

        property string value: "—"
        property string label: ""
        property color accent: root.welcomeAccent

        implicitHeight: 58

        RowLayout {
            anchors.fill: parent
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 3
                Layout.preferredHeight: 34
                radius: 2
                color: metric.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                WelcomeText {
                    Layout.fillWidth: true
                    text: metric.value
                    font.family: root.welcomeFontNumbers
                    font.pixelSize: Appearance.font.pixelSize.huge * 1.12
                    font.weight: Font.Bold
                    color: metric.accent
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: metric.label
                    font.pixelSize: root.welcomeFontMeta
                    font.weight: Font.Medium
                    color: root.welcomeSecondaryText
                    elide: Text.ElideRight
                }
            }
        }
    }

    component WelcomeSegmentedControl: RowLayout {
        id: segmented

        property var options: []
        property var currentValue: null
        signal selected(var value)

        spacing: 6

        Repeater {
            model: segmented.options

            RippleButton {
                id: segmentButton
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 36
                readonly property bool active: segmented.currentValue != null
                    && segmented.currentValue == modelData.value
                buttonRadius: 10
                rippleEnabled: true
                cookieMorphing: false
                colBackground: active ? root.welcomeAccentContainer : root.welcomeSurfaceRaised
                colBackgroundHover: active ? root.welcomeAccentHover : root.welcomeSurfaceHigh
                colRipple: root.welcomeSurfaceHighest
                onClicked: segmented.selected(modelData.value)

                contentItem: Item {
                    WelcomeText {
                        anchors.centerIn: parent
                        text: segmentButton.modelData.displayName
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontCaption
                        font.weight: segmentButton.active ? Font.Bold : Font.Medium
                        color: segmentButton.active ? root.welcomeOnAccentContainer : root.welcomeSecondaryText
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MaterialSymbol {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: segmentButton.modelData.icon || ""
                        iconSize: 15
                        color: segmentButton.active ? root.welcomeAccent : root.welcomeSecondaryText
                    }
                }
            }
        }
    }

    component WelcomeKey: Rectangle {
        id: keyCap
        property string key: ""

        implicitWidth: keyLabel.implicitWidth + 14
        implicitHeight: 24
        radius: 7
        color: root.welcomeSurfaceHighest
        border.width: 1
        border.color: ColorUtils.applyAlpha(root.welcomeOutline, 0.55)

        WelcomeText {
            id: keyLabel
            anchors.centerIn: parent
            text: keyCap.key
            font.family: root.welcomeFontMain
            font.pixelSize: root.welcomeFontMeta
            font.weight: Font.Medium
            color: root.welcomeOnSurface
        }
    }

    component WelcomeListAction: RippleButton {
        id: listAction

        property string materialIcon: ""
        property string title: ""
        property string subtitle: ""

        implicitHeight: 46
        buttonRadius: 12
        rippleEnabled: true
        cookieMorphing: false
        colBackground: root.welcomeSurfaceRaised
        colBackgroundHover: root.welcomeSurfaceHigh
        colRipple: root.welcomeSurfaceHighest

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            MaterialSymbol {
                text: listAction.materialIcon
                iconSize: 18
                color: root.welcomeAccent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                WelcomeText {
                    Layout.fillWidth: true
                    text: listAction.title
                    font.family: root.welcomeFontTitle
                    font.pixelSize: root.welcomeFontBody
                    font.weight: Font.DemiBold
                    color: root.welcomeOnSurface
                    elide: Text.ElideRight
                }
                WelcomeText {
                    Layout.fillWidth: true
                    text: listAction.subtitle
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                text: "arrow_forward"
                iconSize: 16
                color: root.welcomeSecondaryText
                opacity: 0.7
            }
        }
    }

    PanelWindow {
        id: wizardPanel
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:welcome"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root._closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }
        implicitWidth: root.focusedScreen?.width ?? 1920
        implicitHeight: root.focusedScreen?.height ?? 1080

        // Keep the live desktop readable behind onboarding. Re-rendering and blurring
        // the wallpaper hid the bar/dock changes being configured and paid a full-screen
        // GPU cost for no useful first-run information.
        Item {
            id: scrim
            anchors.fill: parent
            opacity: root._entryReady ? 1.0 : 0.0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(320)
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                color: root.welcomeScrim
                opacity: 0.28
            }
        }

        // Click outside does NOT dismiss — just absorb clicks
        MouseArea {
            anchors.fill: parent
        }

        // Main wizard card: one stable onboarding frame. Page content follows the
        // same flat sections, dense rows and selective tonal groups used by iNiR.
        Item {
            id: wizardCard
            readonly property real preferredHeight: root.currentStep === 4 ? (root.compact ? 720 : 760)
                : root.currentStep === 2 || root.currentStep === 3 ? (root.compact ? 680 : 720)
                : (root.compact ? 640 : 670)
            anchors.centerIn: parent
            width: Math.max(360, Math.min(1120,
                parent.width - 2 * root.screenPadding))
            height: Math.max(360, Math.min(parent.height - 2 * root.screenPadding,
                preferredHeight))
            focus: true

            Behavior on height {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }

            transformOrigin: Item.Center
            scale: root._contentReady ? 1.0 : 0.96
            opacity: root._contentReady ? 1.0 : 0.0
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(260)
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.calcEffectiveDuration(220); easing.type: Easing.OutCubic }
            }

            Keys.onEscapePressed: root.finish(true)
            Keys.onLeftPressed: if (root.currentStep > 0) root.currentStep--
            Keys.onRightPressed: if (root.currentStep < root.totalSteps - 1) root.currentStep++
            Keys.onReturnPressed: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)
            Keys.onEnterPressed: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)

            PanelSurface {
                id: cardBg
                anchors.fill: parent
                surfaceDialect: "material"
                elevation: 1
                opaqueSurface: false
                cardStyle: true
                outlined: true
                radiusOverride: 20
                clipContent: true
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // First-run navigation follows the same quiet tab grammar used
                // across Settings: labels and glyphs sit on the field, and the
                // active step is carried by one short accent rule.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.compact ? 58 : 66

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.compact ? 16 : 22
                        anchors.rightMargin: root.compact ? 14 : 20
                        spacing: root.compact ? 6 : 10

                        RowLayout {
                            Layout.preferredWidth: wizardCard.width >= 820 ? 138 : 46
                            spacing: 9
                            MaterialCookie {
                                implicitSize: 34
                                sides: 8
                                color: root.welcomeAccentContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "deployed_code"
                                    iconSize: 18
                                    color: root.welcomeAccent
                                }
                            }
                            ColumnLayout {
                                visible: wizardCard.width >= 820
                                spacing: 0
                                WelcomeText {
                                    text: "iNiR"
                                    font.family: root.welcomeFontTitle
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: root.welcomeOnSurface
                                }
                                WelcomeText {
                                    text: Translation.tr("Setup")
                                    font.pixelSize: root.welcomeFontMeta
                                    color: root.welcomeSecondaryText
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Repeater {
                                model: root.steps

                                RippleButton {
                                    id: stepTab
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: root.compact ? 44 : 48
                                    enabled: index <= root.currentStep
                                    opacity: enabled ? 1 : 0.62
                                    buttonRadius: 10
                                    colBackground: index === root.currentStep
                                        ? ColorUtils.applyAlpha(root.welcomeAccentContainer, 0.94)
                                        : "transparent"
                                    colBackgroundHover: index === root.currentStep
                                        ? root.welcomeAccentHover
                                        : root.welcomeSurfaceHigh
                                    colRipple: root.welcomeSurfaceHighest
                                    onClicked: root.currentStep = index

                                    contentItem: Item {
                                        WelcomeText {
                                            id: stepLabel
                                            anchors.centerIn: parent
                                            visible: wizardCard.width >= 860
                                            text: stepTab.modelData.title
                                            font.family: root.welcomeFontTitle
                                            font.pixelSize: root.welcomeFontCaption
                                            font.weight: stepTab.index === root.currentStep ? Font.Bold : Font.Medium
                                            color: stepTab.index === root.currentStep
                                                ? root.welcomeOnAccentContainer : root.welcomeSecondaryText
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        MaterialSymbol {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: stepLabel.visible
                                                ? Math.max(7, stepLabel.x - width - 6)
                                                : Math.round((parent.width - width) / 2)
                                            text: stepTab.index < root.currentStep ? "check" : stepTab.modelData.icon
                                            iconSize: 15
                                            color: stepTab.index === root.currentStep
                                                ? root.welcomeOnAccentContainer
                                                : stepTab.index < root.currentStep
                                                    ? root.welcomeAccent
                                                    : root.welcomeSecondaryText
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: stepTab.index === root.currentStep ? Math.min(parent.width - 18, 58) : 0
                                            height: 3
                                            radius: 1.5
                                            color: root.welcomeAccent
                                            Behavior on width {
                                                enabled: Appearance.animationsEnabled
                                                NumberAnimation {
                                                    duration: Appearance.animation.elementResize.duration
                                                    easing.type: Appearance.animation.elementResize.type
                                                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RippleButton {
                            id: skipButton
                            visible: root.currentStep < root.totalSteps - 1
                            implicitWidth: skipContent.implicitWidth + 16
                            implicitHeight: 34
                            buttonRadius: 10
                            colBackground: "transparent"
                            colBackgroundHover: root.welcomeSurfaceHigh
                            colRipple: root.welcomeSurfaceHighest
                            onClicked: root.finish(true)

                            contentItem: RowLayout {
                                id: skipContent
                                anchors.centerIn: parent
                                spacing: 5
                                WelcomeText {
                                    visible: wizardCard.width >= 760
                                    text: Translation.tr("Skip setup")
                                    font.pixelSize: root.welcomeFontMeta
                                    color: root.welcomeSecondaryText
                                }
                                MaterialSymbol {
                                    text: "close"
                                    iconSize: 14
                                    color: root.welcomeSecondaryText
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: ColorUtils.applyAlpha(root.welcomeOutline, 0.55)
                }

                // Page body: strong textual hierarchy, then one task-specific
                // composition. Avoid repeating a decorative icon card at every step.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: root.compact ? 22 : 28
                    Layout.rightMargin: root.compact ? 22 : 28
                    Layout.topMargin: root.compact ? 14 : 18
                    Layout.bottomMargin: root.compact ? 10 : 14
                    spacing: root.compact ? 10 : 13

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 18

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 3
                                    radius: 2
                                    color: root.welcomeAccentAlt
                                }

                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: String(root.currentStep + 1).padStart(2, "0") + "  "
                                        + root.steps[root.currentStep].title.toUpperCase()
                                    font.family: root.welcomeFontNumbers
                                    font.pixelSize: root.welcomeFontMeta
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.0
                                    color: root.welcomeAccentAlt
                                }
                            }

                            WelcomeText {
                                Layout.fillWidth: true
                                text: root.steps[root.currentStep].headline
                                font.family: root.welcomeFontExpressive
                                font.pixelSize: root.compact
                                    ? Appearance.font.pixelSize.huge * 1.22
                                    : Appearance.font.pixelSize.hugeass * 1.34
                                font.weight: Font.Bold
                                font.letterSpacing: -0.42
                                color: root.welcomeOnSurface
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            WelcomeText {
                                Layout.fillWidth: true
                                visible: !root.veryCompact
                                text: root.steps[root.currentStep].subtitle
                                font.pixelSize: root.welcomeFontBody
                                font.weight: Font.Medium
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.topMargin: 3
                                Layout.preferredWidth: Math.min(116, parent.width * 0.16)
                                Layout.preferredHeight: 3
                                radius: 2
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.welcomeAccent }
                                    GradientStop { position: 1.0; color: root.welcomeAccentAlt }
                                }
                            }
                        }

                        WelcomeStepMark {
                            visible: wizardCard.width >= 850
                            icon: root.steps[root.currentStep].icon
                            indexText: String(root.currentStep + 1).padStart(2, "0")
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        StackLayout {
                            id: stepStack
                            anchors.fill: parent
                            currentIndex: root.currentStep
                            property int prevStep: 0

                            onCurrentIndexChanged: {
                                stepTranslate.x = currentIndex > prevStep ? 18 : -18
                                stepFade.restart()
                                prevStep = currentIndex
                            }

                            transform: Translate { id: stepTranslate; x: 0 }
                            opacity: 1

                            SequentialAnimation {
                                id: stepFade
                                ParallelAnimation {
                                    NumberAnimation { target: stepStack; property: "opacity"; from: 0.55; to: 1; duration: 190; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: stepTranslate; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                                }
                            }

                            Item { WelcomeContent { id: welcomePage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } ScrollEdgeFade { target: welcomePage; visible: welcomePage.contentHeight > welcomePage.height } }
                            Item { FeaturesContent { id: featuresPage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } ScrollEdgeFade { target: featuresPage; visible: featuresPage.contentHeight > featuresPage.height } }
                            Item { ThemeContent { id: themePage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } ScrollEdgeFade { target: themePage; visible: themePage.contentHeight > themePage.height } }
                            Item { LayoutContent { id: layoutPage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } ScrollEdgeFade { target: layoutPage; visible: layoutPage.contentHeight > layoutPage.height } }
                            Item { ReadyContent { id: readyPage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } }
                        }
                    }
                }

                // Fixed footer, mirroring the proven greeter pattern: one nested
                // surface, one secondary action, one primary action.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.compact ? 56 : 62

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.55)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.compact ? 16 : 22
                        anchors.rightMargin: root.compact ? 16 : 22
                        spacing: 10

                        WelcomeActionButton {
                            visible: root.currentStep > 0
                            Layout.preferredWidth: 102
                            materialIcon: "arrow_back"
                            label: Translation.tr("Back")
                            onClicked: root.currentStep--
                        }

                        Item { Layout.fillWidth: true }

                        WelcomeActionButton {
                            Layout.preferredWidth: root.currentStep === root.totalSteps - 1 ? 148 : 124
                            primary: true
                            materialIcon: root.currentStep === root.totalSteps - 1 ? "rocket_launch" : "arrow_forward"
                            label: root.currentStep === root.totalSteps - 1 ? Translation.tr("Get Started") : Translation.tr("Continue")
                            onClicked: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP CONTENT COMPONENTS
    // ═══════════════════════════════════════════════════════════════════════

    // First-run choices use tonal selection like the established Material selectors:
    // the whole option changes mass/outline instead of repeating a decorative side rail.
    component WelcomeChoiceRow: RippleButton {
        id: choiceRow

        property string title: ""
        property string detail: ""
        property string symbol: "check"
        property string badge: ""
        property bool selected: false
        property bool compactRow: false

        Layout.fillWidth: true
        implicitHeight: compactRow ? 50 : (detail.length > 0 ? 76 : 52)
        buttonRadius: 14
        colBackground: selected
            ? root.welcomeAccentContainer
            : "transparent"
        colBackgroundHover: selected
            ? root.welcomeAccentHover
            : root.welcomeSurfaceHigh
        colRipple: root.welcomeSurfaceHighest

        contentItem: Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                radius: choiceRow.buttonRadius
                color: "transparent"
                border.width: choiceRow.selected ? 1 : 0
                border.color: ColorUtils.applyAlpha(root.welcomeAccent, 0.58)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 10

                Item {
                    Layout.preferredWidth: choiceRow.compactRow ? 28 : 34
                    Layout.preferredHeight: choiceRow.compactRow ? 28 : 34

                    MaterialCookie {
                        anchors.centerIn: parent
                        visible: choiceRow.selected && !choiceRow.compactRow
                        implicitSize: 32
                        sides: 8
                        color: ColorUtils.applyAlpha(root.welcomeSurfaceHighest, 0.96)
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: choiceRow.symbol
                        iconSize: choiceRow.compactRow ? 17 : 19
                        color: choiceRow.selected ? root.welcomeAccent : root.welcomeOnSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    WelcomeText {
                        Layout.fillWidth: true
                        text: choiceRow.title
                        font.family: root.welcomeFontTitle
                        font.pixelSize: choiceRow.compactRow
                            ? root.welcomeFontBody
                            : choiceRow.selected ? root.welcomeFontSection : root.welcomeFontBody
                        font.weight: choiceRow.selected ? Font.Bold : Font.Medium
                        color: choiceRow.selected ? root.welcomeOnAccentContainer : root.welcomeOnSurface
                        elide: Text.ElideRight
                    }
                    WelcomeText {
                        Layout.fillWidth: true
                        visible: choiceRow.detail.length > 0 && !choiceRow.compactRow
                        text: choiceRow.detail
                        font.pixelSize: root.welcomeFontCaption
                        color: choiceRow.selected
                            ? root.welcomeOnAccentContainer
                            : root.welcomeSecondaryText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    visible: choiceRow.badge.length > 0
                    implicitWidth: badgeText.implicitWidth + 14
                    implicitHeight: 24
                    radius: 12
                    color: root.welcomeGuideContainer

                    WelcomeText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: choiceRow.badge
                        font.pixelSize: root.welcomeFontMeta
                        font.weight: Font.Bold
                        color: root.welcomeGuideText
                    }
                }

                MaterialSymbol {
                    visible: choiceRow.selected
                    text: "check"
                    iconSize: 16
                    color: root.welcomeOnAccentContainer
                }
            }
        }
    }

    component WelcomeContent: Flickable {
        id: welcomeFlickable
        width: root.stepWidth
        contentHeight: welcomeColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 18
        topMargin: Math.max(root.compact ? 8 : 14,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - welcomeColumn.implicitHeight - bottomMargin) / 2)))

        ColumnLayout {
            id: welcomeColumn
            width: parent.width
            spacing: root.compact ? 14 : 18

            GridLayout {
                Layout.fillWidth: true
                columns: welcomeFlickable.width < 720 ? 1 : 2
                columnSpacing: root.compact ? 22 : 34
                rowSpacing: 18

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: welcomeFlickable.width < 720
                        ? welcomeFlickable.width : (welcomeFlickable.width - (root.compact ? 22 : 34)) * 0.43
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: root.compact ? 2 : 6
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            MaterialCookie {
                                implicitSize: root.compact ? 42 : 48
                                sides: 8
                                color: root.welcomeAccentContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "deployed_code"
                                    iconSize: root.compact ? 22 : 25
                                    color: root.welcomeAccent
                                }
                            }

                            WelcomeText {
                                Layout.fillWidth: true
                                text: "iNiR"
                                font.family: root.welcomeFontExpressive
                                font.pixelSize: root.compact ? 42 : 54
                                font.weight: Font.Bold
                                font.letterSpacing: -0.7
                                color: root.welcomeOnSurface
                            }

                            WelcomeText {
                                Layout.fillWidth: true
                                text: Translation.tr("A complete Niri shell with sensible defaults and room to make it yours.")
                                font.pixelSize: root.welcomeFontBody
                                font.weight: Font.Medium
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                            }
                        }

                        MascotImage {
                            id: welcomeMascot
                            previewMode: true
                            pose: "welcome-wave"
                            visible: status === Image.Ready && welcomeFlickable.width >= 720
                            Layout.preferredWidth: visible ? (root.compact ? 142 : 176) : 0
                            Layout.preferredHeight: visible ? (root.compact ? 176 : 214) : 0
                            Layout.alignment: Qt.AlignBottom
                        }

                        Item {
                            visible: welcomeMascot.status !== Image.Ready && welcomeFlickable.width >= 720
                            Layout.preferredWidth: visible ? (root.compact ? 132 : 166) : 0
                            Layout.preferredHeight: visible ? (root.compact ? 162 : 194) : 0
                            Layout.alignment: Qt.AlignBottom

                            MaterialCookie {
                                anchors.centerIn: parent
                                implicitSize: root.compact ? 104 : 126
                                sides: 9
                                color: root.welcomeAccentContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "deployed_code"
                                    iconSize: root.compact ? 42 : 50
                                    color: root.welcomeAccent
                                }
                            }

                            MaterialCookie {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: 8
                                anchors.topMargin: 18
                                implicitSize: 34
                                sides: 7
                                color: ColorUtils.mix(root.welcomeSurfaceHighest, root.welcomeAccentAlt, 0.62)
                            }

                            MaterialCookie {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 10
                                anchors.bottomMargin: 20
                                implicitSize: 24
                                sides: 6
                                color: ColorUtils.applyAlpha(root.welcomeAccent, 0.42)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: root.compact ? 8 : 16
                        spacing: 12
                        Repeater {
                            model: [
                                { icon: "palette", label: Translation.tr("Appearance"), detail: Translation.tr("Style, theme and wallpaper") },
                                { icon: "dashboard", label: Translation.tr("Desktop"), detail: Translation.tr("Family, bar and dock placement") },
                                { icon: "tune", label: Translation.tr("Essentials"), detail: Translation.tr("Effects and useful defaults") }
                            ]
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 10
                                MaterialSymbol {
                                    Layout.preferredWidth: 24
                                    text: modelData.icon
                                    iconSize: 18
                                    color: root.welcomeAccent
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    WelcomeText {
                                        text: modelData.label
                                        font.pixelSize: root.welcomeFontBody
                                        font.weight: Font.DemiBold
                                        color: root.welcomeOnSurface
                                    }
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: modelData.detail
                                        font.pixelSize: root.welcomeFontCaption
                                        color: root.welcomeSecondaryText
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                PanelSurface {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: welcomeFlickable.width < 720
                        ? welcomeFlickable.width : (welcomeFlickable.width - (root.compact ? 22 : 34)) * 0.57
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: welcomeSetupColumn.implicitHeight + 28
                    surfaceDialect: "material"
                    elevation: 2
                    outlined: false
                    radiusOverride: 16

                    ColumnLayout {
                        id: welcomeSetupColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialCookie {
                                implicitSize: 34
                                sides: 8
                                color: root.welcomeAccentContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "tune"
                                    iconSize: 17
                                    color: root.welcomeAccent
                                }
                            }
                            WelcomeText {
                                text: Translation.tr("Settings view")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: root.welcomeFontSection
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                        }

                        WelcomeText {
                            Layout.fillWidth: true
                            text: Translation.tr("Focused keeps everyday pages up front. Complete shows everything.")
                            font.pixelSize: root.welcomeFontCaption
                            color: root.welcomeSecondaryText
                            wrapMode: Text.WordWrap
                        }

                        WelcomeChoiceRow {
                            title: Translation.tr("Focused")
                            detail: Translation.tr("Everyday settings, with advanced pages out of the way.")
                            symbol: "school"
                            selected: (Config.options?.settingsUi?.easyMode ?? false) === true
                            onClicked: Config.setNestedValue("settingsUi.easyMode", true)
                        }

                        WelcomeChoiceRow {
                            title: Translation.tr("Complete")
                            detail: Translation.tr("All settings pages and advanced controls.")
                            symbol: "tune"
                            selected: (Config.options?.settingsUi?.easyMode ?? false) === false
                            onClicked: Config.setNestedValue("settingsUi.easyMode", false)
                        }

                        Item {
                            Layout.fillHeight: true
                            Layout.minimumHeight: 4
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            WelcomeText {
                                text: Translation.tr("Up next")
                                font.pixelSize: root.welcomeFontMeta
                                font.weight: Font.DemiBold
                                color: root.welcomeSecondaryText
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 20
                                color: ColorUtils.applyAlpha(root.welcomeOutline, 0.42)
                            }

                            Repeater {
                                model: root.steps.slice(1, 4)
                                RowLayout {
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6

                                    WelcomeText {
                                        text: String(index + 2).padStart(2, "0")
                                        font.family: root.welcomeFontNumbers
                                        font.pixelSize: root.welcomeFontMeta
                                        font.weight: Font.DemiBold
                                        color: root.welcomeAccent
                                    }
                                    MaterialSymbol {
                                        text: modelData.icon
                                        iconSize: 16
                                        color: root.welcomeSecondaryText
                                    }
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        font.pixelSize: root.welcomeFontCaption
                                        font.weight: Font.Medium
                                        color: root.welcomeOnSurface
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component ThemeContent: Flickable {
        id: themeFlickable
        width: root.stepWidth
        contentHeight: themeColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 6 : 10,
            Math.min(root.compact ? 18 : 24,
                Math.round((height - themeColumn.implicitHeight - bottomMargin) / 2)))

        GridLayout {
            id: themeColumn
            width: parent.width
            columns: themeFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 20 : 28
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: themeFlickable.width < 760
                    ? themeFlickable.width : (themeFlickable.width - (root.compact ? 20 : 28)) * 0.34
                Layout.alignment: Qt.AlignTop
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol { text: "auto_awesome"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Style")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 3
                    text: Translation.tr("Choose the look for the whole shell.")
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 2

                    Repeater {
                        model: root.stylePresets
                        WelcomeChoiceRow {
                            required property var modelData
                            compactRow: true
                            title: modelData.name
                            symbol: modelData.icon
                            selected: root.effectiveStylePreset === modelData.id
                            onClicked: root.applyStylePreset(modelData.id)
                        }
                    }
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: themeFlickable.width < 760
                    ? themeFlickable.width : (themeFlickable.width - (root.compact ? 20 : 28)) * 0.66
                Layout.alignment: Qt.AlignTop
                implicitHeight: appearanceColumn.implicitHeight + 28
                surfaceDialect: "material"
                elevation: 2
                outlined: false
                radiusOverride: 16

                ColumnLayout {
                    id: appearanceColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: root.compact ? 9 : 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialCookie {
                            implicitSize: 38
                            sides: 8
                            color: root.welcomeAccentContainer
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.currentStylePreset.icon
                                iconSize: 19
                                color: root.welcomeAccent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            WelcomeText {
                                text: root.effectiveStylePreset === "custom"
                                    ? Translation.tr("Custom style") : root.currentStylePreset.name
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: root.currentStylePresetDescription
                                font.pixelSize: root.welcomeFontCaption
                                font.weight: Font.Medium
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            visible: root.effectiveStylePreset === "material"
                            implicitWidth: recommendedStyleLabel.implicitWidth + 14
                            implicitHeight: 22
                            radius: 11
                            color: ColorUtils.mix(root.welcomeSurfaceHighest, root.welcomeAccentAlt, 0.62)

                            WelcomeText {
                                id: recommendedStyleLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Recommended")
                                font.pixelSize: root.welcomeFontMeta
                                font.weight: Font.Bold
                                color: ColorUtils.ensureReadable(root.welcomeOnSurface, parent.color, 4.5)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        LightDarkPreferenceButton { dark: false }
                        LightDarkPreferenceButton { dark: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                    }

                    ColumnLayout {
                        id: wallpaperGroup
                        Layout.fillWidth: true
                        spacing: 7

                        property var wallpapersList: []
                        readonly property string wallpapersPath: Directories.wallpapersPath
                        readonly property real itemWidth: root.compact ? 156 : 180
                        readonly property real itemHeight: root.compact ? 88 : 100

                        Component.onCompleted: wallpaperScanProc.running = true

                        Process {
                            id: wallpaperScanProc
                            command: ["/bin/sh", "-c", `find '${wallpaperGroup.wallpapersPath}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \\) -printf '%C@\\t%p\\n' 2>/dev/null`]
                            stdout: SplitParser {
                                splitMarker: ""
                                onRead: data => {
                                    const lines = data.trim().split("\n").filter(l => l.length > 0)
                                    lines.sort((a, b) => parseFloat(b.split("\t")[0]) - parseFloat(a.split("\t")[0]))
                                    wallpaperGroup.wallpapersList = lines.map(l => l.split("\t")[1]).filter(p => p && p.length > 0)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            MaterialSymbol { text: "wallpaper"; iconSize: 17; color: root.welcomeAccent }
                            WelcomeText {
                                text: Translation.tr("Wallpaper")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            Item { Layout.fillWidth: true }
                            WelcomeText {
                                text: Translation.tr("Colors update automatically")
                                color: root.welcomeSecondaryText
                                font.pixelSize: root.welcomeFontMeta
                            }
                        }

                ListView {
                    id: wallpaperCarousel
                    Layout.fillWidth: true
                    Layout.preferredHeight: wallpaperGroup.itemHeight
                    visible: wallpaperGroup.wallpapersList.length > 0
                    orientation: ListView.Horizontal
                    spacing: 7
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: wallpaperGroup.wallpapersList

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            wallpaperCarousel.contentX = Math.max(0, Math.min(
                                wallpaperCarousel.contentWidth - wallpaperCarousel.width,
                                wallpaperCarousel.contentX - delta
                            ))
                        }
                    }

                    delegate: Item {
                        id: wpDelegate
                        required property int index
                        required property string modelData
                        readonly property string filePath: modelData
                        readonly property bool isCurrentWallpaper: (Config.options?.background?.wallpaperPath ?? "") === filePath
                        readonly property bool isHovered: wpMouseArea.containsMouse

                        width: wallpaperGroup.itemWidth
                        height: wallpaperGroup.itemHeight

                        PanelSurface {
                            id: wpThumb
                            anchors.fill: parent
                            surfaceDialect: "material"
                                    elevation: 1
                            cardStyle: true
                            outlined: wpDelegate.isCurrentWallpaper
                            borderWidthOverride: wpDelegate.isCurrentWallpaper ? 2 : 0
                                    radiusOverride: 12
                            clipContent: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: wpDelegate.isCurrentWallpaper ? 3 : 0
                                source: wpDelegate.filePath ? `file://${wpDelegate.filePath}` : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize.width: Math.round(wallpaperGroup.itemWidth * 2.25)
                                sourceSize.height: Math.round(wallpaperGroup.itemHeight * 2.25)
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: wpDelegate.isHovered && !wpDelegate.isCurrentWallpaper ? "#36000000" : "transparent"
                            }

                                    Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                        anchors.margins: 6
                                visible: wpDelegate.isCurrentWallpaper
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: root.welcomeAccent
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "check"
                                            iconSize: 14
                                            color: root.welcomeOnAccent
                                        }
                            }

                            MouseArea {
                                id: wpMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpapers.select(wpDelegate.filePath)
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: wallpaperGroup.itemHeight
                    visible: wallpaperGroup.wallpapersList.length === 0
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "image"; iconSize: 20; color: root.welcomeOnSurfaceVariant }
                        WelcomeText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("No wallpapers found in ~/Pictures/Wallpapers").replace("~/Pictures/Wallpapers", Directories.shortHomePath(Directories.wallpapersPath))
                            color: root.welcomeSecondaryText
                            font.pixelSize: root.welcomeFontMeta
                        }
                    }
                }
            }
                }
            }
        }
    }

    component LayoutContent: Flickable {
        id: layoutFlickable
        width: root.stepWidth
        contentHeight: layoutColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - layoutColumn.implicitHeight - bottomMargin) / 2)))

        GridLayout {
            id: layoutColumn
            width: parent.width
            columns: layoutFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 22 : 30
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: layoutFlickable.width < 760
                    ? layoutFlickable.width : (layoutFlickable.width - (root.compact ? 22 : 30)) * 0.42
                Layout.alignment: Qt.AlignTop
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol { text: "dashboard"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Shell family")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Choose the shell family that matches how you want the desktop to work.")
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                }

                WelcomeChoiceRow {
                    title: "Material II"
                    detail: Translation.tr("M3 bar, dock and sidebars with shared Material controls.")
                    symbol: "dashboard"
                    selected: (Config.options?.panelFamily ?? "ii") === "ii"
                    badge: Translation.tr("Default")
                    onClicked: root.setProfileFeature("panelFamily", "ii")
                }

                WelcomeChoiceRow {
                    title: "Waffle"
                    detail: Translation.tr("Taskbar, Start menu and Action Center.")
                    symbol: "grid_view"
                    selected: (Config.options?.panelFamily ?? "ii") === "waffle"
                    onClicked: root.setProfileFeature("panelFamily", "waffle")
                }

                WelcomeChoiceRow {
                    title: "iRiS"
                    detail: Translation.tr("Minimal bar, Palette and controls with the lowest idle footprint.")
                    symbol: "visibility"
                    selected: (Config.options?.panelFamily ?? "ii") === "iris"
                    onClicked: root.setProfileFeature("panelFamily", "iris")
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: layoutFlickable.width < 760
                    ? layoutFlickable.width : (layoutFlickable.width - (root.compact ? 22 : 30)) * 0.58
                Layout.alignment: Qt.AlignTop
                implicitHeight: Math.max(placementColumn.implicitHeight + 28, root.compact ? 300 : 330)
                surfaceDialect: "material"
                elevation: 2
                outlined: false
                radiusOverride: 16

                ColumnLayout {
                    id: placementColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialCookie {
                            implicitSize: 34
                            sides: 8
                            color: root.welcomeAccentContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "view_compact"
                                iconSize: 17
                                color: root.welcomeAccent
                            }
                        }
                        WelcomeText {
                            text: Translation.tr("Placement")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        WelcomeText {
                            text: Translation.tr("Bar position")
                            font.pixelSize: root.welcomeFontBody
                            font.weight: Font.Medium
                            color: root.welcomeOnSurface
                        }
                        WelcomeSegmentedControl {
                            Layout.fillWidth: true
                            currentValue: (Config.options?.bar?.bottom ?? false) ? "bottom" : "top"
                            options: [
                                { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                                { displayName: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" }
                            ]
                            onSelected: value => root.setProfileFeature("bar.bottom", value === "bottom")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        WelcomeText {
                            text: Translation.tr("Dock position")
                            font.pixelSize: root.welcomeFontBody
                            font.weight: Font.Medium
                            color: root.welcomeOnSurface
                        }
                        WelcomeSegmentedControl {
                            Layout.fillWidth: true
                            currentValue: Config.options?.dock?.position ?? "bottom"
                            options: [
                                { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: "bottom" },
                                { displayName: Translation.tr("Left"), icon: "arrow_back", value: "left" },
                                { displayName: Translation.tr("Right"), icon: "arrow_forward", value: "right" }
                            ]
                            onSelected: value => root.setProfileFeature("dock.position", value)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.minimumHeight: 6
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (Config.options?.panelFamily ?? "ii") === "ii"
                            && (Config.options?.bar?.appearanceStyle ?? "m3") === "m3"
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol {
                                text: "side_navigation"
                                iconSize: 18
                                color: root.welcomeAccent
                            }
                            WelcomeText {
                                text: Translation.tr("Sidebar access")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: root.welcomeFontSection
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            Item { Layout.fillWidth: true }
                            WelcomeText {
                                text: Translation.tr("M3 bar")
                                font.pixelSize: root.welcomeFontMeta
                                font.weight: Font.Bold
                                color: root.welcomeAccentAlt
                            }
                        }

                        WelcomeText {
                            Layout.fillWidth: true
                            text: Translation.tr("A sidebar button stays at each outer edge of the bar.")
                            font.pixelSize: root.welcomeFontCaption
                            color: root.welcomeSecondaryText
                            wrapMode: Text.WordWrap
                        }

                        PanelSurface {
                            Layout.fillWidth: true
                            implicitHeight: 116
                            surfaceDialect: "material"
                            elevation: 1
                            outlined: false
                            radiusOverride: 14

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    WelcomeText {
                                        text: Translation.tr("Edge controls")
                                        font.pixelSize: root.welcomeFontMeta
                                        font.weight: Font.DemiBold
                                        color: root.welcomeSecondaryText
                                    }

                                    Item { Layout.fillWidth: true }

                                    WelcomeText {
                                        text: "M3 · COMPACT"
                                        font.family: root.welcomeFontNumbers
                                        font.pixelSize: root.welcomeFontMeta
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.7
                                        color: root.welcomeAccentAlt
                                    }
                                }

                                PanelSurface {
                                    Layout.fillWidth: true
                                    implicitHeight: 52
                                    surfaceDialect: "material"
                                    elevation: 2
                                    island: true
                                    outlined: false
                                    radiusOverride: 18

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 7
                                        anchors.rightMargin: 7
                                        spacing: 7

                                        PanelSurface {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            Layout.alignment: Qt.AlignVCenter
                                            surfaceDialect: "material"
                                            elevation: 3
                                            island: true
                                            outlined: false

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "left_panel_open"
                                                iconSize: 20
                                                color: root.welcomeAccent
                                            }
                                        }

                                        RowLayout {
                                            spacing: 4
                                            Layout.alignment: Qt.AlignVCenter

                                            Rectangle {
                                                implicitWidth: 18
                                                implicitHeight: 8
                                                radius: 4
                                                color: root.welcomeAccent
                                            }
                                            Rectangle {
                                                implicitWidth: 8
                                                implicitHeight: 8
                                                radius: 4
                                                color: ColorUtils.applyAlpha(root.welcomeOnSurfaceVariant, 0.34)
                                            }
                                            Rectangle {
                                                implicitWidth: 8
                                                implicitHeight: 8
                                                radius: 4
                                                color: ColorUtils.applyAlpha(root.welcomeOnSurfaceVariant, 0.34)
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        PanelSurface {
                                            Layout.preferredWidth: 156
                                            Layout.preferredHeight: 34
                                            Layout.alignment: Qt.AlignVCenter
                                            surfaceDialect: "material"
                                            elevation: 3
                                            island: true
                                            outlined: false

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Repeater {
                                                    model: ["folder", "terminal", "language", "music_note"]
                                                    MaterialSymbol {
                                                        required property string modelData
                                                        text: modelData
                                                        iconSize: 16
                                                        color: root.welcomeOnSurfaceVariant
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        RowLayout {
                                            spacing: 4
                                            Layout.alignment: Qt.AlignVCenter
                                            MaterialSymbol {
                                                text: "wifi"
                                                iconSize: 15
                                                color: root.welcomeOnSurfaceVariant
                                            }
                                            MaterialSymbol {
                                                text: "volume_up"
                                                iconSize: 15
                                                color: root.welcomeOnSurfaceVariant
                                            }
                                        }

                                        PanelSurface {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            Layout.alignment: Qt.AlignVCenter
                                            surfaceDialect: "material"
                                            elevation: 3
                                            island: true
                                            outlined: false

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "right_panel_open"
                                                iconSize: 20
                                                color: root.welcomeAccent
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    RowLayout {
                                        spacing: 5
                                        MaterialSymbol {
                                            text: "left_panel_open"
                                            iconSize: 14
                                            color: root.welcomeAccent
                                        }
                                        WelcomeText {
                                            text: Translation.tr("Left sidebar")
                                            font.pixelSize: root.welcomeFontMeta
                                            font.weight: Font.Medium
                                            color: root.welcomeOnSurface
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    RowLayout {
                                        spacing: 5
                                        WelcomeText {
                                            text: Translation.tr("Right sidebar")
                                            font.pixelSize: root.welcomeFontMeta
                                            font.weight: Font.Medium
                                            color: root.welcomeOnSurface
                                        }
                                        MaterialSymbol {
                                            text: "right_panel_open"
                                            iconSize: 14
                                            color: root.welcomeAccent
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (Config.options?.panelFamily ?? "ii") === "ii"
                            && (Config.options?.bar?.appearanceStyle ?? "m3") !== "m3"
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol {
                                text: "side_navigation"
                                iconSize: 18
                                color: root.welcomeAccentAlt
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: Translation.tr("Sidebar access")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: root.welcomeFontSection
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                text: String(Config.options?.bar?.appearanceStyle ?? "m3").toUpperCase()
                                font.family: root.welcomeFontNumbers
                                font.pixelSize: root.welcomeFontMeta
                                font.weight: Font.Bold
                                color: root.welcomeAccentAlt
                            }
                        }

                        PanelSurface {
                            Layout.fillWidth: true
                            implicitHeight: 82
                            surfaceDialect: "material"
                            elevation: 1
                            outlined: false
                            radiusOverride: 14

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                MaterialCookie {
                                    implicitSize: 42
                                    sides: 7
                                    color: ColorUtils.mix(root.welcomeSurfaceHighest, root.welcomeAccentAlt, 0.62)
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "visibility"
                                        iconSize: 20
                                        color: root.welcomeAccentAlt
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("Sidebars stay available")
                                        font.family: root.welcomeFontTitle
                                        font.pixelSize: root.welcomeFontBody
                                        font.weight: Font.Bold
                                        color: root.welcomeOnSurface
                                    }
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("This bar style uses its own controls; your sidebars remain available.")
                                        font.pixelSize: root.welcomeFontCaption
                                        color: root.welcomeSecondaryText
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component FeaturesContent: Flickable {
        id: featuresFlickable
        width: root.stepWidth
        contentHeight: featuresColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - featuresColumn.implicitHeight - bottomMargin) / 2)))

        readonly property var profileHighlights: root.selectedProfile === "minimum" ? [
            { value: "M3", label: Translation.tr("compact bar") },
            { value: "2", label: Translation.tr("sidebars") },
            { value: "4", label: Translation.tr("quick toggles") },
            { value: "0", label: Translation.tr("desktop widgets") }
        ] : root.selectedProfile === "full" ? [
            { value: "M3+", label: Translation.tr("bar + media") },
            { value: "2", label: Translation.tr("full sidebars") },
            { value: "8", label: Translation.tr("quick toggles") },
            { value: "2", label: Translation.tr("desktop widgets") }
        ] : [
            { value: "M3", label: Translation.tr("bar + dock") },
            { value: "2", label: Translation.tr("sidebars") },
            { value: "8", label: Translation.tr("quick toggles") },
            { value: "1", label: Translation.tr("desktop clock") }
        ]

        GridLayout {
            id: featuresColumn
            width: parent.width
            columns: featuresFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 22 : 30
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: featuresFlickable.width < 760
                    ? featuresFlickable.width : (featuresFlickable.width - (root.compact ? 22 : 30)) * 0.38
                Layout.alignment: Qt.AlignTop
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol { text: "tune"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Base setup")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Choose how much iNiR sets up for your first session.")
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                }

                WelcomeChoiceRow {
                    title: Translation.tr("Minimum")
                    detail: Translation.tr("Core controls with no desktop widgets.")
                    symbol: "filter_1"
                    selected: !root.profileCustomized && root.selectedProfile === "minimum"
                    onClicked: root.applyProfile("minimum")
                }

                WelcomeChoiceRow {
                    title: Translation.tr("Balanced")
                    detail: Translation.tr("Sidebars, daily toggles and a desktop clock.")
                    symbol: "tune"
                    badge: Translation.tr("Recommended")
                    selected: !root.profileCustomized && root.selectedProfile === "balanced"
                    onClicked: root.applyProfile("balanced")
                }

                WelcomeChoiceRow {
                    title: Translation.tr("Full")
                    detail: Translation.tr("More local tools, fuller sidebars and a system monitor.")
                    symbol: "auto_awesome"
                    selected: !root.profileCustomized && root.selectedProfile === "full"
                    onClicked: root.applyProfile("full")
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: featuresFlickable.width < 760
                    ? featuresFlickable.width : (featuresFlickable.width - (root.compact ? 22 : 30)) * 0.62
                Layout.alignment: Qt.AlignTop
                implicitHeight: Math.max(profileSummaryColumn.implicitHeight + 28, root.compact ? 300 : 330)
                surfaceDialect: "material"
                elevation: 2
                outlined: false
                radiusOverride: 16

                ColumnLayout {
                    id: profileSummaryColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialCookie {
                            implicitSize: 38
                            sides: 8
                            color: root.welcomeAccentContainer
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.selectedProfile === "minimum" ? "filter_1"
                                    : root.selectedProfile === "full" ? "auto_awesome" : "tune"
                                iconSize: 19
                                color: root.welcomeAccent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            WelcomeText {
                                text: root.profileCustomized
                                    ? Translation.tr("Custom setup") : root.selectedProfileTitle
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: root.selectedProfileDescription
                                font.pixelSize: root.welcomeFontCaption
                                font.weight: Font.Medium
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 2
                        Repeater {
                            model: featuresFlickable.profileHighlights
                            WelcomeMetric {
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                value: modelData.value
                                label: modelData.label
                                accent: index % 2 === 0 ? root.welcomeAccent : root.welcomeAccentAlt
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.minimumHeight: 4
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol { text: "speed"; iconSize: 18; color: root.welcomeAccent }
                        WelcomeText {
                            text: Translation.tr("Effects")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        Item { Layout.fillWidth: true }
                        WelcomeText {
                            text: root.effectivePerformancePreset === "custom"
                                ? Translation.tr("Custom") : root.currentPerformancePreset.name
                            font.pixelSize: root.welcomeFontMeta
                            color: root.welcomeSecondaryText
                        }
                    }

                    WelcomeSegmentedControl {
                        Layout.fillWidth: true
                        currentValue: root.effectivePerformancePreset
                        options: root.performancePresets.map(preset => ({
                            displayName: preset.name,
                            icon: preset.icon,
                            value: preset.id
                        }))
                        onSelected: value => root.applyPerformancePreset(value)
                    }

                    WelcomeText {
                        Layout.fillWidth: true
                        text: root.currentPerformancePresetDescription
                        font.pixelSize: root.welcomeFontCaption
                        color: root.welcomeSecondaryText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component ReadyContent: Flickable {
        id: readyFlickable
        width: root.stepWidth
        contentHeight: readyColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 12
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 12 : 16,
                Math.round((height - readyColumn.implicitHeight - bottomMargin) / 2)))

        ColumnLayout {
            id: readyColumn
            width: parent.width
            spacing: root.compact ? 10 : 14

            PanelSurface {
                Layout.fillWidth: true
                implicitHeight: readySummaryColumn.implicitHeight + 24
                surfaceDialect: "material"
                elevation: 2
                outlined: false
                radiusOverride: 16

                ColumnLayout {
                    id: readySummaryColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        MaterialCookie {
                            implicitSize: 46
                            sides: 8
                            color: root.welcomeAccentContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 24
                                color: root.welcomeAccent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            WelcomeText {
                                text: Translation.tr("Setup ready")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.large * 1.08
                                font.weight: Font.DemiBold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: Translation.tr("You can change any of this later in Settings.")
                                font.pixelSize: root.welcomeFontCaption
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                            }
                        }

                        MascotImage {
                            previewMode: true
                            pose: "about-confident"
                            visible: status === Image.Ready && readyFlickable.width >= 720
                            Layout.preferredWidth: visible ? 80 : 0
                            Layout.preferredHeight: visible ? 90 : 0
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.32)
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: readyFlickable.width < 720 ? 2 : 4
                        columnSpacing: 18
                        rowSpacing: 8

                        Repeater {
                            model: [
                                { icon: "tune", label: Translation.tr("Starting point"), value: root.selectedProfileTitle },
                                { icon: "palette", label: Translation.tr("Style"), value: root.effectiveStylePreset === "custom" ? Translation.tr("Custom") : root.currentStylePreset.name },
                                { icon: "dashboard", label: Translation.tr("Family"), value: (Config.options?.panelFamily ?? "ii") === "waffle" ? "Waffle" : (Config.options?.panelFamily ?? "ii") === "iris" ? "iRiS" : "Material II" },
                                { icon: "speed", label: Translation.tr("Effects"), value: root.effectivePerformancePreset === "custom" ? Translation.tr("Custom") : root.currentPerformancePreset.name }
                            ]

                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8
                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: 17
                                    color: root.welcomeAccent
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    WelcomeText {
                                        text: modelData.label
                                        font.pixelSize: root.welcomeFontMeta
                                        color: root.welcomeSecondaryText
                                    }
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        font.pixelSize: root.welcomeFontCaption
                                        font.weight: Font.DemiBold
                                        color: root.welcomeOnSurface
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Two task columns use the full content field. Like Dashboard, each
            // column owns one semantic group instead of stacking decorative cards.
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                columns: readyFlickable.width < 760 ? 1 : 2
                columnSpacing: root.compact ? 10 : 14
                rowSpacing: root.compact ? 10 : 14

                // Keyboard shortcuts card
                PanelSurface {
                    Layout.fillWidth: true
                    Layout.preferredWidth: readyFlickable.width < 760 ? readyFlickable.width : 420
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: shortcutsCardCol.implicitHeight + 20
                    surfaceDialect: "material"
                    elevation: 1
                    outlined: false
                    radiusOverride: 16

                    ColumnLayout {
                        id: shortcutsCardCol
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 8

                        RowLayout {
                            spacing: 8
                            MaterialSymbol { text: "keyboard"; iconSize: 18; color: root.welcomeAccent }
                            WelcomeText {
                                text: Translation.tr("Keyboard")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                            }
                            Item { Layout.fillWidth: true }
                            WelcomeText {
                                text: Translation.tr("Full list: Super+/")
                                font.pixelSize: root.welcomeFontMeta
                                color: root.welcomeSecondaryText
                            }
                        }

                        Repeater {
                            model: [
                                { keys: "Super+/",     desc: Translation.tr("All shortcuts") },
                                { keys: "Super+Space", desc: Translation.tr("App launcher") },
                                { keys: "Super+,",     desc: Translation.tr("Settings") },
                                { keys: "Super+V",     desc: Translation.tr("Clipboard history") }
                            ]
                            RowLayout {
                                Layout.fillWidth: true
                                required property var modelData
                                spacing: 10

                                Row {
                                    Layout.preferredWidth: root.compact ? 138 : 154
                                    spacing: 2
                                    Repeater {
                                        model: modelData.keys.split("+")
                                        WelcomeKey {
                                            required property string modelData
                                            key: modelData
                                        }
                                    }
                                }
                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: modelData.desc
                                    font.pixelSize: root.welcomeFontCaption
                                    color: root.welcomeSecondaryText
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                        }
                    }
                }

                // Try it now — interactive action card
                PanelSurface {
                    Layout.fillWidth: true
                    Layout.preferredWidth: readyFlickable.width < 760 ? readyFlickable.width : 580
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: tryItCardCol.implicitHeight + 20
                    surfaceDialect: "material"
                    elevation: 2
                    outlined: false
                    radiusOverride: 16

                    ColumnLayout {
                        id: tryItCardCol
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol { text: "rocket_launch"; iconSize: 18; color: root.welcomeAccent }
                            WelcomeText {
                                text: Translation.tr("Quick actions")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Repeater {
                            model: [
                                {
                                    icon: "tune",
                                    label: Translation.tr("Open quick settings"),
                                    sub: Translation.tr("Network, audio and brightness"),
                                    target: "controlPanel",
                                    fn: "toggle"
                                },
                                {
                                    icon: "wallpaper",
                                    label: Translation.tr("Pick a wallpaper"),
                                    sub: Translation.tr("Choose a background"),
                                    target: "wallpaperSelector",
                                    fn: "toggle"
                                },
                                {
                                    icon: "keyboard",
                                    label: Translation.tr("Show all shortcuts"),
                                    sub: Translation.tr("Open the full shortcut list"),
                                    target: "cheatsheet",
                                    fn: "toggle"
                                }
                            ]
                            WelcomeListAction {
                                Layout.fillWidth: true
                                required property var modelData
                                materialIcon: modelData.icon
                                title: modelData.label
                                subtitle: modelData.sub

                                onClicked: Quickshell.execDetached([
                                    Quickshell.shellPath("scripts/inir"),
                                    modelData.target,
                                    modelData.fn
                                ])
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 6

                Item { Layout.fillWidth: true }

                WelcomeActionButton {
                    materialIcon: "settings"
                    label: Translation.tr("Settings")
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                }

                WelcomeActionButton {
                    materialIcon: "open_in_new"
                    label: Translation.tr("Troubleshoot")
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/wiki/Troubleshooting")
                }

                WelcomeActionButton {
                    materialIcon: "menu_book"
                    label: Translation.tr("Docs")
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/wiki")
                }

                WelcomeActionButton {
                    materialIcon: "bug_report"
                    label: Translation.tr("Report")
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/issues")
                }
            }

            Item { Layout.preferredHeight: 2 }
        }
    }
}
