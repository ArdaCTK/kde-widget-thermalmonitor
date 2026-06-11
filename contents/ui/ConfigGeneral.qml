import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Kirigami.FormLayout {
    id: configPage

    // ── settings bound to Plasmoid.configuration ──────────────────────────
    property alias cfg_pollInterval:   pollSlider.value
    property alias cfg_showCpu:        showCpuCheck.checked
    property alias cfg_showGpu1:       showGpu1Check.checked
    property alias cfg_showGpu2:       showGpu2Check.checked
    property alias cfg_showFans:       showFansCheck.checked
    property alias cfg_colorTheme:     colorThemeCombo.currentValue
    property alias cfg_fontSize:       fontSizeSpinner.value

    // ── Sensors section ────────────────────────────────────────────────────
    Kirigami.Separator {
        Kirigami.FormData.label: "Sensors"
        Kirigami.FormData.isSection: true
    }

    QQC2.CheckBox {
        id: showCpuCheck
        Kirigami.FormData.label: "Show CPU temperature"
        text: ""
    }

    QQC2.CheckBox {
        id: showGpu1Check
        Kirigami.FormData.label: "Show GPU temperature (dGPU)"
        text: ""
    }

    QQC2.CheckBox {
        id: showGpu2Check
        Kirigami.FormData.label: "Show iGPU temperature"
        text: ""
    }

    QQC2.CheckBox {
        id: showFansCheck
        Kirigami.FormData.label: "Show fan speeds in popup"
        text: ""
    }

    // ── Appearance section ─────────────────────────────────────────────────
    Kirigami.Separator {
        Kirigami.FormData.label: "Appearance"
        Kirigami.FormData.isSection: true
    }

    QQC2.ComboBox {
        id: colorThemeCombo
        Kirigami.FormData.label: "Color theme"
        model: [
            { text: "ROG Red",  value: "rog"     },
            { text: "Neon",     value: "neon"     },
            { text: "Minimal",  value: "minimal"  },
        ]
        textRole: "text"
        valueRole: "value"
        Component.onCompleted: {
            var idx = 0
            for (var i = 0; i < model.length; i++) {
                if (model[i].value === Plasmoid.configuration.colorTheme) {
                    idx = i; break
                }
            }
            currentIndex = idx
        }
    }

    QQC2.SpinBox {
        id: fontSizeSpinner
        Kirigami.FormData.label: "Font size (px)"
        from: 9; to: 20; stepSize: 1
    }

    // ── Polling section ────────────────────────────────────────────────────
    Kirigami.Separator {
        Kirigami.FormData.label: "Performance"
        Kirigami.FormData.isSection: true
    }

    RowLayout {
        Kirigami.FormData.label: "Poll interval"
        spacing: 8

        QQC2.Slider {
            id: pollSlider
            from: 500; to: 10000; stepSize: 500
            Layout.preferredWidth: 160
        }

        QQC2.Label {
            text: (pollSlider.value / 1000).toFixed(1) + " s"
            Layout.minimumWidth: 40
        }
    }
}
