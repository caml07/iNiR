import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Cloudflare WARP")

    readonly property string warpCliPath: "warp-cli"
    readonly property string notifySendPath: "notify-send"

    property bool _daemonRunning: true

    toggled: false
    buttonIcon: "cloud_lock"

    function refreshStatus() {
        fetchActiveState.running = false;
        fetchActiveState.running = true;
    }

    function showServiceInstructions() {
        Quickshell.execDetached([root.notifySendPath, Translation.tr("Cloudflare WARP"), Translation.tr("The WARP daemon is stopped. Start warp-svc with your system service manager, then retry."), "-a", "Shell"])
    }
    
    mainAction: () => {
        if (!root._daemonRunning) {
            root.showServiceInstructions();
            return;
        }
        if (toggled) disconnectProc.running = true;
        else connectProc.running = true;
    }

    altAction: () => {
        root.showServiceInstructions();
    }

    Process {
        id: disconnectProc
        command: [root.warpCliPath, "disconnect"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([root.notifySendPath,
                    Translation.tr("Cloudflare WARP"),
                    Translation.tr("Disconnect failed. Please inspect manually with the <tt>warp-cli</tt> command"),
                    "-a", "Shell"
                ])
            }
            root.refreshStatus();
        }
    }

    Process {
        id: connectProc
        command: [root.warpCliPath, "connect"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([root.notifySendPath,
                    Translation.tr("Cloudflare WARP"), 
                    Translation.tr("Connection failed. Please inspect manually with the <tt>warp-cli</tt> command")
                    , "-a", "Shell"
                ])
            }
            root.refreshStatus();
        }
    }

    Process {
        id: fetchActiveState
        running: false
        command: ["/bin/sh", "-c", root.warpCliPath + " status"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.visible = true
            }
        }
        stdout: StdioCollector {
            id: warpStatusCollector
            onStreamFinished: {
                const out = warpStatusCollector.text

                if (out.length > 0 || out.includes("Unable")) {
                    root.visible = true
                }

                if (out.includes("Unable to connect")) {
                    root._daemonRunning = false
                    root.toggled = false
                    return;
                }

                root._daemonRunning = true
                if (out.includes("Connected")) {
                    root.toggled = true
                } else if (out.includes("Disconnected")) {
                    root.toggled = false
                }
            }
        }
    }


    Timer {
        id: warpPollTimer
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: GlobalStates.sidebarRightOpen
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()
    StyledToolTip {
        text: Translation.tr("Cloudflare WARP (1.1.1.1)")
    }
}
