pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root

    required property real availableWidth
    required property real availableHeight
    property bool libraryOpen: false
    property string outputName: ""
    property bool hasSelection: false
    property bool gridExpanded: false
    property bool attachedTopEdge: false

    signal libraryRequested()
    signal settingsRequested()
    signal edgeSettingsRequested()
    signal doneRequested()

    readonly property int gridSize: Config.getNestedValue("background.widgets.editGrid.size", 32)
    readonly property bool snap: Config.getNestedValue("background.widgets.editGrid.snap", true)
    readonly property bool compact: availableWidth < 760
    readonly property int railItemStride: 34
    readonly property int railSlots: Math.max(3, Math.min(12,
        Math.floor(Math.max(railStride * 3, availableWidth - 390) / railStride)))
    readonly property real railWidth: railSlots * railStride
    readonly property var builtinWidgets: [
        { key: "weather", icon: "cloud", label: "Weather", defaultOn: false },
        { key: "customImage", icon: "add_photo_alternate", label: "Custom Image", defaultOn: false },
        { key: "imageConverter", icon: "transform", label: "Image Converter", defaultOn: false },
        { key: "clock", icon: "schedule", label: "Clock", defaultOn: true },
        { key: "mediaControls", icon: "album", label: "Media", defaultOn: false },
        { key: "japaneseTypography", icon: "translate", label: "Japanese Typography", defaultOn: false },
        { key: "visualizer", icon: "graphic_eq", label: "Visualizer", defaultOn: false },
        { key: "systemMonitor", icon: "monitor_heart", label: "System Monitor", defaultOn: false },
        { key: "battery", icon: "battery_full", label: "Battery", defaultOn: false },
        { key: "notes", icon: "sticky_note_2", label: "Notes", defaultOn: false },
        { key: "calendarUpcoming", icon: "event", label: "Upcoming Events", defaultOn: false },
        { key: "monthCalendar", icon: "calendar_month", label: "Month Calendar", defaultOn: false },
        { key: "todo", icon: "checklist", label: "Todo", defaultOn: false },
        { key: "timers", icon: "timer", label: "Timers", defaultOn: false },
        { key: "dayProgress", icon: "timelapse", label: "Day progress", defaultOn: false },
        { key: "uptime", icon: "avg_pace", label: "System Uptime", defaultOn: false },
        { key: "shape", icon: "category", label: "Decorative Shape", defaultOn: false },
        { key: "dateBadge", icon: "today", label: "Date Badge", defaultOn: false },
        { key: "editorial", icon: "text_fields", label: "Editorial", defaultOn: false },
        { key: "mascot", icon: "pets", label: "Mascot", defaultOn: false },
        { key: "newsTicker", icon: "newspaper", label: "News Ticker", defaultOn: false },
        { key: "worldClock", icon: "public", label: "World Clock", defaultOn: false },
        { key: "userCard", icon: "account_circle", label: "User Card", defaultOn: false }
    ]

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    // iRiS category tints (the fixed palette notification tiles use).
    readonly property var irisTints: ({
        weather: "#0a84ff", clock: "#ff9f0a", worldClock: "#ff9f0a", dayProgress: "#ff9f0a", uptime: "#5e5ce6",
        mediaControls: "#ff375f", visualizer: "#bf5af2", systemMonitor: "#34c759", battery: "#34c759",
        notes: "#ffcc00", calendarUpcoming: "#ff3b30", monthCalendar: "#ff3b30", dateBadge: "#ff3b30",
        todo: "#ff9f0a", timers: "#ff9f0a", newsTicker: "#30b0c7", userCard: "#0a84ff",
        customImage: "#30b0c7", imageConverter: "#30b0c7", japaneseTypography: "#bf5af2",
        editorial: "#8e8e93", shape: "#bf5af2", mascot: "#ff375f"
    })
    readonly property real railStride: root.iris ? 40 : root.railItemStride
    readonly property real bodyHeight: root.iris ? 60 : 48
    readonly property real bodyRadius: root.iris ? Math.min(IrisStyle.radius, root.bodyHeight / 2) : 0
    readonly property real fillet: root.iris ? Math.round(root.bodyRadius * 0.62) : 0
    readonly property string inwardTooltipPosition: root.attachedTopEdge ? "bottom" : "top"
    readonly property real bodyWidth: root.iris
        ? Math.min(Math.max(280, availableWidth - 2 * root.fillet),
            Math.max(320, toolbarRow.implicitWidth + 20))
        : Math.min(availableWidth, Math.max(320, toolbarRow.implicitWidth + 12))
    width: root.bodyWidth + (root.iris ? 2 * root.fillet : 0)
    height: root.bodyHeight

    Item {
        id: bodyFrame
        x: root.iris ? root.fillet : 0
        width: root.bodyWidth
        height: root.height
    }

    Toolbar {
        anchors.fill: bodyFrame
        padding: 6
        spacing: 4
        transparent: root.iris
        screenX: root.x
        screenY: root.y
    }

    // iRiS editing replaces the Dock with an edge-attached notch. Keep body and
    // concave fillets in one path so the join reads as one Dynamic Island
    // surface instead of a floating pill with decorative corners.
    Shape {
        id: irisNotchSilhouette
        anchors.fill: parent
        visible: root.iris
        preferredRendererType: Shape.CurveRenderer
        readonly property bool flip: !root.attachedTopEdge
        readonly property real f: root.fillet
        readonly property real r: Math.min(root.bodyRadius, root.height, root.bodyWidth / 2)
        readonly property real edgeL: root.fillet
        readonly property real edgeR: root.fillet + root.bodyWidth
        readonly property real far: root.height
        function ey(v: real): real { return irisNotchSilhouette.flip ? root.height - v : v }
        readonly property int outward: irisNotchSilhouette.flip ? PathArc.Counterclockwise : PathArc.Clockwise
        readonly property int inward: irisNotchSilhouette.flip ? PathArc.Clockwise : PathArc.Counterclockwise

        ShapePath {
            strokeWidth: -1
            fillColor: IrisStyle.surface
            startX: irisNotchSilhouette.edgeL - irisNotchSilhouette.f
            startY: irisNotchSilhouette.ey(0)
            PathArc {
                x: irisNotchSilhouette.edgeL
                y: irisNotchSilhouette.ey(irisNotchSilhouette.f)
                radiusX: irisNotchSilhouette.f
                radiusY: irisNotchSilhouette.f
                direction: irisNotchSilhouette.outward
            }
            PathLine {
                x: irisNotchSilhouette.edgeL
                y: irisNotchSilhouette.ey(irisNotchSilhouette.far - irisNotchSilhouette.r)
            }
            PathArc {
                x: irisNotchSilhouette.edgeL + irisNotchSilhouette.r
                y: irisNotchSilhouette.ey(irisNotchSilhouette.far)
                radiusX: irisNotchSilhouette.r
                radiusY: irisNotchSilhouette.r
                direction: irisNotchSilhouette.inward
            }
            PathLine {
                x: irisNotchSilhouette.edgeR - irisNotchSilhouette.r
                y: irisNotchSilhouette.ey(irisNotchSilhouette.far)
            }
            PathArc {
                x: irisNotchSilhouette.edgeR
                y: irisNotchSilhouette.ey(irisNotchSilhouette.far - irisNotchSilhouette.r)
                radiusX: irisNotchSilhouette.r
                radiusY: irisNotchSilhouette.r
                direction: irisNotchSilhouette.inward
            }
            PathLine {
                x: irisNotchSilhouette.edgeR
                y: irisNotchSilhouette.ey(irisNotchSilhouette.f)
            }
            PathArc {
                x: irisNotchSilhouette.edgeR + irisNotchSilhouette.f
                y: irisNotchSilhouette.ey(0)
                radiusX: irisNotchSilhouette.f
                radiusY: irisNotchSilhouette.f
                direction: irisNotchSilhouette.outward
            }
            PathLine {
                x: irisNotchSilhouette.edgeL - irisNotchSilhouette.f
                y: irisNotchSilhouette.ey(0)
            }
        }
    }

    MouseArea {
        anchors.fill: bodyFrame
        z: -1
        acceptedButtons: Qt.AllButtons
    }

    RowLayout {
        id: toolbarRow
        anchors.fill: bodyFrame
        anchors.margins: root.iris ? 8 : 6
        anchors.leftMargin: root.iris ? 10 : 6
        anchors.rightMargin: root.iris ? 8 : 6
        spacing: root.iris ? 6 : 4

        WidgetEditAction {
            id: snapAction
            compact: true
            iconName: "grid_on"
            label: Translation.tr("Snap to grid")
            toggled: root.snap
            tooltip: root.snap ? Translation.tr("Disable grid snap") : Translation.tr("Enable grid snap")
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: Config.setNestedValue("background.widgets.editGrid.snap", !root.snap)
        }

        WidgetEditAction {
            id: gridSizeAction
            iconName: "grid_4x4"
            label: root.gridSize + " px"
            compact: root.availableWidth < 560
            tooltip: Translation.tr("Grid size: %1px — click to cycle").arg(root.gridSize)
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: {
                const sizes = [16, 32, 48, 64]
                const index = sizes.indexOf(root.gridSize)
                Config.setNestedValue("background.widgets.editGrid.size",
                    sizes[(index + 1) % sizes.length])
            }
        }

        Rectangle {
            visible: !root.iris
            Layout.preferredWidth: 1
            Layout.preferredHeight: 22
            color: root.iris ? IrisStyle.hairlineStrong : Appearance.colors.colOutlineVariant
            opacity: root.iris ? 1 : 0.42
        }

        WidgetEditAction {
            compact: true
            iconName: "chevron_left"
            label: Translation.tr("Previous widgets")
            enabled: widgetRail.contentX > 1
            opacity: enabled ? 1 : 0.28
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: widgetRail.scrollPage(-1)
        }

        Rectangle {
            Layout.preferredWidth: root.railWidth + (root.iris ? 8 : 0)
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            Layout.preferredHeight: root.iris ? 42 : 32
            radius: height / 2
            color: root.iris ? ColorUtils.applyAlpha(IrisStyle.text, 0.055) : "transparent"

            Flickable {
                id: widgetRail
                anchors.fill: parent
                anchors.margins: root.iris ? 4 : 0
                contentWidth: widgetRow.implicitWidth
                contentHeight: height
                clip: true
                interactive: contentWidth > width
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                function snapContentX(value: real): real {
                    const maxX = Math.max(0, contentWidth - width)
                    const snapped = Math.round(value / root.railStride) * root.railStride
                    return Math.max(0, Math.min(maxX, snapped))
                }

                function scrollPage(direction: int): void {
                    const page = Math.max(root.railStride,
                        (root.railSlots - 1) * root.railStride)
                    contentX = snapContentX(contentX + direction * page)
                }

                onMovementEnded: contentX = snapContentX(contentX)
                onWidthChanged: Qt.callLater(() => contentX = snapContentX(contentX))
                onContentWidthChanged: Qt.callLater(() => contentX = snapContentX(contentX))

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const horizontal = event.angleDelta.x
                        const vertical = event.angleDelta.y
                        const delta = Math.abs(horizontal) > Math.abs(vertical) ? -horizontal : -vertical
                        if (delta !== 0)
                            widgetRail.contentX = widgetRail.snapContentX(widgetRail.contentX
                                + (delta > 0 ? root.railStride * 3 : -root.railStride * 3))
                        event.accepted = true
                    }
                }

                Row {
                    id: widgetRow
                    spacing: root.iris ? 2 : 2

                    Repeater {
                        model: root.builtinWidgets
                        WidgetEditAction {
                            required property var modelData
                            readonly property bool widgetEnabled: DesktopWidgetLayout.enabled(
                                root.outputName, modelData.key,
                                Config.getNestedValue("background.widgets." + modelData.key + ".enable", modelData.defaultOn))
                            compact: true
                            tileTint: root.iris ? (root.irisTints[modelData.key] ?? "#8e8e93") : "transparent"
                            iconName: modelData.icon
                            label: Translation.tr(modelData.label)
                            tooltip: Translation.tr(modelData.label)
                            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
                            toggled: widgetEnabled
                            onClicked: DesktopWidgetLayout.setGloballyEnabled(modelData.key, !widgetEnabled)
                        }
                    }

                    Repeater {
                        model: CustomWidgets.ready ? CustomWidgets.widgets : []
                        WidgetEditAction {
                            required property var modelData
                            readonly property string layoutKey: "custom." + modelData.id
                            readonly property bool widgetEnabled: DesktopWidgetLayout.enabled(
                                root.outputName, layoutKey,
                                Config.getNestedValue("background.widgets.custom." + modelData.id + ".enable", false))
                            compact: true
                            tileTint: root.iris ? "#5e5ce6" : "transparent"
                            iconName: modelData.icon || "widgets"
                            label: modelData.name
                            tooltip: modelData.name
                            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
                            toggled: widgetEnabled
                            onClicked: DesktopWidgetLayout.setGloballyEnabled(layoutKey, !widgetEnabled)
                        }
                    }
                }
            }
        }

        WidgetEditAction {
            compact: true
            iconName: "chevron_right"
            label: Translation.tr("More widgets")
            enabled: widgetRail.contentX < Math.max(0, widgetRail.contentWidth - widgetRail.width) - 1
            opacity: enabled ? 1 : 0.28
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: widgetRail.scrollPage(1)
        }

        Rectangle {
            visible: !root.iris
            Layout.preferredWidth: 1
            Layout.preferredHeight: 22
            color: root.iris ? IrisStyle.hairlineStrong : Appearance.colors.colOutlineVariant
            opacity: root.iris ? 1 : 0.42
        }

        WidgetEditAction {
            id: libraryAction
            iconName: "dashboard_customize"
            label: Translation.tr("Manage widgets")
            compact: root.availableWidth < 980
            toggled: root.libraryOpen
            tooltip: Translation.tr("Browse, add and manage widgets")
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: root.libraryRequested()
        }

        WidgetEditAction {
            compact: true
            iconName: "border_outer"
            label: Translation.tr("Screen edges")
            tooltip: Translation.tr("Configure Organic edge")
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: root.edgeSettingsRequested()
        }

        WidgetEditAction {
            compact: true
            iconName: "settings"
            label: Translation.tr("Widget settings")
            tooltip: Translation.tr("Open full widget settings")
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: root.settingsRequested()
        }

        Rectangle {
            visible: !root.iris
            Layout.preferredWidth: 1
            Layout.preferredHeight: 22
            color: root.iris ? IrisStyle.hairlineStrong : Appearance.colors.colOutlineVariant
            opacity: root.iris ? 1 : 0.42
        }

        WidgetEditAction {
            id: doneAction
            iconName: "check"
            label: Translation.tr("Done")
            compact: root.availableWidth < 720
            primary: true
            tooltip: Translation.tr("Done editing")
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: root.doneRequested()
        }
    }
}
