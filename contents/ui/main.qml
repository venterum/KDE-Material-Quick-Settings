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
            connectSource("pactl set-sink-volume @DEFAULT_SINK@ " + volume + "%")
        }
        
        function getVolume() {
            connectSource("pactl get-sink-volume @DEFAULT_SINK@")
        }
        
        function toggleMute() {
            connectSource("pactl set-sink-mute @DEFAULT_SINK@ toggle")
        }
        
        function getMuteStatus() {
            connectSource("pactl get-sink-mute @DEFAULT_SINK@")
        }
        
        onNewData: function(sourceName, data) {
            if (sourceName.indexOf("get-sink-volume") !== -1) {
                var match = data.stdout.match(/(\d+)%/)
                if (match && match[1]) {
                    var volume = parseInt(match[1])
                    var volumeControl = fullRepresentation.findChild("volumeSlider")?.parent?.parent
                    if (volumeControl) {
                        volumeControl.currentVolume = volume
                    }
                }
            }
            else if (sourceName.indexOf("get-sink-mute") !== -1) {
                isMuted = data.stdout.indexOf("yes") !== -1
            }
            disconnectSource(sourceName)
        }
    }

    // Brightness control
    P5Support.DataSource {
        id: brightnessSource
        engine: "executable"
        
        function getBrightness() {
            connectSource("brightnessctl g")
        }
        
        function setBrightness(value) {
            connectSource("brightnessctl s " + value + "%")
        }
        
        onNewData: function(sourceName, data) {
            if (sourceName === "brightnessctl g") {
                var maxBrightness = 255
                var currentBrightness = parseInt(data.stdout.trim())
                var percentage = Math.round((currentBrightness / maxBrightness) * 100)
                var brightnessControl = fullRepresentation.findChild("brightnessSlider")?.parent?.parent
                if (brightnessControl) {
                    brightnessControl.currentBrightness = percentage
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
        
        onNewData: {
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
            else if (command === "pgrep redshift") {
                nightShiftEnabled = (stdout.trim() !== "")
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
            executable.run("pgrep redshift")
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
            
            // Высота сетки кнопок
            height += Math.ceil(buttonsGrid.visibleButtons / 2) * 
                     (buttonsGrid.buttonHeight + buttonsGrid.spacing)
            
            // Медиаплеер
            if (cfg_showMediaPlayer && mpris2Model.currentPlayer !== null) {
                height += Kirigami.Units.gridUnit * 9
            }
            
            // Слайдеры
            if (cfg_showVolume) height += Kirigami.Units.gridUnit * 3
            if (cfg_showBrightness) height += Kirigami.Units.gridUnit * 3
            
            // Нижняя панель
            height += Kirigami.Units.gridUnit * 3
            
            // Увеличим отступы
            height += Kirigami.Units.largeSpacing * 8
            
            return height
        }
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r, 
                      Kirigami.Theme.backgroundColor.g, 
                      Kirigami.Theme.backgroundColor.b, 0.98)
        radius: cornerRadius

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            // Grid of buttons
            Grid {
                Layout.fillWidth: true
                columns: 2
                spacing: Kirigami.Units.largeSpacing
                
                // Вычисляем количество видимых кнопок
                property int visibleButtons: {
                    let count = 4 // WiFi и Bluetooth всегда видимы
                    if (cfg_showNightLight) count++
                    return count
                }
                
                // Вычисляем размер кнопки на основе доступного пространства
                property real buttonWidth: (parent.width - (columns - 1) * spacing) / columns
                property real buttonHeight: Kirigami.Units.gridUnit * 4

                // WiFi Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: wifiEnabled ? accentColor : 
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
                                text: i18n("Network")
                                font.weight: Font.Medium
                            }

                            PlasmaComponents.Label {
                                text: wifiEnabled ? i18n("On") : i18n("Off")
                                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                opacity: 0.7
                            }

                            PlasmaComponents.Label {
                                text: networkName || i18n("Not Connected")
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
                                executable.run("systemsettings5 network")  // Для Plasma 5
                                // или executable.run("kcmshell6 kcm_networkmanagement")  // Для Plasma 6
                            } else {
                                toggleWifi()
                            }
                        }
                    }
                }

                // Bluetooth Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: bluetoothEnabled ? accentColor : 
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
                                text: i18n("Bluetooth")
                                font.weight: Font.Medium
                            }
                            
                            PlasmaComponents.Label {
                                text: bluetoothEnabled ? i18n("On") : i18n("Off")
                                font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                opacity: 0.7
                            }
                            
                            PlasmaComponents.Label {
                                text: bluetoothDeviceName || i18n("Not Connected")
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
                                executable.run("systemsettings5 bluetooth")  // Для Plasma 5
                                // или executable.run("kcmshell6 kcm_bluetooth")  // Для Plasma 6
                            } else {
                                toggleBluetooth()
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
                            text: i18n("Screenshot")
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

                // Night Shift Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: nightShiftEnabled ? accentColor : 
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
                            text: i18n("Night Light")
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: nightShiftMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!nightShiftEnabled) {
                                executable.run("redshift -O 4500")
                            } else {
                                executable.run("redshift -x")
                            }
                            nightShiftEnabled = !nightShiftEnabled
                        }
                    }
                }

                // Volume Mute Button
                Rectangle {
                    width: parent.buttonWidth
                    height: parent.buttonHeight
                    radius: height / 4
                    color: isMuted ? accentColor : 
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
                            text: isMuted ? i18n("Unmute") : i18n("Mute")
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

                        PlasmaComponents.Label {
                            text: i18n("Terminal")
                            font.weight: Font.Medium
                            Layout.fillWidth: true
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

                    // Верхняя часть с обложкой, информацией и кнопкой play
                    RowLayout {
                        Layout.fillWidth: true
                    spacing: Kirigami.Units.gridUnit

                        // Обложка
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

                        // Информация о треке
                    ColumnLayout {
                        Layout.fillWidth: true
                            spacing: 0

                        PlasmaComponents.Label {
                            text: mpris2Model.currentPlayer?.track ?? i18n("No media playing")
                            font.weight: Font.Medium
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
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

                        // Кнопка Play/Pause
                        PlasmaComponents.Button {
                            icon.name: isPlaying ? "media-playback-pause" : "media-playback-start"
                            flat: true
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                            enabled: canControl && (isPlaying ? canPause : canPlay)
                            onClicked: mpris2Model.currentPlayer.PlayPause()
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Нижняя часть с прогресс-баром и кнопками управления
                        RowLayout {
                        Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents.Button {
                                icon.name: "media-skip-backward"
                                flat: true
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                enabled: canControl && canGoPrevious
                                onClicked: mpris2Model.currentPlayer.Previous()
                            }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            PlasmaComponents.Slider {
                                id: seekSlider
                                Layout.fillWidth: true
                                from: 0
                                to: length
                                value: position
                                enabled: canSeek

                                // Добавим обработчик изменения позиции
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

                            RowLayout {
                                Layout.fillWidth: true
                                PlasmaComponents.Label {
                                    text: formatTime(position)
                                    font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                    opacity: 0.7
                                }
                                Item { Layout.fillWidth: true }
                                PlasmaComponents.Label {
                                    text: formatTime(length)
                                    font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8)
                                    opacity: 0.7
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

            // Sliders Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // Volume Slider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    radius: height / 4
                    color: Qt.rgba(Kirigami.Theme.textColor.r, 
                                Kirigami.Theme.textColor.g, 
                                Kirigami.Theme.textColor.b, 
                                buttonOpacity)
                    visible: cfg_showVolume

                    property int currentVolume: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "audio-volume-high"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        }

                        PlasmaComponents.Slider {
                            id: volumeSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: parent.parent.currentVolume
                            onMoved: {
                                parent.parent.currentVolume = value
                                pulseAudio.setVolume(value)
                            }
                        }

                        PlasmaComponents.Label {
                            text: parent.parent.currentVolume + "%"
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Brightness Slider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    radius: height / 4
                    color: Qt.rgba(Kirigami.Theme.textColor.r, 
                                Kirigami.Theme.textColor.g, 
                                Kirigami.Theme.textColor.b, 
                                buttonOpacity)
                    visible: cfg_showBrightness

                    property int currentBrightness: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: "brightness"
                            flat: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        }

                        PlasmaComponents.Slider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: parent.parent.currentBrightness
                            onMoved: {
                                parent.parent.currentBrightness = value
                                brightnessSource.setBrightness(value)
                            }
                        }

                        PlasmaComponents.Label {
                            text: parent.parent.currentBrightness + "%"
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // Bottom Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                radius: height / 4
                Layout.topMargin: Kirigami.Units.smallSpacing
                color: Qt.rgba(Kirigami.Theme.textColor.r, 
                              Kirigami.Theme.textColor.g, 
                              Kirigami.Theme.textColor.b, 
                              buttonOpacity)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing

                    // Battery Status
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Button {
                            icon.name: {
                                if (!pmSource.hasBattery) return ""
                                if (pmSource.pluggedIn) return "battery-charging"
                                let percentage = pmSource.batteryPercent
                                if (percentage >= 90) return "battery-100"
                                if (percentage >= 70) return "battery-070"
                                if (percentage >= 40) return "battery-040"
                                if (percentage >= 20) return "battery-020"
                                return "battery-000"
                            }
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            visible: pmSource.hasBattery
                        }

                        PlasmaComponents.Label {
                            text: {
                                let batteryText = pmSource.hasBattery ? pmSource.batteryPercent + "%" : ""
                                if (pmSource.hasBattery && pmSource.data["Battery"]["Time to empty"]) {
                                    let timeToEmpty = Math.round(pmSource.data["Battery"]["Time to empty"] / 60)
                                    batteryText += " • " + timeToEmpty + "m"
                                }
                                return batteryText
                            }
                            opacity: 0.7
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Settings Button
                    PlasmaComponents.Button {
                        icon.name: "configure"
                        flat: true
                        onClicked: {
                            // Для Plasma 5
                            executable.run("systemsettings5 kcm_quick")
                            // Для Plasma 6 раскомментировать следующую строку и закомментировать предыдущую
                            // executable.run("kcmshell6 kcm_quick")
                            root.expanded = false
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
            executable.run("redshift -O 4500")
            nightShiftEnabled = true
        } else {
            executable.run("redshift -x")
            nightShiftEnabled = false
        }
    }

    // Add these properties at the beginning of PlasmoidItem
    property bool cfg_showBrightness: plasmoid.configuration.showBrightness
    property bool cfg_showVolume: plasmoid.configuration.showVolume
    property bool cfg_showNightLight: plasmoid.configuration.showNightLight
    property bool cfg_showMediaPlayer: plasmoid.configuration.showMediaPlayer
    property string cfg_terminalApp: plasmoid.configuration.terminalApp

    // Обновим свойства для отслеживания позиции
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

    // Добавим таймер для обновления позиции в секцию с другими таймерами
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

    // Добавим функцию форматирования времени
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
                // перемотка назад на 5с
                seekSlider.value = Math.max(0, seekSlider.value - 5000000)
                if (!disablePositionUpdate) {
                    queuedPositionUpdate.restart()
                }
            } else if (event.key === Qt.Key_L) {
                // перемотка вперед на 5с
                seekSlider.value = Math.min(seekSlider.to, seekSlider.value + 5000000)
                if (!disablePositionUpdate) {
                    queuedPositionUpdate.restart()
                }
            } else {
                event.accepted = false
            }
        }
    }
} 