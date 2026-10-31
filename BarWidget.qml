// Omarchy bar widget: battery level of a Pulsar mouse via the LINK 2 dongle.
//
// Runs the repo's pulsar-battery.py on a timer and renders its Waybar JSON
// (text / tooltip / class). The host bar injects `bar`, `moduleName` and
// `settings`; nothing else from the shell is imported, so the widget keeps
// working across Omarchy releases.

import QtQuick
import Quickshell.Io

Item {
  id: root

  property var bar: null
  property string moduleName: "io.github.michalgritzbach.pulsar-battery"
  property var settings: ({})

  // Directory this QML file lives in, without the file:// scheme.
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

  // The repo root is the plugin folder, so the script ships next to the QML.
  readonly property var scriptCandidates: [
    pluginDir + "/pulsar-battery.py"
  ]

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : 26

  // The host's shared tooltip only opens while the target reports itself
  // hovered; first-party widgets get this from their WidgetButton base.
  readonly property bool tooltipHovered: visible && mouse.containsMouse

  property string outText: ""
  property string outTooltip: ""
  property string outClass: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  // The script hides the module by printing an empty text field.
  visible: outText !== ""

  implicitWidth: !visible ? 0
    : vertical ? barSize
    : Math.max(12, label.implicitWidth + 2 * Number(setting("horizontalMargin", 8)))
  implicitHeight: !visible ? 0
    : vertical ? Math.max(12, label.implicitHeight + 8)
    : barSize

  readonly property color normalColor: bar ? bar.barForeground : "white"
  readonly property color urgentColor: bar ? bar.urgent : "#f38ba8"
  readonly property color chargingColor: String(setting("chargingColor", "#a6e3a1"))

  Text {
    id: label
    anchors.centerIn: parent
    // A vertical bar is 28px wide, so stack "icon" and "95%" instead.
    text: root.vertical ? root.outText.replace(/\s+/g, "\n") : root.outText
    color: root.outClass === "charging" ? root.chargingColor
      : (root.outClass === "critical" || root.outClass === "disconnected") ? root.urgentColor
      : root.normalColor
    font.family: root.bar ? root.bar.fontFamily : "monospace"
    font.pixelSize: Number(root.setting("fontSize", 12))
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    lineHeight: 0.85
    renderType: Text.NativeRendering
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    onEntered: root.showTooltip()
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function (event) {
      var command = event.button === Qt.RightButton ? String(root.setting("onRightClick", ""))
        : event.button === Qt.MiddleButton ? String(root.setting("onMiddleClick", ""))
        : String(root.setting("onClick", ""))
      if (command && root.bar) root.bar.run(command)
      else root.poll()
    }
  }

  function showTooltip() {
    if (bar && mouse.containsMouse && outTooltip !== "") bar.showTooltip(root, outTooltip)
  }

  function poll() {
    if (proc.running) return
    // runProcess staggers concurrent polls across bar instances when the host
    // offers it; fall back to starting the process directly.
    if (bar && typeof bar.runProcess === "function") bar.runProcess(proc)
    else proc.running = true
  }

  function update(raw) {
    var trimmed = String(raw || "").trim()
    if (trimmed === "") {
      outText = ""
      outTooltip = ""
      outClass = ""
      return
    }

    var data = null
    try {
      data = JSON.parse(trimmed)
    } catch (e) {
      data = null
    }

    if (data && typeof data === "object") {
      outText = String(data.text || "")
      outTooltip = String(data.tooltip || "")
      outClass = Array.isArray(data["class"]) ? data["class"].join(" ") : String(data["class"] || "")
    } else {
      outText = trimmed
      outTooltip = ""
      outClass = ""
    }

    // Keep an open tooltip in sync with the fresh reading.
    showTooltip()
  }

  Process {
    id: proc
    command: {
      var custom = String(root.setting("command", ""))
      if (custom !== "") return ["bash", "-lc", custom]
      // First candidate that exists and is executable wins.
      return ["bash", "-c",
        "for candidate in \"$@\"; do [ -x \"$candidate\" ] && exec \"$candidate\"; done; exit 127",
        root.moduleName].concat(root.scriptCandidates)
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.update(text)
    }
  }

  Timer {
    interval: Math.max(5, Number(root.setting("interval", 60))) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }
}
