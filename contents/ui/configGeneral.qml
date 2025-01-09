import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_showBrightness: showBrightnessCheckbox.checked
    property alias cfg_showVolume: showVolumeCheckbox.checked
    property alias cfg_showNightLight: showNightLightCheckbox.checked
    property alias cfg_showMediaPlayer: showMediaPlayerCheckbox.checked
    property alias cfg_terminalApp: terminalComboBox.currentValue

    Kirigami.Heading {
        Kirigami.FormData.label: i18n("Display Elements")
        text: i18n("Show or hide elements:")
    }

    QQC2.CheckBox {
        id: showBrightnessCheckbox
        text: i18n("Show brightness slider")
    }

    QQC2.CheckBox {
        id: showVolumeCheckbox
        text: i18n("Show volume slider")
    }

    QQC2.CheckBox {
        id: showNightLightCheckbox
        text: i18n("Show Night Light button")
    }

    QQC2.CheckBox {
        id: showMediaPlayerCheckbox
        text: i18n("Show media player")
    }

    Item { Kirigami.FormData.isSection: true }

    Kirigami.Heading {
        Kirigami.FormData.label: i18n("Terminal Settings")
        text: i18n("Choose terminal application:")
    }

    QQC2.ComboBox {
        id: terminalComboBox
        Kirigami.FormData.label: i18n("Terminal:")
        model: [
            { text: i18n("Konsole"), value: "konsole" },
            { text: i18n("Kitty"), value: "kitty" },
            { text: i18n("Wave"), value: "waveterm" }
        ]
        textRole: "text"
        valueRole: "value"
        currentIndex: {
            switch(plasmoid.configuration.terminalApp) {
                case "kitty": return 1;
                case "waveterm": return 2;
                default: return 0;
            }
        }
    }

    Item { Kirigami.FormData.isSection: true }

    Kirigami.Heading {
        Kirigami.FormData.label: i18n("Language Settings")
        text: i18n("Choose interface language:")
    }

    QQC2.ComboBox {
        id: languageComboBox
        Kirigami.FormData.label: i18n("Interface language:")
        model: [
            { text: i18n("English"), value: "en" },
            { text: i18n("Русский"), value: "ru" },
            { text: i18n("Čeština"), value: "cs" }
        ]
        textRole: "text"
        valueRole: "value"
        currentIndex: {
            switch(plasmoid.configuration.language) {
                case "ru": return 1;
                case "cs": return 2;
                default: return 0;
            }
        }
        onCurrentValueChanged: plasmoid.configuration.language = currentValue
    }
} 