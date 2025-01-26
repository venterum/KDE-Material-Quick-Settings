import QtQuick 2.0
import QtQuick.Window 2.2
import QtQuick.Layouts
import QtQuick.Controls 2.5
import Qt5Compat.GraphicalEffects
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.private.mpris as Mpris
import org.kde.kquickcontrolsaddons 2.0 as KQuickAddons
import "translations.js" as Translations

PlasmoidItem {
    id: root
    
    property string iconPath: Qt.resolvedUrl("../icons/")
    
    preferredRepresentation: compactRepresentation

    property color accentColor: Qt.rgba(Kirigami.Theme.highlightColor.r,
                                      Kirigami.Theme.highlightColor.g,
                                      Kirigami.Theme.highlightColor.b,
                                      0.2)
    property int cornerRadius: Kirigami.Units.gridUnit * 1.2
    property real buttonOpacity: 0.1

    property bool wifiEnabled: false
    property bool bluetoothEnabled: false
    property bool isMuted: false
    
    // Media properties
    property var currentPlayer: mpris2Model.currentPlayer
    property string networkName: ""
    property string bluetoothDeviceName: ""
    property bool canControl: mpris2Model.currentPlayer?.canControl ?? false
    property bool canGoPrevious: mpris2Model.currentPlayer?.canGoPrevious ?? false
    property bool canGoNext: mpris2Model.currentPlayer?.canGoNext ?? false
    property bool canPlay: mpris2Model.currentPlayer?.canPlay ?? false
    property bool canPause: mpris2Model.currentPlayer?.canPause ?? false
    property int playbackStatus: mpris2Model.currentPlayer?.playbackStatus ?? 0
    property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing

    // Battery monitoring
    P5Support.DataSource {
        id: pmSource
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
        
        readonly property bool hasBattery: data["Battery"]["Has Battery"]
        readonly property int batteryPercent: data["Battery"]["Percent"]
        readonly property bool pluggedIn: data["AC Adapter"] ? data["AC Adapter"]["Plugged in"] : false
    }

    // Volume control
    P5Support.DataSource {
        id: pulseAudio
        engine: "executable"
        
        function setVolume(volume) {
            connectSource("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (volume/100).toFixed(2))
        }
        
        function getVolume() {
            connectSource("wpctl get-volume @DEFAULT_AUDIO_SINK@")
        }
        
        function toggleMute() {
            connectSource("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
        }
        
        function getMuteStatus() {
            connectSource("wpctl get-volume @DEFAULT_AUDIO_SINK@")
        }
        
        onNewData: function(sourceName, data) {
            if (sourceName.indexOf("get-volume") !== -1) {
                var match = data.stdout.match(/Volume: ([0-9.]+)/)
                if (match && match[1]) {
                    var volume = Math.round(parseFloat(match[1]) * 100)
                    var volumeControl = volumeSlider
                    if (volumeControl && !volumeControl.pressed) {
                        volumeControl.value = volume
                        volumeControl.parent.parent.currentVolume = volume
                    }
                }
                isMuted = data.stdout.indexOf("MUTED") !== -1
            }
            disconnectSource(sourceName)
        }
    }

    // Brightness control
    P5Support.DataSource {
        id: brightnessSource
        engine: "executable"
        
        function getBrightness() {
            connectSource("brightnessctl -m")
        }
        
        function setBrightness(value) {
            connectSource("brightnessctl set " + Math.round(value) + "% -q")
        }
        
        onNewData: function(sourceName, data) {
            if (sourceName === "brightnessctl -m") {
                var values = data.stdout.trim().split(',')
                if (values.length >= 3) {
                    var percentage = Math.round(parseFloat(values[2]))
                    var brightnessControl = brightnessSlider
                    if (brightnessControl && !brightnessControl.pressed) {
                        brightnessControl.value = percentage
                        brightnessControl.parent.parent.currentBrightness = percentage
                    }
                }
            }
            disconnectSource(sourceName)
        }
    }

    // Network control functions
    function toggleWifi() {
        executable.run("nmcli radio wifi " + (!wifiEnabled ? "on" : "off"))
    }

    function toggleBluetooth() {
        executable.run("bluetoothctl power " + (!bluetoothEnabled ? "on" : "off"))
    }

    // System commands executor
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        
        function run(cmd) {
            connectSource(cmd)
        }
        
        Component.onDestruction: {
            for (var i = 0; i < connectedSources.length; i++) {
                disconnectSource(connectedSources[i])
            }
        }
        
        onNewData: function(sourceName, data) {
            var stdout = data["stdout"]
            var command = sourceName
            
            if (command.indexOf("nmcli radio wifi") !== -1) {
                wifiEnabled = (stdout.trim() === "enabled")
            } 
            else if (command.indexOf("nmcli -t -f NAME,DEVICE connection show --active") !== -1) {
                networkName = stdout.split('\n')[0].split(':')[0]
            }
            else if (command.indexOf("bluetoothctl show") !== -1) {
                bluetoothEnabled = stdout.indexOf("Powered: yes") !== -1
            }
            else if (command.indexOf("bluetoothctl devices Connected") !== -1) {
                bluetoothDeviceName = stdout.trim() ? stdout.split(' ').slice(2).join(' ') : ""
            }
            else if (command === "qdbus org.kde.KWin /ColorCorrect org.kde.kwin.ColorCorrect.nightColorActive") {
                nightShiftEnabled = (stdout.trim() === "true")
            }
            
            disconnectSource(sourceName)
        }
    }

    // Media control
    Mpris.Mpris2Model {
        id: mpris2Model
    }

    // Update timer
    Timer {
        id: updateTimer
        interval: 500
        running: root.expanded || root.visible
        repeat: true
        onTriggered: {
            executable.run("nmcli radio wifi")
            executable.run("nmcli -t -f NAME,DEVICE connection show --active")
            executable.run("bluetoothctl show | grep Powered")
            executable.run("bluetoothctl devices Connected")
            pulseAudio.getMuteStatus()
            brightnessSource.getBrightness()
            pulseAudio.getVolume()
            pmSource.connectedSources = ["Battery", "AC Adapter"]
            executable.run("qdbus org.kde.KWin /ColorCorrect org.kde.kwin.ColorCorrect.nightColorActive")
        }
    }

    // Compact representation
    compactRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 2
        Layout.maximumWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumWidth

        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: width
            source: "configure"
            opacity: 0.8
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // Full representation
    fullRepresentation: Rectangle {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: {
            let height = Kirigami.Units.gridUnit * 4
            height += Math.ceil(buttonsGrid.visibleButtons / 2) * 
                     (buttonsGrid.buttonHeight + buttonsGrid.spacing)
            
            // Player
            if (cfg_showMediaPlayer && mpris2Model.currentPlayer !== null) {
                height += Kirigami.Units.gridUnit * 9
            }
            
            // Sliders
            if (cfg_showVolume) height += Kirigami.Units.gridUnit * 3
            if (cfg_showBrightness) height += Kirigami.Units.gridUnit * 3
            
            height += Kirigami.Units.gridUnit * 3
            height += Kirigami.Units.largeSpacing * 8
            
            return height
        }
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r, 
                      Kirigami.Theme.backgroundColor.g, 
                      Kirigami.Theme.backgroundColor.b, 0.98)
        radius: cornerRadius

        Behavior on Layout.preferredHeight {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.InOutQuad
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            // Grid of buttons
            Grid {
                Layout.fillWidth: true
                columns: 2
                spacing: Kirigami.Units.largeSpacing
                property int visibleButtons: {
                    let count = 4
                    if (cfg_showNightLight) count++
                    return count
                }
                
                property real buttonWidth: (parent.width - (columns - 1) * spacing) / columns
                property real buttonHeight: Kirigami.Units.gridUnit * 4

                // WiFi Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: wifiEnabled ? Qt.rgba(Kirigami.Theme.highlightColor.r, 
                                                Kirigami.Theme.highlightColor.g, 
                                                Kirigami.Theme.highlightColor.b, 
                                                0.3) :
                          wifiMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                              Kirigami.Theme.textColor.g, 
                                                              Kirigami.Theme.textColor.b, 
                                                              buttonOpacity * 1.5) :
                          Qt.rgba(Kirigami.Theme.textColor.r, 
                                                    Kirigami.Theme.textColor.g, 
                                 Kirigami.Theme.textColor.b, 
                                 buttonOpacity)
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "network-wireless"
                            icon.source: "icons/wifi.png"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            PlasmaComponents.Label {
                                text: Translations.getTranslation("Network", language)
                                font.weight: Font.Medium
                            }

                            PlasmaComponents.Label {
                                text: wifiEnabled ? 
                                      Translations.getTranslation("On", language) : 
                                      Translations.getTranslation("Off", language)
                                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                opacity: 0.7
                            }

                            PlasmaComponents.Label {
                                text: networkName || Translations.getTranslation("Not Connected", language)
                                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                opacity: 0.7
                            }
                        }
                    }

                    MouseArea {
                        id: wifiMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            if (mouse.button === Qt.RightButton) {
                                executable.run("kcmshell6 kcm_networkmanagement")
                            } else {
                                toggleWifi()
                            }
                        }
                    }
                }

                // Screenshot Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: screenshotMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                                   Kirigami.Theme.textColor.g, 
                                                                   Kirigami.Theme.textColor.b, 
                                                                   buttonOpacity * 1.5) :
                          Qt.rgba(Kirigami.Theme.textColor.r, 
                                 Kirigami.Theme.textColor.g, 
                                 Kirigami.Theme.textColor.b, 
                                 buttonOpacity)
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "camera-photo"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }

                            PlasmaComponents.Label {
                            text: Translations.getTranslation("Screenshot", language)
                                font.weight: Font.Medium
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: screenshotMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: executable.run("spectacle -r")
                    }
                }

                // Bluetooth Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: bluetoothEnabled ? Qt.rgba(Kirigami.Theme.highlightColor.r, 
                                                     Kirigami.Theme.highlightColor.g, 
                                                     Kirigami.Theme.highlightColor.b, 
                                                     0.3) :
                                              bluetoothMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                                     Kirigami.Theme.textColor.g, 
                                                                     Kirigami.Theme.textColor.b, 
                                                                     buttonOpacity * 1.5) :
                          Qt.rgba(Kirigami.Theme.textColor.r, 
                                 Kirigami.Theme.textColor.g, 
                                 Kirigami.Theme.textColor.b, 
                                 buttonOpacity)
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "bluetooth"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                        PlasmaComponents.Label {
                                text: Translations.getTranslation("Bluetooth", language)
                            font.weight: Font.Medium
                            }
                            
                            PlasmaComponents.Label {
                                text: bluetoothEnabled ? 
                                      Translations.getTranslation("On", language) : 
                                      Translations.getTranslation("Off", language)
                                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                opacity: 0.7
                            }
                            
                            PlasmaComponents.Label {
                                text: bluetoothDeviceName || Translations.getTranslation("Not Connected", language)
                                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                opacity: 0.7
                            }
                        }
                    }

                    MouseArea {
                        id: bluetoothMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            if (mouse.button === Qt.RightButton) {
                                executable.run("kcmshell6 kcm_bluetooth")
                            } else {
                                toggleBluetooth()
                            }
                        }
                    }
                }

                // Night Shift Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: nightShiftEnabled ? Qt.rgba(Kirigami.Theme.highlightColor.r, 
                                                     Kirigami.Theme.highlightColor.g, 
                                                     Kirigami.Theme.highlightColor.b, 
                                                     0.3) :
                           nightShiftMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                                       Kirigami.Theme.textColor.g, 
                                                                       Kirigami.Theme.textColor.b, 
                                                                       buttonOpacity * 1.5) :
                           Qt.rgba(Kirigami.Theme.textColor.r, 
                                  Kirigami.Theme.textColor.g, 
                                  Kirigami.Theme.textColor.b, 
                                  buttonOpacity)
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    visible: cfg_showNightLight

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "redshift"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }

                        PlasmaComponents.Label {
                            text: Translations.getTranslation("Night Light", language)
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: nightShiftMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            toggleNightShift()
                        }
                    }
                }

                // Volume Mute Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: isMuted ? Qt.rgba(Kirigami.Theme.highlightColor.r, 
                                             Kirigami.Theme.highlightColor.g, 
                                             Kirigami.Theme.highlightColor.b, 
                                             0.3) :
                           muteMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                               Kirigami.Theme.textColor.g, 
                                                               Kirigami.Theme.textColor.b, 
                                                               buttonOpacity * 1.5) :
                           Qt.rgba(Kirigami.Theme.textColor.r, 
                                  Kirigami.Theme.textColor.g, 
                                  Kirigami.Theme.textColor.b, 
                                  buttonOpacity)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: isMuted ? "audio-volume-muted" : "audio-volume-high"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }

                        PlasmaComponents.Label {
                            text: isMuted ? Translations.getTranslation("Unmute", language) : Translations.getTranslation("Mute", language)
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: muteMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: pulseAudio.toggleMute()
                    }
                }

                // Terminal Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: terminalMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                                   Kirigami.Theme.textColor.g, 
                                                                   Kirigami.Theme.textColor.b, 
                                                                   buttonOpacity * 1.5) :
                           Qt.rgba(Kirigami.Theme.textColor.r, 
                                  Kirigami.Theme.textColor.g, 
                                  Kirigami.Theme.textColor.b, 
                                  buttonOpacity)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "utilities-terminal"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            PlasmaComponents.Label {
                                text: Translations.getTranslation("Terminal", language)
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                            }

                            PlasmaComponents.Label {
                                text: {
                                    switch(cfg_terminalApp) {
                                        case "kitty": return "Kitty";
                                        case "waveterm": return "Wave";
                                        default: return "Konsole";
                                    }
                                }
                                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                opacity: 0.7
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        id: terminalMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: executable.run(cfg_terminalApp)
                    }
                }
            }

            // Media Controls Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 9
                radius: height / 8
                Layout.topMargin: Kirigami.Units.smallSpacing
                color: Qt.rgba(Kirigami.Theme.textColor.r, 
                              Kirigami.Theme.textColor.g, 
                              Kirigami.Theme.textColor.b, 
                              buttonOpacity)
                visible: cfg_showMediaPlayer && mpris2Model.currentPlayer !== null

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.gridUnit
                    spacing: Kirigami.Units.smallSpacing
                    RowLayout {
                        Layout.fillWidth: true
                    spacing: Kirigami.Units.gridUnit

                        // Album art
                    Rectangle {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: height * 0.15
                        color: Qt.rgba(Kirigami.Theme.textColor.r, 
                                     Kirigami.Theme.textColor.g, 
                                     Kirigami.Theme.textColor.b, 
                                     buttonOpacity)

                        Image {
                            id: albumArtImage
                            anchors.fill: parent
                            source: mpris2Model.currentPlayer?.artUrl ?? ""
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: albumArtImage.width
                                    height: albumArtImage.height
                                    radius: height * 0.15
                                }
                            }
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            source: "media-album-track"
                            width: parent.width * 0.7
                            height: width
                            opacity: 0.7
                            visible: !albumArtImage.visible
                        }
                    }

                        // Track info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            text: mpris2Model.currentPlayer?.identity ?? ""
                            font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.9)
                            opacity: 0.7
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        PlasmaComponents.Label {
                            text: mpris2Model.currentPlayer?.track ?? 
                                  Translations.getTranslation("No media playing", language)
                            font.weight: Font.Medium
                            font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 1.1)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        PlasmaComponents.Label {
                            text: mpris2Model.currentPlayer?.artist ?? ""
                            opacity: 0.7
                            font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.9)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }

                        // Play/Pause button
                        PlasmaComponents.Button {
                            icon.name: isPlaying ? "media-playback-pause" : "media-playback-start"
                            flat: true
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                            icon.width: Kirigami.Units.gridUnit * 2.5
                            icon.height: Kirigami.Units.gridUnit * 2.5
                            enabled: canControl && (isPlaying ? canPause : canPlay)
                            onClicked: mpris2Model.currentPlayer.PlayPause()
                            
                            background: Rectangle {
                                radius: 12
                                color: parent.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                              Kirigami.Theme.textColor.g, 
                                                              Kirigami.Theme.textColor.b, 
                                                              0.3) :
                                       parent.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                              Kirigami.Theme.textColor.g, 
                                                              Kirigami.Theme.textColor.b, 
                                                              0.2) :
                                       Qt.rgba(Kirigami.Theme.textColor.r, 
                                              Kirigami.Theme.textColor.g, 
                                              Kirigami.Theme.textColor.b, 
                                              0.1)
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Progress bar and controls
                    ColumnLayout {
                        Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                        // Progress bar
                            PlasmaComponents.Slider {
                                id: seekSlider
                                Layout.fillWidth: true
                                from: 0
                                to: length
                                value: position
                                enabled: canSeek

                                Connections {
                                    target: root
                                    function onPositionChanged() {
                                        if (!seekSlider.pressed) {
                                            seekSlider.value = position
                                        }
                                    }
                                    function onLengthChanged() {
                                        seekSlider.value = 0
                                        seekSlider.to = length
                                        if (mpris2Model.currentPlayer) {
                                            mpris2Model.currentPlayer.updatePosition()
                                        }
                                    }
                                }

                                Timer {
                                    id: queuedPositionUpdate
                                    interval: 100
                                    onTriggered: {
                                        if (mpris2Model.currentPlayer) {
                                            mpris2Model.currentPlayer.position = seekSlider.value
                                        }
                                    }
                                }

                                onMoved: {
                                    if (canSeek) {
                                        queuedPositionUpdate.restart()
                                    }
                                }

                                onPressedChanged: {
                                    if (!pressed && canSeek) {
                                        mpris2Model.currentPlayer.position = value
                                        mpris2Model.currentPlayer.updatePosition()
                                    }
                                }
                            }

                        // Time and controls
                            RowLayout {
                                Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            // Combined time label
                                PlasmaComponents.Label {
                                text: formatTime(position) + " / " + formatTime(length)
                                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize)
                                font.weight: Font.Bold
                                    opacity: 0.7
                                }

                                Item { Layout.fillWidth: true }

                            // Track controls
                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                PlasmaComponents.Button {
                                    icon.name: "media-skip-backward"
                                    flat: true
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                    enabled: canControl && canGoPrevious
                                    onClicked: mpris2Model.currentPlayer.Previous()
                                }

                                PlasmaComponents.Button {
                                    icon.name: "media-seek-backward"
                                    flat: true
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                    enabled: canSeek
                                    onClicked: {
                                        if (mpris2Model.currentPlayer) {
                                            let newPosition = Math.max(0, position - 10000000) // 10 секунд в микросекундах
                                            mpris2Model.currentPlayer.position = newPosition
                                            mpris2Model.currentPlayer.updatePosition()
                                        }
                                    }
                                }

                                PlasmaComponents.Button {
                                    icon.name: "media-seek-forward"
                                    flat: true
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                    enabled: canSeek
                                    onClicked: {
                                        if (mpris2Model.currentPlayer) {
                                            let newPosition = Math.min(length, position + 10000000) // 10 секунд в микросекундах
                                            mpris2Model.currentPlayer.position = newPosition
                                            mpris2Model.currentPlayer.updatePosition()
                                }
                            }
                            }

                            PlasmaComponents.Button {
                                icon.name: "media-skip-forward"
                                flat: true
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                enabled: canControl && canGoNext
                                onClicked: mpris2Model.currentPlayer.Next()
                                }
                            }
                        }
                    }
                }
            }

            // Sliders Section
                Rectangle {
                    Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 6
                radius: cornerRadius
                Layout.topMargin: Kirigami.Units.smallSpacing
                    color: Qt.rgba(Kirigami.Theme.textColor.r, 
                                Kirigami.Theme.textColor.g, 
                                Kirigami.Theme.textColor.b, 
                                buttonOpacity)
                visible: cfg_showVolume || cfg_showBrightness

                property bool isHovered: false

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
                
                color: isHovered ? 
                       Qt.rgba(Kirigami.Theme.textColor.r, 
                               Kirigami.Theme.textColor.g, 
                               Kirigami.Theme.textColor.b, 
                               buttonOpacity * 1.5) :
                       Qt.rgba(Kirigami.Theme.textColor.r, 
                               Kirigami.Theme.textColor.g, 
                               Kirigami.Theme.textColor.b, 
                               buttonOpacity)

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.isHovered = true
                    onExited: parent.isHovered = false
                }

                ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    // Volume Control
                    RowLayout {
                        Layout.fillWidth: true
                        visible: cfg_showVolume
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: isMuted ? "audio-volume-muted" : "audio-volume-high"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: pulseAudio.toggleMute()
                        }

                        PlasmaComponents.Slider {
                            id: volumeSlider
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.smallSpacing
                            from: 0
                            to: 100
                            value: parent.parent.parent.currentVolume
                            onMoved: {
                                parent.parent.parent.currentVolume = value
                                pulseAudio.setVolume(value)
                            }
                        }

                        PlasmaComponents.Label {
                            text: parent.parent.parent.currentVolume + "%"
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            horizontalAlignment: Text.AlignRight
                            font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.9)
                            opacity: 0.7
                    }
                }

                    // Brightness Control
                    RowLayout {
                    Layout.fillWidth: true
                    visible: cfg_showBrightness
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "display-brightness-symbolic"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            Layout.alignment: Qt.AlignVCenter
                        }

                        PlasmaComponents.Slider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.smallSpacing
                            from: 0
                            to: 100
                            value: parent.parent.parent.currentBrightness
                            onMoved: {
                                parent.parent.parent.currentBrightness = value
                                brightnessSource.setBrightness(value)
                            }
                        }

                        PlasmaComponents.Label {
                            text: parent.parent.parent.currentBrightness + "%"
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            horizontalAlignment: Text.AlignRight
                            font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.9)
                            opacity: 0.7
                        }
                    }
                }

                property int currentVolume: 0
                property int currentBrightness: 0
            }

            // Bottom Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                radius: cornerRadius
                Layout.topMargin: Kirigami.Units.smallSpacing
                color: Qt.rgba(Kirigami.Theme.textColor.r, 
                              Kirigami.Theme.textColor.g, 
                              Kirigami.Theme.textColor.b, 
                              buttonOpacity)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.gridUnit * 0.75
                    spacing: Kirigami.Units.smallSpacing

                    // Power Button
                    PlasmaComponents.Button {
                        icon.name: "system-shutdown-symbolic"
                        flat: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredWidth: Layout.preferredHeight
                        onClicked: {
                            executable.run("qdbus org.kde.LogoutPrompt /LogoutPrompt promptShutDown")
                            root.expanded = false
                        }
                        
                        background: Rectangle {
                            radius: width / 2
                            color: parent.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                          Kirigami.Theme.textColor.g, 
                                                          Kirigami.Theme.textColor.b, 
                                                          0.3) :
                                   parent.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                          Kirigami.Theme.textColor.g, 
                                                          Kirigami.Theme.textColor.b, 
                                                          0.2) :
                                   Qt.rgba(Kirigami.Theme.textColor.r, 
                                          Kirigami.Theme.textColor.g, 
                                          Kirigami.Theme.textColor.b, 
                                          0.1)
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    // Reboot Button
                    PlasmaComponents.Button {
                        icon.name: "reload_page"
                        flat: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredWidth: Layout.preferredHeight
                        onClicked: {
                            executable.run("qdbus org.kde.LogoutPrompt /LogoutPrompt promptReboot")
                            root.expanded = false
                        }
                        
                        background: Rectangle {
                            radius: width / 2
                            color: parent.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                          Kirigami.Theme.textColor.g, 
                                                          Kirigami.Theme.textColor.b, 
                                                          0.3) :
                                   parent.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                          Kirigami.Theme.textColor.g, 
                                                          Kirigami.Theme.textColor.b, 
                                                          0.2) :
                                   Qt.rgba(Kirigami.Theme.textColor.r, 
                                          Kirigami.Theme.textColor.g, 
                                          Kirigami.Theme.textColor.b, 
                                          0.1)
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    // Logout Button
                        PlasmaComponents.Button {
                        icon.name: "system-log-out-symbolic"
                        flat: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredWidth: Layout.preferredHeight
                        onClicked: {
                            executable.run("qdbus org.kde.LogoutPrompt /LogoutPrompt promptLogout")
                            root.expanded = false
                        }
                        
                        background: Rectangle {
                            radius: width / 2
                            color: parent.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                          Kirigami.Theme.textColor.g, 
                                                          Kirigami.Theme.textColor.b, 
                                                          0.3) :
                                   parent.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                          Kirigami.Theme.textColor.g, 
                                                          Kirigami.Theme.textColor.b, 
                                                          0.2) :
                                   Qt.rgba(Kirigami.Theme.textColor.r, 
                                          Kirigami.Theme.textColor.g, 
                                          Kirigami.Theme.textColor.b, 
                                          0.1)
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Battery Status
                        PlasmaComponents.Label {
                            text: {
                            if (!pmSource.hasBattery) return ""
                            let batteryText = pmSource.batteryPercent + "%"
                            if (pmSource.data["Battery"]["Time to empty"]) {
                                    let timeToEmpty = Math.round(pmSource.data["Battery"]["Time to empty"] / 60)
                                    batteryText += " • " + timeToEmpty + "m"
                                }
                                return batteryText
                            }
                            opacity: 0.7
                        visible: pmSource.hasBattery
                    }

                    // Settings Button
                    PlasmaComponents.Button {
                        icon.name: "configure"
                        flat: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                        Layout.preferredWidth: Layout.preferredHeight
                        onClicked: {
                            executable.run("kcmshell6 kcm_landingpage")
                            root.expanded = false
                        }
                        
                        background: Rectangle {
                            radius: width / 2
                            color: parent.pressed ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                          Kirigami.Theme.textColor.g, 
                                                          Kirigami.Theme.textColor.b, 
                                                          0.3) :
                                           parent.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, 
                                                          Kirigami.Theme.textColor.g, 
                                                          Kirigami.Theme.textColor.b, 
                                                          0.2) :
                                           Qt.rgba(Kirigami.Theme.textColor.r, 
                                                  Kirigami.Theme.textColor.g, 
                                                  Kirigami.Theme.textColor.b, 
                                                  0.1)
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                }
            }
        }
    }

    // Night Shift
    property bool nightShiftEnabled: false

    function toggleNightShift() {
        if (!nightShiftEnabled) {
            executable.run("qdbus org.kde.KWin /ColorCorrect org.kde.kwin.ColorCorrect.setNightColorActive true")
            executable.run("qdbus org.kde.KWin /ColorCorrect org.kde.kwin.ColorCorrect.setTemperature 4500")
        } else {
            executable.run("qdbus org.kde.KWin /ColorCorrect org.kde.kwin.ColorCorrect.setNightColorActive false")
        }
        nightShiftEnabled = !nightShiftEnabled
    }

    property bool cfg_showBrightness: plasmoid.configuration.showBrightness
    property bool cfg_showVolume: plasmoid.configuration.showVolume
    property bool cfg_showNightLight: plasmoid.configuration.showNightLight
    property bool cfg_showMediaPlayer: plasmoid.configuration.showMediaPlayer
    property string cfg_terminalApp: plasmoid.configuration.terminalApp
    property real rate: mpris2Model.currentPlayer?.rate ?? 1
    property double length: mpris2Model.currentPlayer?.length ?? 0
    property double position: {
        if (mpris2Model.currentPlayer) {
            return mpris2Model.currentPlayer.position
        }
        return 0
    }
    property bool canSeek: mpris2Model.currentPlayer?.canSeek ?? false
    property bool disablePositionUpdate: false
    property bool keyPressed: false

    Timer {
        id: positionUpdateTimer
        interval: 1000
        repeat: true
        running: isPlaying && mpris2Model.currentPlayer !== null
        onTriggered: {
            if (mpris2Model.currentPlayer) {
                mpris2Model.currentPlayer.updatePosition()
            }
        }
    }

    function formatTime(microseconds) {
        let seconds = Math.floor(microseconds / 1000000)
        let minutes = Math.floor(seconds / 60)
        seconds = seconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    Keys.onPressed: keyPressed = true

    Keys.onReleased: event => {
        keyPressed = false
        
        if (!event.modifiers) {
            event.accepted = true
            
            if (event.key === Qt.Key_J) {
                seekSlider.value = Math.max(0, seekSlider.value - 5000000)
                if (!disablePositionUpdate) {
                    queuedPositionUpdate.restart()
                }
            } else if (event.key === Qt.Key_L) {
                seekSlider.value = Math.min(seekSlider.to, seekSlider.value + 5000000)
                if (!disablePositionUpdate) {
                    queuedPositionUpdate.restart()
                }
            } else {
                event.accepted = false
            }
        }
    }

    property string language: plasmoid.configuration.language
} 