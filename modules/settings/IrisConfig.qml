import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 28
    settingsPageName: "iRiS"
    property string activeSection: "design"
    readonly property bool familyActive: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property var slotOptions: [
        { displayName: Translation.tr("Off"), value: "off" },
        { displayName: Translation.tr("Left"), value: "left" },
        { displayName: Translation.tr("Center"), value: "center" },
        { displayName: Translation.tr("Right"), value: "right" }
    ]
    readonly property var builtInModules: [
        { id: "brand", icon: "visibility", label: "iRiS" },
        { id: "workspaces", icon: "workspaces", label: Translation.tr("Workspaces") },
        { id: "activeWindow", icon: "web_asset", label: Translation.tr("Active window") },
        { id: "status", icon: "network_check", label: Translation.tr("Status") },
        { id: "clock", icon: "schedule", label: Translation.tr("Clock") },
        { id: "controls", icon: "tune", label: Translation.tr("Controls") }
    ]

    function listFor(slot: string): var {
        if (slot === "left") return Config.options?.iris?.bar?.leftModules ?? []
        if (slot === "center") return Config.options?.iris?.bar?.centerModules ?? []
        if (slot === "right") return Config.options?.iris?.bar?.rightModules ?? []
        return []
    }
    function slotFor(moduleId: string): string {
        for (const slot of ["left", "center", "right"]) {
            if (root.listFor(slot).includes(moduleId)) return slot
        }
        return "off"
    }
    function setModuleSlot(moduleId: string, slot: string): void {
        const left = [...root.listFor("left")].filter(id => id !== moduleId)
        const center = [...root.listFor("center")].filter(id => id !== moduleId)
        const right = [...root.listFor("right")].filter(id => id !== moduleId)
        const target = slot === "left" ? left : slot === "center" ? center : right
        if (slot !== "off") target.push(moduleId)
        Config.setNestedValues({
            "iris.bar.leftModules": left,
            "iris.bar.centerModules": center,
            "iris.bar.rightModules": right
        })
    }
    function canMoveModule(moduleId: string, delta: int): bool {
        const slot = root.slotFor(moduleId)
        if (slot === "off") return false
        const list = root.listFor(slot)
        const index = list.indexOf(moduleId)
        const target = index + delta
        return index >= 0 && target >= 0 && target < list.length
    }
    function moveModule(moduleId: string, delta: int): void {
        const slot = root.slotFor(moduleId)
        if (slot === "off") return
        const list = [...root.listFor(slot)]
        const index = list.indexOf(moduleId)
        const target = index + delta
        if (index < 0 || target < 0 || target >= list.length) return
        const moved = list[index]
        list.splice(index, 1)
        list.splice(target, 0, moved)
        Config.setNestedValue("iris.bar." + slot + "Modules", list)
    }

    SettingsTaskNavigator {
        icon: "visibility"
        title: "iRiS"
        description: Translation.tr("Apple-inspired Island shell with Dock, Palette and optional desktop widgets.")
        summary: Translation.tr("Design · bar · modules · surfaces")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("Design"), icon: "palette", value: "design" },
            { displayName: Translation.tr("Bar"), icon: "toolbar", value: "bar" },
            { displayName: Translation.tr("Modules"), icon: "extension", value: "modules" },
            { displayName: Translation.tr("Surfaces"), icon: "web_asset", value: "surfaces" }
        ]
    }

    SettingsTaskLoader {
        requested: root.activeSection === "design"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "design"
                expanded: true
                icon: "visibility"
                title: Translation.tr("iRiS family")
                SettingsGroup {
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.sizes.spacingMedium
                        MaterialSymbol {
                            text: "visibility"
                            iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.colors.colPrimary
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                text: root.familyActive ? Translation.tr("iRiS is active") : Translation.tr("iRiS is ready")
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Island chrome stays lightweight; Dock and desktop widgets can be enabled independently.")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                wrapMode: Text.WordWrap
                            }
                        }
                        RippleButton {
                            visible: !root.familyActive
                            implicitWidth: 116
                            implicitHeight: 38
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colPrimaryContainer
                            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                            colRipple: Appearance.colors.colPrimaryContainerActive
                            onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "panelFamily", "set", "iris"])
                            StyledText {
                                anchors.centerIn: parent
                                text: Translation.tr("Activate")
                                color: Appearance.colors.colOnPrimaryContainer
                                font.weight: Font.Bold
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "design"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "design"
                expanded: true
                icon: "design_services"
                title: Translation.tr("Visual system")
                SettingsGroup {
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { Layout.fillWidth: true; text: Translation.tr("Design") }
                        StyledComboBox {
                            Layout.preferredWidth: 180
                            model: [
                                { displayName: "Classic", value: "classic" },
                                { displayName: "Island", value: "island" }
                            ]
                            textRole: "displayName"
                            currentIndex: (Config.options?.iris?.appearance?.design ?? "island") === "classic" ? 0 : 1
                            onActivated: index => Config.setNestedValue("iris.appearance.design", model[index].value)
                        }
                    }
                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "density_medium"
                            text: Translation.tr("Density (%)")
                            value: Math.round((Config.options?.iris?.appearance?.density ?? 1.0) * 100)
                            from: 80
                            to: 135
                            stepSize: 5
                            onValueChanged: Config.setNestedValue("iris.appearance.density", value / 100)
                        }
                        ConfigSpinBox {
                            icon: "rounded_corner"
                            text: Translation.tr("Classic radius")
                            enabled: (Config.options?.iris?.appearance?.design ?? "island") === "classic"
                            value: Config.options?.iris?.appearance?.radius ?? 12
                            from: 4
                            to: 28
                            onValueChanged: Config.setNestedValue("iris.appearance.radius", value)
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "animation"
                        text: Translation.tr("Motion")
                        checked: Config.options?.iris?.appearance?.motion ?? true
                        onCheckedChanged: Config.setNestedValue("iris.appearance.motion", checked)
                    }
                }
            }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "bar"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "bar"
                expanded: true
                icon: "toolbar"
                title: Translation.tr("Bar geometry")
                SettingsGroup {
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.sizes.spacingMedium
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Position")
                        }
                        StyledComboBox {
                            Layout.preferredWidth: 150
                            model: [
                                { displayName: Translation.tr("Top"), value: "top" },
                                { displayName: Translation.tr("Bottom"), value: "bottom" }
                            ]
                            textRole: "displayName"
                            currentIndex: String(Config.options?.iris?.bar?.position ?? "top") === "bottom" ? 1 : 0
                            onActivated: index => Config.setNestedValue("iris.bar.position", model[index].value)
                        }
                    }
                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "height"
                            text: Translation.tr("Height")
                            value: Config.options?.iris?.bar?.height ?? 42
                            from: 32
                            to: 64
                            onValueChanged: Config.setNestedValue("iris.bar.height", value)
                        }
                        ConfigSpinBox {
                            icon: "space_bar"
                            text: Translation.tr("Screen gap")
                            value: Config.options?.iris?.bar?.margin ?? 8
                            from: 0
                            to: 24
                            onValueChanged: Config.setNestedValue("iris.bar.margin", value)
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "view_compact"
                        text: Translation.tr("Reserve workspace space")
                        checked: Config.options?.iris?.bar?.reserveSpace ?? true
                        onCheckedChanged: Config.setNestedValue("iris.bar.reserveSpace", checked)
                    }
                }
            }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: true
                icon: "view_week"
                title: Translation.tr("Bar slots")
                SettingsGroup {
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Off removes a module from the runtime bar tree.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    Repeater {
                        model: root.builtInModules
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Appearance.sizes.spacingMedium
                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.label
                                font.weight: Font.DemiBold
                            }
                            StyledComboBox {
                                Layout.preferredWidth: 140
                                model: root.slotOptions
                                textRole: "displayName"
                                currentIndex: Math.max(0, root.slotOptions.findIndex(option => option.value === root.slotFor(modelData.id)))
                                onActivated: index => root.setModuleSlot(modelData.id, root.slotOptions[index].value)
                            }
                            IconToolbarButton {
                                visible: root.slotFor(modelData.id) !== "off"
                                enabled: root.canMoveModule(modelData.id, -1)
                                implicitWidth: 30
                                implicitHeight: 30
                                iconSize: 17
                                text: "arrow_back"
                                onClicked: root.moveModule(modelData.id, -1)
                                StyledToolTip { text: Translation.tr("Move earlier") }
                            }
                            IconToolbarButton {
                                visible: root.slotFor(modelData.id) !== "off"
                                enabled: root.canMoveModule(modelData.id, 1)
                                implicitWidth: 30
                                implicitHeight: 30
                                iconSize: 17
                                text: "arrow_forward"
                                onClicked: root.moveModule(modelData.id, 1)
                                StyledToolTip { text: Translation.tr("Move later") }
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
                icon: "extension"
                title: Translation.tr("User modules")
                SettingsGroup {
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Widgets can expose a compact iRiS component without adding another plugin system.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: CustomWidgets.ready
                            ? CustomWidgets.widgets.filter(widget => String(widget.irisQmlPath ?? "").length > 0)
                            : []
                        RowLayout {
                            required property var modelData
                            readonly property string moduleId: "custom:" + modelData.id
                            Layout.fillWidth: true
                            spacing: Appearance.sizes.spacingMedium
                            SmartAppIcon {
                                icon: modelData.icon || "extension"
                                iconSize: Appearance.font.pixelSize.larger
                                monochrome: true
                                color: Appearance.colors.colPrimary
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText { text: modelData.name; font.weight: Font.DemiBold }
                                StyledText {
                                    text: modelData.description
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    elide: Text.ElideRight
                                }
                            }
                            StyledComboBox {
                                Layout.preferredWidth: 140
                                readonly property var allowedSlots: modelData.irisSlots ?? []
                                model: root.slotOptions.filter(option => option.value === "off"
                                    || allowedSlots.length === 0
                                    || allowedSlots.includes("bar." + option.value))
                                textRole: "displayName"
                                currentIndex: Math.max(0, model.findIndex(option => option.value === root.slotFor(parent.moduleId)))
                                onActivated: index => root.setModuleSlot(parent.moduleId, model[index].value)
                            }
                            IconToolbarButton {
                                visible: root.slotFor(parent.moduleId) !== "off"
                                enabled: root.canMoveModule(parent.moduleId, -1)
                                implicitWidth: 30
                                implicitHeight: 30
                                iconSize: 17
                                text: "arrow_back"
                                onClicked: root.moveModule(parent.moduleId, -1)
                                StyledToolTip { text: Translation.tr("Move earlier") }
                            }
                            IconToolbarButton {
                                visible: root.slotFor(parent.moduleId) !== "off"
                                enabled: root.canMoveModule(parent.moduleId, 1)
                                implicitWidth: 30
                                implicitHeight: 30
                                iconSize: 17
                                text: "arrow_forward"
                                onClicked: root.moveModule(parent.moduleId, 1)
                                StyledToolTip { text: Translation.tr("Move later") }
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: CustomWidgets.ready
                            && CustomWidgets.widgets.filter(widget => String(widget.irisQmlPath ?? "").length > 0).length === 0
                        text: Translation.tr("No custom iRiS modules installed. `inir customWidgets create my-widget` now scaffolds one.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "surfaces"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "surfaces"
                expanded: true
                icon: "toggle_on"
                title: Translation.tr("On-demand surfaces")

                SettingsGroup {
                    SettingsSwitch {
                        buttonIcon: "widgets"
                        text: Translation.tr("Desktop widgets")
                        checked: Config.options?.iris?.modules?.desktopWidgets ?? true
                        onCheckedChanged: Config.setNestedValue("iris.modules.desktopWidgets", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "dock_to_bottom"
                        text: Translation.tr("Dock")
                        checked: Config.options?.iris?.dock?.enable ?? true
                        onCheckedChanged: Config.setNestedValue("iris.dock.enable", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "visibility"
                        text: Translation.tr("Automatically hide dock")
                        checked: Config.options?.iris?.dock?.autoHide ?? true
                        onCheckedChanged: Config.setNestedValue("iris.dock.autoHide", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "blur_on"
                        text: Translation.tr("Dock blur")
                        checked: Config.options?.iris?.dock?.blur ?? false
                        onCheckedChanged: Config.setNestedValue("iris.dock.blur", checked)
                    }
                    ConfigSpinBox {
                        icon: "photo_size_select_small"
                        text: Translation.tr("Dock icon size")
                        value: Config.options?.iris?.dock?.iconSize ?? 40
                        from: 28
                        to: 64
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("iris.dock.iconSize", value)
                    }
                    SettingsSwitch {
                        buttonIcon: "search"
                        text: Translation.tr("Palette")
                        checked: Config.options?.iris?.modules?.palette ?? true
                        onCheckedChanged: Config.setNestedValue("iris.modules.palette", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "tune"
                        text: Translation.tr("Control center")
                        checked: Config.options?.iris?.modules?.controlCenter ?? true
                        onCheckedChanged: Config.setNestedValue("iris.modules.controlCenter", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "notifications"
                        text: Translation.tr("Notification popups")
                        checked: Config.options?.iris?.modules?.notificationPopup ?? true
                        onCheckedChanged: Config.setNestedValue("iris.modules.notificationPopup", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "monitoring"
                        text: Translation.tr("OSD")
                        checked: Config.options?.iris?.modules?.osd ?? true
                        onCheckedChanged: Config.setNestedValue("iris.modules.osd", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "power_settings_new"
                        text: Translation.tr("Session screen")
                        checked: Config.options?.iris?.modules?.sessionScreen ?? true
                        onCheckedChanged: Config.setNestedValue("iris.modules.sessionScreen", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "lock"
                        text: Translation.tr("Lock screen")
                        checked: Config.options?.iris?.modules?.lock ?? true
                        onCheckedChanged: Config.setNestedValue("iris.modules.lock", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "admin_panel_settings"
                        text: Translation.tr("Polkit authentication")
                        checked: Config.options?.iris?.modules?.polkit ?? true
                        onCheckedChanged: Config.setNestedValue("iris.modules.polkit", checked)
                    }
                }
            }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "surfaces"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "surfaces"
                expanded: false
                icon: "aspect_ratio"
                title: Translation.tr("Surface sizing")

                SettingsGroup {
                    ConfigSpinBox {
                        icon: "search"
                        text: Translation.tr("Palette width")
                        value: Config.options?.iris?.palette?.width ?? 640
                        from: 420
                        to: 900
                        stepSize: 10
                        onValueChanged: Config.setNestedValue("iris.palette.width", value)
                    }
                    ConfigSpinBox {
                        icon: "format_list_numbered"
                        text: Translation.tr("Palette results")
                        value: Config.options?.iris?.palette?.maxResults ?? 8
                        from: 3
                        to: 14
                        onValueChanged: Config.setNestedValue("iris.palette.maxResults", value)
                    }
                    SettingsSwitch {
                        buttonIcon: "keyboard"
                        text: Translation.tr("Palette shortcut hints")
                        checked: Config.options?.iris?.palette?.showHints ?? true
                        onCheckedChanged: Config.setNestedValue("iris.palette.showHints", checked)
                    }
                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "tune"
                            text: Translation.tr("Control width")
                            value: Config.options?.iris?.controlCenter?.width ?? 360
                            from: 300
                            to: 540
                            stepSize: 10
                            onValueChanged: Config.setNestedValue("iris.controlCenter.width", value)
                        }
                        ConfigSpinBox {
                            icon: "notifications"
                            text: Translation.tr("Notification width")
                            value: Config.options?.iris?.notifications?.width ?? 380
                            from: 300
                            to: 560
                            stepSize: 10
                            onValueChanged: Config.setNestedValue("iris.notifications.width", value)
                        }
                    }
                    ConfigSpinBox {
                        icon: "monitoring"
                        text: Translation.tr("OSD width")
                        value: Config.options?.iris?.osd?.width ?? 320
                        from: 260
                        to: 480
                        stepSize: 10
                        onValueChanged: Config.setNestedValue("iris.osd.width", value)
                    }
                }
            }
        }
    }
}
