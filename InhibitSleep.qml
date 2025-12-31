import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    property bool hasMediaDevices: false
    property bool sleepInhibited: false

    // Timer to periodically check for media devices
    Timer {
        id: checkTimer
        interval: 2000 // Check every 2 seconds
        running: true
        repeat: true
        onTriggered: checkMediaDevices()
    }

    // Process to check for media devices
    Process {
        id: mprisCheckProcess
        command: ["dms", "ipc", "call", "mpris", "list"]

        property string output: ""

        stdout: SplitParser {
            onRead: line => {
                mprisCheckProcess.output += line + "\n"
            }
        }

        onExited: {
            var trimmed = output.trim()
            // Check if there are any media players
            // Handle empty output, empty JSON arrays, null, etc.
            var hasMedia = trimmed !== "" && 
                          trimmed !== "[]" && 
                          trimmed !== "null" && 
                          trimmed !== "{}" &&
                          !trimmed.match(/^\s*\[\s*\]\s*$/) // Empty JSON array with whitespace
            
            if (hasMedia !== root.hasMediaDevices) {
                root.hasMediaDevices = hasMedia
                updateSleepInhibition()
            }
            output = "" // Reset for next run
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim()) {
                    console.warn("MPRIS check error:", line)
                }
            }
        }
    }

    // Process to enable sleep inhibition
    Process {
        id: inhibitEnableProcess
        command: ["ds", "ipc", "call", "inhibit", "enable"]

        stdout: SplitParser {
            onRead: line => {
                console.log("Inhibit enable response:", line)
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim()) {
                    console.warn("Inhibit enable error:", line)
                }
            }
        }
    }

    // Process to disable sleep inhibition
    Process {
        id: inhibitDisableProcess
        command: ["ds", "ipc", "call", "inhibit", "disable"]

        stdout: SplitParser {
            onRead: line => {
                console.log("Inhibit disable response:", line)
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim()) {
                    console.warn("Inhibit disable error:", line)
                }
            }
        }
    }

    function checkMediaDevices() {
        mprisCheckProcess.running = true
    }

    function updateSleepInhibition() {
        if (root.hasMediaDevices && !root.sleepInhibited) {
            // Enable sleep inhibition
            inhibitEnableProcess.running = true
            root.sleepInhibited = true
            console.log("Sleep inhibition enabled (media device detected)")
        } else if (!root.hasMediaDevices && root.sleepInhibited) {
            // Disable sleep inhibition
            inhibitDisableProcess.running = true
            root.sleepInhibited = false
            console.log("Sleep inhibition disabled (no media devices)")
        }
    }

    Component.onCompleted: {
        console.info("InhibitSleep plugin started")
        // Initial check
        checkMediaDevices()
    }

    Component.onDestruction: {
        // Disable sleep inhibition when plugin is destroyed
        if (root.sleepInhibited) {
            inhibitDisableProcess.running = true
        }
    }
}
