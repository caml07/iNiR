pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property date currentDate
    property string orientation: "horizontal"
    property real scaleFactor: 1
    property color softColor: Appearance.colors.colPrimaryContainer
    property color boldColor: Appearance.colors.colPrimary
    property bool showShadow: true

    readonly property bool vertical: root.orientation === "vertical"
    readonly property real desiredImplicitWidth: Math.round((root.vertical ? 276 : 420) * root.scaleFactor)
    readonly property real desiredImplicitHeight: Math.round((root.vertical ? 252 : 150) * root.scaleFactor)
    implicitWidth: root.desiredImplicitWidth
    implicitHeight: root.desiredImplicitHeight

    readonly property string digits: Qt.formatDateTime(root.currentDate, "HHmm")
    readonly property string glyphTopLeft: root.digits.charAt(0)
    readonly property string glyphTopRight: root.digits.charAt(1)
    readonly property string glyphBottomLeft: root.digits.charAt(2)
    readonly property string glyphBottomRight: root.digits.charAt(3)

    readonly property real fringeSize: root.vertical ? root.width * 0.026 : root.height * 0.03
    readonly property real tileW: root.vertical ? root.width * 0.66 : root.width * 0.30
    readonly property real tileH: root.vertical ? root.height * 0.66 : root.height * 0.9
    readonly property real glyphSize: root.vertical ? root.height * 0.66 : root.height * 0.85

    readonly property real pos0X: 0
    readonly property real pos1X: root.vertical ? root.width * 0.30 : root.width * 0.15
    readonly property real pos2X: root.vertical ? 0 : root.width * 0.46
    readonly property real pos3X: root.vertical ? root.width * 0.30 : root.width * 0.60
    readonly property real pos0Y: root.vertical ? root.height * -0.04 : root.height * 0.05
    readonly property real pos1Y: root.pos0Y
    readonly property real pos2Y: root.vertical ? root.height * 0.42 : root.height * 0.05
    readonly property real pos3Y: root.pos2Y
    readonly property real colonX: root.pos1X + root.tileW
        + (root.pos2X - (root.pos1X + root.tileW)) / 2 - root.width * 0.03
    readonly property real colonDotSize: root.height * 0.2
    readonly property real colonGap: root.height * 0.04

    function ringSamples(count: int, radius: real): var {
        const points = [{ dx: 0, dy: 0 }]
        for (let i = 0; i < count; ++i) {
            const angle = i / count * Math.PI * 2
            points.push({ dx: Math.cos(angle) * radius, dy: Math.sin(angle) * radius })
        }
        return points
    }

    readonly property var fringeSamples: root.ringSamples(16, root.fringeSize)

    StyledDropShadow {
        target: glyphStage
        visible: root.showShadow && Appearance.effectsEnabled
    }

    Item {
        id: glyphStage
        anchors.fill: parent

        component GlyphTile: Text {
            width: root.tileW
            height: root.tileH
            font.family: "Google Sans Flex"
            font.weight: 1000
            font.bold: true
            font.pixelSize: root.glyphSize
            font.variableAxes: ({ "wght": 1000 })
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: tileAFace
            anchors.fill: parent
            visible: false
            GlyphTile { x: root.pos0X; y: root.pos0Y; text: root.glyphTopLeft; color: root.softColor }
        }
        Item {
            id: tileAPunch
            anchors.fill: parent
            visible: false
            Repeater {
                model: root.fringeSamples
                Item {
                    id: punchA
                    required property var modelData
                    anchors.fill: parent
                    GlyphTile { x: root.pos1X + punchA.modelData.dx; y: root.pos1Y + punchA.modelData.dy; text: root.glyphTopRight; color: "black" }
                    GlyphTile { x: root.pos2X + punchA.modelData.dx; y: root.pos2Y + punchA.modelData.dy; text: root.glyphBottomLeft; color: "black" }
                    GlyphTile { x: root.pos3X + punchA.modelData.dx; y: root.pos3Y + punchA.modelData.dy; text: root.glyphBottomRight; color: "black" }
                }
            }
        }
        OpacityMask { anchors.fill: parent; source: tileAFace; maskSource: tileAPunch; invert: true; z: 0 }

        Item {
            id: tileBFace
            anchors.fill: parent
            visible: false
            GlyphTile { x: root.pos1X; y: root.pos1Y; text: root.glyphTopRight; color: root.boldColor }
        }
        Item {
            id: tileBPunch
            anchors.fill: parent
            visible: false
            Repeater {
                model: root.fringeSamples
                Item {
                    id: punchB
                    required property var modelData
                    anchors.fill: parent
                    GlyphTile { x: root.pos2X + punchB.modelData.dx; y: root.pos2Y + punchB.modelData.dy; text: root.glyphBottomLeft; color: "black" }
                    GlyphTile { x: root.pos3X + punchB.modelData.dx; y: root.pos3Y + punchB.modelData.dy; text: root.glyphBottomRight; color: "black" }
                }
            }
        }
        OpacityMask { anchors.fill: parent; source: tileBFace; maskSource: tileBPunch; invert: true; z: 1 }

        Item {
            id: tileCFace
            anchors.fill: parent
            visible: false
            GlyphTile { x: root.pos2X; y: root.pos2Y; text: root.glyphBottomLeft; color: root.boldColor }
        }
        Item {
            id: tileCPunch
            anchors.fill: parent
            visible: false
            Repeater {
                model: root.fringeSamples
                Item {
                    id: punchC
                    required property var modelData
                    anchors.fill: parent
                    GlyphTile { x: root.pos3X + punchC.modelData.dx; y: root.pos3Y + punchC.modelData.dy; text: root.glyphBottomRight; color: "black" }
                }
            }
        }
        OpacityMask { anchors.fill: parent; source: tileCFace; maskSource: tileCPunch; invert: true; z: 2 }

        GlyphTile {
            x: root.pos3X
            y: root.pos3Y
            text: root.glyphBottomRight
            color: root.softColor
            z: 3
        }

        Column {
            visible: !root.vertical
            x: root.colonX
            y: root.pos0Y + root.tileH / 2 - height / 2
            spacing: root.colonGap
            z: 4
            Rectangle { width: root.colonDotSize; height: width; radius: width / 2; color: root.boldColor; anchors.horizontalCenter: parent.horizontalCenter }
            Rectangle { width: root.colonDotSize; height: width; radius: width / 2; color: root.boldColor; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
