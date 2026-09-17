import qs
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

QuickToggleModel {
    id: root
    name: Translation.tr("Cloudflare WARP")

    readonly property string warpCliPath: "warp-cli"
    readonly property string notifySendPath: "notify-send"

    available: false
    toggled: false
    icon: "cloud_lock"
    statusText: root._daemonRunning ? "" : Translation.tr("Daemon not running")
    hasStatusText: true

    property bool _daemonRunning: true

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

        stdout: StdioCollector {
            id: warpStatusCollector
            onStreamFinished: {
                const out = warpStatusCollector.text
                if (out.length > 0 || out.includes("Unable")) {
                    root.available = true
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

        onExited: (exitCode, exitStatus) => {
            // If warp-cli doesn't exist, process fails silently
            // Disable toggle in that case
            if (exitCode !== 0) {
                root.available = false
                root._daemonRunning = false
            }
        }
    }

    tooltipText: Translation.tr("Cloudflare WARP (1.1.1.1)")

    Timer {
        id: warpPollTimer
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: root.available && (GlobalStates.sidebarRightOpen || GlobalStates.waffleActionCenterOpen)
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.refreshStatus()
}
