import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    property bool hasMediaDevices: false
    property bool sleepInhibited: false
    
    onSleepInhibitedChanged: {
        console.log("sleepInhibited changed to:", sleepInhibited)
    }

    // Bar indicator for horizontal bar
    horizontalBarPill: Component {
        Item {
            width: 16
            height: 16
            
            DankIcon {
                anchors.centerIn: parent
                name: "coffee"
                size: 16
                color: root.sleepInhibited ? Theme.primary : "#808080"
                opacity: root.sleepInhibited ? 1.0 : 0.3
            }
        }
    }

    // Bar indicator for vertical bar
    verticalBarPill: Component {
        Item {
            width: 16
            height: 16
            
            DankIcon {
                anchors.centerIn: parent
                name: "coffee"
                size: 16
                color: root.sleepInhibited ? Theme.primary : "#808080"
                opacity: root.sleepInhibited ? 1.0 : 0.3
            }
        }
    }

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
        command: ["dms", "ipc", "call", "inhibit", "enable"]

        stdout: SplitParser {
            onRead: line => {
                console.log("Inhibit enable response:", line)
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim()) {
                    console.error("Inhibit enable error:", line)
                }
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Sleep inhibition successfully enabled")
                // Verify state matches
                if (root.hasMediaDevices && !root.sleepInhibited) {
                    root.sleepInhibited = true
                }
            } else {
                console.error("Failed to enable sleep inhibition, exit code:", exitCode)
                // Revert state if command failed
                if (!root.hasMediaDevices) {
                    root.sleepInhibited = false
                }
            }
        }
    }

    // Process to disable sleep inhibition
    Process {
        id: inhibitDisableProcess
        command: ["dms", "ipc", "call", "inhibit", "disable"]

        stdout: SplitParser {
            onRead: line => {
                console.log("Inhibit disable response:", line)
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim()) {
                    console.error("Inhibit disable error:", line)
                }
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Sleep inhibition successfully disabled")
                // Verify state matches
                if (!root.hasMediaDevices && root.sleepInhibited) {
                    root.sleepInhibited = false
                }
            } else {
                console.error("Failed to disable sleep inhibition, exit code:", exitCode)
                // Revert state if command failed
                if (root.hasMediaDevices) {
                    root.sleepInhibited = true
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
            console.log("Enabling sleep inhibition (media device detected)")
            // Update icon immediately
            root.sleepInhibited = true
            // Stop process if already running
            if (inhibitEnableProcess.running) {
                inhibitEnableProcess.running = false
            }
            // Wait a moment then start
            Qt.callLater(() => {
                inhibitEnableProcess.running = true
            })
        } else if (!root.hasMediaDevices && root.sleepInhibited) {
            // Disable sleep inhibition
            console.log("Disabling sleep inhibition (no media devices)")
            // Update icon immediately
            root.sleepInhibited = false
            // Stop process if already running
            if (inhibitDisableProcess.running) {
                inhibitDisableProcess.running = false
            }
            // Wait a moment then start
            Qt.callLater(() => {
                inhibitDisableProcess.running = true
            })
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
