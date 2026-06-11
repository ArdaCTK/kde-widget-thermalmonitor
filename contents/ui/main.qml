import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    implicitWidth: compactRepresentationItem ? compactRepresentationItem.implicitWidth : 120
    implicitHeight: compactRepresentationItem ? compactRepresentationItem.implicitHeight : 32

    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth

    // ── settings ──────────────────────────────────────────────────────────
    property int    cfg_pollInterval:   Plasmoid.configuration.pollInterval
    property bool   cfg_showCpu:        Plasmoid.configuration.showCpu
    property bool   cfg_showGpu1:       Plasmoid.configuration.showGpu1
    property bool   cfg_showGpu2:       Plasmoid.configuration.showGpu2
    property bool   cfg_showFans:       Plasmoid.configuration.showFans
    property string cfg_colorTheme:     Plasmoid.configuration.colorTheme
    property int    cfg_fontSize:       Plasmoid.configuration.fontSize

    // ── runtime state ─────────────────────────────────────────────────────
    property var    cpuTemp:  null
    property var    gpu1Temp: null
    property string gpu1Name: "GPU"
    property var    gpu2Temp: null
    property string gpu2Name: ""
    property var    fans:     ({})
    property string errorMsg: ""

    // History buffer for mini-chart (last 60 readings per sensor)
    property var cpuHistory:  []
    property var gpu1History: []

    // ── color theme ───────────────────────────────────────────────────────
    readonly property var themes: ({
        "rog": {
            accent:    "#e8002d",
            accent2:   "#ff4060",
            surface:   "#0a0a0f",
            surface2:  "#111118",
            text:      "#e8e8f0",
            dim:       "#55556a",
            glow:      "rgba(232,0,45,0.35)"
        },
        "neon": {
            accent:    "#c792ea",
            accent2:   "#89ddff",
            surface:   "#0d0d14",
            surface2:  "#161622",
            text:      "#e8e8f0",
            dim:       "#44445a",
            glow:      "rgba(199,146,234,0.30)"
        },
        "minimal": {
            accent:    "#5ccfe6",
            accent2:   "#bae67e",
            surface:   "#1a1a2e",
            surface2:  "#22223a",
            text:      "#cdd6f4",
            dim:       "#585878",
            glow:      "rgba(92,207,230,0.20)"
        }
    })

    readonly property var theme: themes[cfg_colorTheme] || themes["rog"]

    // ── temp → color mapping ──────────────────────────────────────────────
    function tempColor(t) {
        if (t === null || t === undefined) return theme.dim
        if (t < 50)  return "#00d4aa"
        if (t < 65)  return "#f0c040"
        if (t < 80)  return "#ff8c35"
        return "#ff2d55"
    }

    function tempLabel(t) {
        if (t === null || t === undefined) return "N/A"
        return t + "°C"
    }

    // ── backend ───────────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            var out = (data["stdout"] || "").trim()
            var err = (data["stderr"] || "").trim()
            if (out) {
                try {
                    var d = JSON.parse(out)
                    root.cpuTemp  = (d.cpu  !== null && d.cpu  !== undefined) ? d.cpu  : null
                    root.gpu1Temp = (d.gpu1 !== null && d.gpu1 !== undefined) ? d.gpu1 : null
                    root.gpu1Name = d.gpu1_name || "GPU"
                    root.gpu2Temp = (d.gpu2 !== null && d.gpu2 !== undefined) ? d.gpu2 : null
                    root.gpu2Name = d.gpu2_name || ""
                    root.fans     = d.fans || {}
                    root.errorMsg = ""

                    // Update history
                    if (d.cpu !== null && d.cpu !== undefined) {
                        var ch = root.cpuHistory.slice()
                        ch.push(d.cpu)
                        if (ch.length > 60) ch.shift()
                        root.cpuHistory = ch
                    }
                    if (d.gpu1 !== null && d.gpu1 !== undefined) {
                        var gh = root.gpu1History.slice()
                        gh.push(d.gpu1)
                        if (gh.length > 60) gh.shift()
                        root.gpu1History = gh
                    }
                } catch(e) {
                    root.errorMsg = "Parse error"
                }
            } else if (err) {
                root.errorMsg = err.substring(0, 40)
            }
            disconnectSource(sourceName)
        }
    }

    readonly property string backendPath: {
        var u = Qt.resolvedUrl("../code/thermal_backend.py").toString()
        return u.replace(/^file:\/\//, "")
    }

    function poll() {
        var cmd = "python3 " + root.backendPath
        executable.connectSource(cmd)
    }

    Timer {
        id: pollTimer
        interval:  root.cfg_pollInterval
        running:   true
        repeat:    true
        onTriggered: root.poll()
        Component.onCompleted: root.poll()
    }

    onCfg_pollIntervalChanged: pollTimer.interval = root.cfg_pollInterval

    // ════════════════════════════════════════════════════════════════════════
    // COMPACT REPRESENTATION — taskbar strip
    // ════════════════════════════════════════════════════════════════════════
    compactRepresentation: Item {
        id: compactRoot

        readonly property int chipH: 22
        readonly property int chipPad: 8
        readonly property int gap: root.cfg_showGpu2 ? 4 : 6

        // ── Size hints for Plasma panel layout engine ─────────────────────
        readonly property int cpuW:  root.cfg_showCpu ? (root.cfg_fontSize * 6 + 10) : 0
        readonly property int gpu1W: root.cfg_showGpu1 ? (root.cfg_fontSize * 6 + 10) : 0
        readonly property int gpu2W: (root.cfg_showGpu2 && root.gpu2Temp !== null) ? (root.cfg_fontSize * 6.5 + 10) : 0

        readonly property int activeChips: (root.cfg_showCpu ? 1 : 0) + (root.cfg_showGpu1 ? 1 : 0) + ((root.cfg_showGpu2 && root.gpu2Temp !== null) ? 1 : 0)
        readonly property int gaps: activeChips > 1 ? (activeChips - 1) * gap : 0

        readonly property int contentWidth: cpuW + gpu1W + gpu2W + gaps + 12

        implicitWidth:         contentWidth
        implicitHeight:        parent ? parent.height : 32

        Layout.minimumWidth:   contentWidth
        Layout.preferredWidth: contentWidth
        Layout.maximumWidth:   contentWidth

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.expanded = !root.expanded
        }

        // Subtle dark backing strip
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.leftMargin:  2
            anchors.rightMargin: 2
            height: compactRoot.chipH + 4
            radius: (compactRoot.chipH + 4) / 2
            color:  Qt.rgba(0, 0, 0, 0.30)
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: compactRoot.gap
            width: implicitWidth

            // ── CPU chip ────────────────────────────────────────────────
            Rectangle {
                id: cpuChip
                visible:        root.cfg_showCpu
                width:          compactRoot.cpuW
                height:         compactRoot.chipH
                radius:         height / 2
                color: Qt.rgba(
                    Qt.color(root.tempColor(root.cpuTemp)).r,
                    Qt.color(root.tempColor(root.cpuTemp)).g,
                    Qt.color(root.tempColor(root.cpuTemp)).b,
                    0.15)
                border.color: root.tempColor(root.cpuTemp)
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 600 } }

                // Glow effect
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: root.tempColor(root.cpuTemp)
                    border.width: 3
                    opacity: 0.15
                    Behavior on border.color { ColorAnimation { duration: 600 } }
                }

                Row {
                    id: cpuChipRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "CPU"
                        color: root.theme.dim
                        font.pixelSize: root.cfg_fontSize - 2
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: cpuTempText
                        text: root.tempLabel(root.cpuTemp)
                        color: root.tempColor(root.cpuTemp)
                        font.pixelSize: root.cfg_fontSize
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 600 } }

                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: cpuTempText; property: "opacity"; to: 0.3; duration: 80 }
                                PropertyAction {}
                                NumberAnimation { target: cpuTempText; property: "opacity"; to: 1.0; duration: 120 }
                            }
                        }
                    }
                }
            }

            // ── GPU1 chip ────────────────────────────────────────────────
            Rectangle {
                id: gpu1Chip
                visible:        root.cfg_showGpu1
                width:          compactRoot.gpu1W
                height:         compactRoot.chipH
                radius:         height / 2
                color: Qt.rgba(
                    Qt.color(root.tempColor(root.gpu1Temp)).r,
                    Qt.color(root.tempColor(root.gpu1Temp)).g,
                    Qt.color(root.tempColor(root.gpu1Temp)).b,
                    0.15)
                border.color: root.tempColor(root.gpu1Temp)
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 600 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: root.tempColor(root.gpu1Temp)
                    border.width: 3
                    opacity: 0.15
                    Behavior on border.color { ColorAnimation { duration: 600 } }
                }

                Row {
                    id: gpu1ChipRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "GPU"
                        color: root.theme.dim
                        font.pixelSize: root.cfg_fontSize - 2
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: gpu1TempText
                        text: root.tempLabel(root.gpu1Temp)
                        color: root.tempColor(root.gpu1Temp)
                        font.pixelSize: root.cfg_fontSize
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 600 } }

                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: gpu1TempText; property: "opacity"; to: 0.3; duration: 80 }
                                PropertyAction {}
                                NumberAnimation { target: gpu1TempText; property: "opacity"; to: 1.0; duration: 120 }
                            }
                        }
                    }
                }
            }

            // ── GPU2 chip (iGPU — optional) ──────────────────────────────
            Rectangle {
                id: gpu2Chip
                visible:        root.cfg_showGpu2 && root.gpu2Temp !== null
                width:          compactRoot.gpu2W
                height:         compactRoot.chipH
                radius:         height / 2
                color: Qt.rgba(
                    Qt.color(root.tempColor(root.gpu2Temp)).r,
                    Qt.color(root.tempColor(root.gpu2Temp)).g,
                    Qt.color(root.tempColor(root.gpu2Temp)).b,
                    0.15)
                border.color: root.tempColor(root.gpu2Temp)
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 600 } }

                Row {
                    id: gpu2ChipRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "iGPU"
                        color: root.theme.dim
                        font.pixelSize: root.cfg_fontSize - 2
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.tempLabel(root.gpu2Temp)
                        color: root.tempColor(root.gpu2Temp)
                        font.pixelSize: root.cfg_fontSize
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // FULL REPRESENTATION — popup panel
    // ════════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        implicitWidth:  300
        implicitHeight: popupCol.implicitHeight + 28

        // ── Background ──────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color:  root.theme.surface
            radius: 16
            border.color: Qt.rgba(
                Qt.color(root.theme.accent).r,
                Qt.color(root.theme.accent).g,
                Qt.color(root.theme.accent).b,
                0.4)
            border.width: 1

            // Subtle glow outline
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: root.theme.glow
                border.width: 4
                opacity: 0.6
            }
        }

        ColumnLayout {
            id: popupCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 12

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Kirigami.Icon {
                    source: "temperature-normal"
                    width: 18; height: 18
                    color: root.theme.accent
                }
                Text {
                    text: "THERMAL MONITOR"
                    color: root.theme.text
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: {
                        var now = new Date()
                        return Qt.formatTime(now, "hh:mm:ss")
                    }
                    color: root.theme.dim
                    font.pixelSize: 10

                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: parent.text = Qt.formatTime(new Date(), "hh:mm:ss")
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(
                    Qt.color(root.theme.accent).r,
                    Qt.color(root.theme.accent).g,
                    Qt.color(root.theme.accent).b,
                    0.20)
            }

            // ── Gauge row ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // CPU gauge
                ThermalGauge {
                    visible: root.cfg_showCpu
                    Layout.fillWidth: true
                    label: "CPU"
                    temperature: root.cpuTemp
                    accentColor: root.tempColor(root.cpuTemp)
                    dimColor: root.theme.dim
                    surfaceColor: root.theme.surface2
                    textColor: root.theme.text
                }

                // GPU1 gauge
                ThermalGauge {
                    visible: root.cfg_showGpu1
                    Layout.fillWidth: true
                    label: root.gpu1Name
                    temperature: root.gpu1Temp
                    accentColor: root.tempColor(root.gpu1Temp)
                    dimColor: root.theme.dim
                    surfaceColor: root.theme.surface2
                    textColor: root.theme.text
                }

                // GPU2 gauge
                ThermalGauge {
                    visible: root.cfg_showGpu2 && root.gpu2Temp !== null
                    Layout.fillWidth: true
                    label: root.gpu2Name || "iGPU"
                    temperature: root.gpu2Temp
                    accentColor: root.tempColor(root.gpu2Temp)
                    dimColor: root.theme.dim
                    surfaceColor: root.theme.surface2
                    textColor: root.theme.text
                }
            }

            // ── Fan speeds (ASUS) ─────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.cfg_showFans && Object.keys(root.fans).length > 0

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(
                        Qt.color(root.theme.accent).r,
                        Qt.color(root.theme.accent).g,
                        Qt.color(root.theme.accent).b,
                        0.15)
                }

                Text {
                    text: "FAN SPEEDS"
                    color: root.theme.dim
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                Repeater {
                    model: {
                        var keys = Object.keys(root.fans)
                        return keys
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Kirigami.Icon {
                            source: "media-optical-audio-symbolic"
                            width: 12; height: 12
                            color: root.theme.dim
                        }
                        Text {
                            text: modelData.replace("_", " ").toUpperCase()
                            color: root.theme.dim
                            font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.fans[modelData] + " RPM"
                            color: root.fans[modelData] > 4500
                                ? "#ff6b35"
                                : root.fans[modelData] > 3000
                                    ? "#f0c040"
                                    : root.theme.text
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            // ── Mini chart ────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(
                        Qt.color(root.theme.accent).r,
                        Qt.color(root.theme.accent).g,
                        Qt.color(root.theme.accent).b,
                        0.15)
                }

                Text {
                    text: "HISTORY (last 60 readings)"
                    color: root.theme.dim
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                // Chart canvas
                Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    color: root.theme.surface2
                    radius: 8
                    clip: true

                    Canvas {
                        id: historyChart
                        anchors.fill: parent
                        anchors.margins: 6

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            function drawLine(history, colorStr) {
                                if (!history || history.length < 2) return
                                var minT = 20, maxT = 100
                                ctx.beginPath()
                                ctx.strokeStyle = colorStr
                                ctx.lineWidth = 1.5
                                ctx.lineJoin = "round"
                                for (var i = 0; i < history.length; i++) {
                                    var x = (i / (history.length - 1)) * width
                                    var y = height - ((history[i] - minT) / (maxT - minT)) * height
                                    y = Math.max(1, Math.min(height - 1, y))
                                    if (i === 0) ctx.moveTo(x, y)
                                    else         ctx.lineTo(x, y)
                                }
                                ctx.stroke()
                            }

                            // Grid lines at 50, 70, 85°C
                            ctx.strokeStyle = "rgba(255,255,255,0.06)"
                            ctx.lineWidth = 1
                            var minT = 20, maxT = 100
                            var gridTemps = [50, 70, 85]
                            for (var g = 0; g < gridTemps.length; g++) {
                                var gy = height - ((gridTemps[g] - minT) / (maxT - minT)) * height
                                ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
                            }

                            if (root.cfg_showCpu)
                                drawLine(root.cpuHistory, "#00d4aa")
                            if (root.cfg_showGpu1)
                                drawLine(root.gpu1History, root.theme.accent)
                        }

                        Connections {
                            target: root
                            function onCpuHistoryChanged()  { historyChart.requestPaint() }
                            function onGpu1HistoryChanged() { historyChart.requestPaint() }
                        }
                    }

                    // Legend
                    Row {
                        anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                        spacing: 10

                        Row {
                            spacing: 4
                            visible: root.cfg_showCpu
                            Rectangle { width: 12; height: 2; color: "#00d4aa"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "CPU"; color: root.theme.dim; font.pixelSize: 9 }
                        }
                        Row {
                            spacing: 4
                            visible: root.cfg_showGpu1
                            Rectangle { width: 12; height: 2; color: root.theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: root.gpu1Name; color: root.theme.dim; font.pixelSize: 9 }
                        }
                    }
                }
            }

            // ── Error msg ─────────────────────────────────────────────
            Text {
                visible: root.errorMsg !== ""
                text: "⚠ " + root.errorMsg
                color: "#ff6b35"
                font.pixelSize: 10
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            Item { height: 2 }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // GAUGE component — inline reusable item
    // ════════════════════════════════════════════════════════════════════════
    component ThermalGauge: Item {
        id: gauge

        property string label:       "CPU"
        property var    temperature: null
        property color  accentColor: "#00d4aa"
        property color  dimColor:    "#44445a"
        property color  surfaceColor:"#111118"
        property color  textColor:   "#e8e8f0"

        implicitHeight: 110

        // Background circle
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(gauge.width, 90)
            height: width
            radius: width / 2
            color: gauge.surfaceColor
            border.color: Qt.rgba(
                gauge.accentColor.r,
                gauge.accentColor.g,
                gauge.accentColor.b,
                0.25)
            border.width: 2

            // Inner glow
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: gauge.accentColor
                border.width: 4
                opacity: 0.12
                Behavior on border.color { ColorAnimation { duration: 600 } }
            }

            // Arc canvas
            Canvas {
                id: gaugeArc
                anchors.fill: parent
                anchors.margins: 4

                property real progress: {
                    if (gauge.temperature === null || gauge.temperature === undefined)
                        return 0
                    return Math.min(1.0, Math.max(0.0, (gauge.temperature - 20) / 80))
                }

                Behavior on progress { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }

                onProgressChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var cx = width / 2
                    var cy = height / 2
                    var r  = Math.min(cx, cy) - 3
                    var startAngle = -Math.PI * 0.75
                    var endAngle   =  Math.PI * 0.75
                    var fillAngle  = startAngle + (endAngle - startAngle) * progress

                    // Track
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, startAngle, endAngle)
                    ctx.strokeStyle = "rgba(255,255,255,0.07)"
                    ctx.lineWidth   = 5
                    ctx.lineCap     = "round"
                    ctx.stroke()

                    if (progress > 0) {
                        // Gradient fill
                        var grad = ctx.createLinearGradient(0, 0, width, 0)
                        grad.addColorStop(0,   "#00d4aa")
                        grad.addColorStop(0.5, "#f0c040")
                        grad.addColorStop(1.0, "#ff2d55")

                        ctx.beginPath()
                        ctx.arc(cx, cy, r, startAngle, fillAngle)
                        ctx.strokeStyle = grad
                        ctx.lineWidth   = 5
                        ctx.lineCap     = "round"
                        ctx.stroke()
                    }
                }

                Connections {
                    target: gauge
                    function onAccentColorChanged() { gaugeArc.requestPaint() }
                }
            }

            // Temperature value
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text:  gauge.temperature !== null ? gauge.temperature + "°" : "—"
                    color: gauge.accentColor
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    Behavior on color { ColorAnimation { duration: 600 } }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text:  gauge.label
                    color: gauge.dimColor
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 0.8
                }
            }
        }

        // Heat bar below circle
        Rectangle {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                bottomMargin: 2
            }
            height: 4
            radius: 2
            color: Qt.rgba(
                gauge.accentColor.r,
                gauge.accentColor.g,
                gauge.accentColor.b,
                0.15)

            Rectangle {
                id: heatFill
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                radius: parent.radius
                width: {
                    if (gauge.temperature === null || gauge.temperature === undefined)
                        return 0
                    return parent.width * Math.min(1.0, Math.max(0.0, (gauge.temperature - 20) / 80))
                }
                color: gauge.accentColor
                Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 600 } }
            }
        }
    }
}
