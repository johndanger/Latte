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
    property string mode: "auto" // "auto" or "manual"
    
    onSleepInhibitedChanged: {
        console.log("sleepInhibited changed to:", sleepInhibited)
    }
    
    // Popout content for mode selection
    popoutContent: Component {
        PopoutComponent {
            id: popout
            
            headerText: "Amphetamine"
            detailsText: "Select auto for when a media player is detected, select manual to toggle sleep inhibition manually"
            
            Column {
                width: parent.width
                spacing: Theme.spacingS
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: root.mode === "auto" ? Theme.primary : "transparent"
                    radius: 4
                    border.color: "#40000000"
                    border.width: 3
                    
                    StyledText {
                        anchors.centerIn: parent
                        text: "Auto (Media Detection)"
                        color: root.mode === "auto" ? "#000000" : "#FFFFFF"
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.mode = "auto"
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: root.mode === "manual" ? Theme.primary : "transparent"
                    radius: 4
                    border.color: "#40000000"
                    border.width: 3
                    
                    StyledText {
                        anchors.centerIn: parent
                        text: "Manual (On/Off)"
                        color: root.mode === "manual" ? "#000000" : "#FFFFFF"
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.mode = "manual"
                        }
                    }
                }
                
                // Toggle button for manual mode
                Rectangle {
                    width: parent.width
                    height: 40
                    visible: root.mode === "manual"
                    color: root.sleepInhibited ? Theme.primary : Theme.surfaceVariant
                    radius: 4
                    border.color: "#40000000"
                    border.width: 3
                    
                    StyledText {
                        anchors.centerIn: parent
                        text: root.sleepInhibited ? "Disable Sleep Inhibition" : "Enable Sleep Inhibition"
                        color: root.sleepInhibited ? "#000000" : "#FFFFFF"
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.handleClick()
                        }
                    }
                }
            }
        }
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
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton && root.mode === "manual") {
                        // Right click: toggle sleep inhibition (only in manual mode)
                        root.handleClick()
                    }
                }
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
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton && root.mode === "manual") {
                        // Right click: toggle sleep inhibition (only in manual mode)
                        root.handleClick()
                    }
                }
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
        // Only auto-update if in auto mode
        if (root.mode !== "auto") {
            return
        }
        
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
    
    function handleClick() {
        if (root.mode === "manual") {
            // Toggle sleep inhibition manually
            if (root.sleepInhibited) {
                root.disableSleepInhibition()
            } else {
                root.enableSleepInhibition()
            }
        }
    }
    
    function enableSleepInhibition() {
        console.log("Manually enabling sleep inhibition")
        root.sleepInhibited = true
        if (inhibitEnableProcess.running) {
            inhibitEnableProcess.running = false
        }
        Qt.callLater(() => {
            inhibitEnableProcess.running = true
        })
    }
    
    function disableSleepInhibition() {
        console.log("Manually disabling sleep inhibition")
        root.sleepInhibited = false
        if (inhibitDisableProcess.running) {
            inhibitDisableProcess.running = false
        }
        Qt.callLater(() => {
            inhibitDisableProcess.running = true
        })
    }
    
    function showPopout() {
        // Access the variant to show the popout
        // Try to find the variant that has the showPopout method
        if (root.variants) {
            for (var i = 0; i < root.variants.length; i++) {
                var variant = root.variants[i]
                if (variant) {
                    // Try different possible method names
                    if (typeof variant.showPopout === "function") {
                        variant.showPopout()
                        return
                    } else if (typeof variant.openPopout === "function") {
                        variant.openPopout()
                        return
                    } else if (variant.popout && typeof variant.popout.open === "function") {
                        variant.popout.open()
                        return
                    }
                }
            }
        }
        console.warn("Could not find popout method to show popout")
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
