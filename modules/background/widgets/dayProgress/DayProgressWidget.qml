pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "dayProgress"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 240, contentHeight: 240,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        style: "ring", comet: true, showIcon: true, showDate: true, hourLabels: true, fontScale: 100,
        showBackground: false, showBorder: false, backgroundOpacity: 0,
        borderWidth: 0, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        x: 80, y: 260
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 240) * scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 240) * scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 190
    resizeMinHeight: 190
    needsColText: true

    // ── Tokens ───────────────────────────────────────────────
    // Semantic roles follow the shared desktop-widget palette contract
    // (colorMode + per-role palette), never hardcoded colors.
    readonly property color ink: root.widgetInk
    readonly property color inkMuted: root.widgetInkMuted
    readonly property color inkFaint: ColorUtils.applyAlpha(root.ink, 0.16)
    readonly property color inkDim: ColorUtils.applyAlpha(root.ink, 0.34)
    readonly property color accent: root.widgetAccentVisible
    readonly property color accentSoft: root.widgetAccent3Visible

    // ── Customization ────────────────────────────────────────
    readonly property string ringStyle: String(root._readConfigKey("style") ?? "ring")
    readonly property bool showTicks: root.ringStyle !== "arc"
    readonly property bool showArc: root.ringStyle !== "ticks"
    readonly property bool showComet: root.showArc && Boolean(root._readConfigKey("comet") ?? true)
    readonly property bool showIcon: Boolean(root._readConfigKey("showIcon") ?? true)
    readonly property bool showDate: Boolean(root._readConfigKey("showDate") ?? true)
    readonly property bool showHourLabels: Boolean(root._readConfigKey("hourLabels") ?? true)
    // Text emphasis control: 100% keeps the ring-relative defaults.
    readonly property real textScale: {
        const v = Number(root._readConfigKey("fontScale") ?? 100)
        return Math.max(0.6, Math.min(1.8, Number.isFinite(v) ? v / 100 : 1))
    }

    // ── Day state ────────────────────────────────────────────
    readonly property real dayFraction: {
        const d = DateTime.clock.date
        return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400
    }
    readonly property bool isDaytime: {
        const h = DateTime.clock.date.getHours()
        return h >= 6 && h < 19
    }

    // Borderless composition: no card, no border. The wallpaper-sampled ink
    // (needsColText) is the only thing keeping ring and type legible.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(10 * root.scaleFactor)

        Item {
            id: ringArea
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real size: Math.min(width, height)
            // Single shared radius: ticks and arc live on the same circle so
            // the elapsed path reads as one continuous instrument.
            readonly property real radius: size / 2 - Math.max(14, Math.round(15 * root.scaleFactor))
            readonly property real arcWidth: Math.max(3, Math.round(4.5 * root.scaleFactor))

            // ── Minute tick ring ─────────────────────────────
            Repeater {
                model: root.showTicks ? 60 : 0

                Item {
                    id: tick
                    required property int index
                    readonly property bool elapsed: (index / 60) <= root.dayFraction
                    readonly property bool quarter: index % 15 === 0
                    // Recent minutes burn brighter toward the tip: the ring
                    // reads as a fading trail instead of a flat fill.
                    readonly property real recency: Math.max(0,
                        Math.min(1, 1 - (root.dayFraction * 60 - index) / 40))
                    anchors.centerIn: ringArea
                    width: ringArea.size
                    height: ringArea.size
                    rotation: index * 6

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Ticks straddle the shared radius so the arc meets
                        // them edge-to-edge instead of floating inside.
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -ringArea.radius
                        width: tick.quarter ? Math.round(2.5 * root.scaleFactor) : Math.max(1, Math.round(1.5 * root.scaleFactor))
                        height: tick.quarter ? Math.round(12 * root.scaleFactor) : Math.round(6.5 * root.scaleFactor)
                        radius: width / 2
                        color: !tick.elapsed
                            ? (tick.quarter ? root.inkDim : root.inkFaint)
                            : tick.quarter ? root.accent
                            : ColorUtils.applyAlpha(root.accentSoft, 0.30 + 0.70 * tick.recency)
                        Behavior on color {
                            enabled: root.animationsActive
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }
                    }
                }
            }

            // ── Hour labels 00 / 06 / 12 / 18 ────────────────
            // Direct trigonometric placement in screen coordinates: the
            // label center sits on the ray of its quarter at a fixed
            // distance just beyond the tick ring. No nested transforms.
            Repeater {
                model: root.showHourLabels ? [0, 6, 12, 18] : []

                StyledText {
                    id: hourLabel
                    required property int modelData
                    // -PI/2 puts 0h at 12 o'clock; hours then run clockwise.
                    readonly property real angle: (modelData / 24) * 2 * Math.PI - Math.PI / 2
                    readonly property real labelRadius: ringArea.radius
                        + Math.max(15, Math.round(16 * root.scaleFactor))
                    // Center on the ring's true center per axis (same
                    // reference as the ticks' anchors.centerIn), so labels
                    // stay attached at any widget aspect ratio.
                    x: ringArea.width / 2 + labelRadius * Math.cos(angle) - width / 2
                    y: ringArea.height / 2 + labelRadius * Math.sin(angle) - height / 2
                    text: String(modelData).padStart(2, "0")
                    color: root.inkMuted
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Math.round(11 * root.scaleFactor * root.textScale)
                        weight: Font.DemiBold
                        letterSpacing: 1
                    }
                }
            }

            // ── Elapsed arc ──────────────────────────────────
            Shape {
                anchors.centerIn: parent
                width: ringArea.size
                height: ringArea.size
                preferredRendererType: Shape.CurveRenderer
                visible: root.showArc && root.dayFraction > 0.0005

                ShapePath {
                    strokeColor: root.accent
                    strokeWidth: ringArea.arcWidth
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: ringArea.size / 2
                        centerY: ringArea.size / 2
                        radiusX: ringArea.radius
                        radiusY: ringArea.radius
                        startAngle: -90
                        sweepAngle: root.dayFraction * 360
                    }
                }

                // Comet tail riding the tip on the same radius: motion
                // emphasis that melts into the arc instead of a detached dot.
                ShapePath {
                    strokeColor: root.showComet ? ColorUtils.applyAlpha(root.accent, 0.18) : "transparent"
                    strokeWidth: ringArea.arcWidth + Math.max(2, Math.round(2.5 * root.scaleFactor))
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: ringArea.size / 2
                        centerY: ringArea.size / 2
                        radiusX: ringArea.radius
                        radiusY: ringArea.radius
                        startAngle: -90 + root.dayFraction * 360 - 14
                        sweepAngle: 14
                    }
                }
                ShapePath {
                    strokeColor: root.showComet ? ColorUtils.applyAlpha(root.accent, 0.38) : "transparent"
                    strokeWidth: ringArea.arcWidth + Math.max(1, Math.round(1.5 * root.scaleFactor))
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: ringArea.size / 2
                        centerY: ringArea.size / 2
                        radiusX: ringArea.radius
                        radiusY: ringArea.radius
                        startAngle: -90 + root.dayFraction * 360 - 5
                        sweepAngle: 5
                    }
                }
            }

            // ── Center readout ───────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.showIcon
                    text: root.isDaytime ? "light_mode" : "bedtime"
                    iconSize: Math.round(ringArea.size * 0.095 * root.textScale)
                    color: root.accentSoft
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: root.showIcon ? Math.round(2 * root.scaleFactor) : 0
                    text: DateTime.time
                    color: root.ink
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Math.round(ringArea.size * 0.205 * root.textScale)
                        weight: Font.DemiBold
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Math.round(1 * root.scaleFactor)
                    text: Translation.tr("%1 of the day").arg(Math.round(root.dayFraction * 100) + "%")
                    color: root.accentSoft
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Math.round(ringArea.size * 0.075 * root.textScale)
                        weight: Font.DemiBold
                        letterSpacing: 0.4
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showDate
            text: DateTime.date
            color: root.inkMuted
            font {
                family: Appearance.font.family.numbers
                pixelSize: Math.round(13 * root.scaleFactor * root.textScale)
                weight: Font.Medium
                letterSpacing: 0.6
            }
        }
    }

    // ── Quick controls ───────────────────────────────────────
    editPopoverContent: Component {
        ColumnLayout {
            spacing: 6

            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: [
                        { value: "ring", label: Translation.tr("Ring"), icon: "donut_large" },
                        { value: "arc", label: Translation.tr("Arc"), icon: "data_usage" },
                        { value: "ticks", label: Translation.tr("Ticks"), icon: "blur_on" }
                    ]
                    WidgetChoiceButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.ringStyle === modelData.value
                        onClicked: root._setOutputValue("style", modelData.value)
                    }
                }
            }

            WidgetChoiceButton {
                Layout.fillWidth: true
                leftmost: true; rightmost: true
                buttonIcon: "flare"
                buttonText: Translation.tr("Comet tail")
                toggled: root.showComet
                enabled: root.showArc
                onClicked: root._setOutputValue("comet", !root.showComet)
            }

            WidgetChoiceButton {
                Layout.fillWidth: true
                leftmost: true; rightmost: true
                buttonIcon: root.isDaytime ? "light_mode" : "bedtime"
                buttonText: Translation.tr("Sun icon")
                toggled: root.showIcon
                onClicked: root._setOutputValue("showIcon", !root.showIcon)
            }

            WidgetChoiceButton {
                Layout.fillWidth: true
                leftmost: true; rightmost: true
                buttonIcon: "pin_drop"
                buttonText: Translation.tr("Hour labels")
                toggled: root.showHourLabels
                onClicked: root._setOutputValue("hourLabels", !root.showHourLabels)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: "format_size"
                    iconSize: 18
                    color: root.inkMuted
                }
                StyledSlider {
                    id: textSizeSlider
                    Layout.fillWidth: true
                    from: 60; to: 180; stepSize: 10
                    value: root.textScale * 100
                    configuration: StyledSlider.Configuration.XS
                    onMoved: root._setOutputValue("fontScale", Math.round(value))
                }
                StyledText {
                    text: Math.round(textSizeSlider.value) + "%"
                    color: root.inkMuted
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Appearance.font.pixelSize.smaller
                        weight: Font.DemiBold
                    }
                }
            }

            WidgetChoiceButton {
                Layout.fillWidth: true
                leftmost: true; rightmost: true
                buttonIcon: "event"
                buttonText: Translation.tr("Show date")
                toggled: root.showDate
                onClicked: root._setOutputValue("showDate", !root.showDate)
            }
        }
    }
}
