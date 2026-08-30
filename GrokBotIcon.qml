import QtQuick
import qs.Commons

// Official Grok Bot face: a lit white sphere, two dark stadium eyes parked
// on the right and tilted clockwise. Not a globe. Body stays light and
// eyes stay dark so it matches the desktop icon on a dark bar. Running
// blinks; idle squints; missing/crashed keeps the lids down.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool running: false
  property bool alarming: false
  property bool installed: true
  property real eyeTilt: 16

  readonly property color bodyColor: {
    if (!installed)
      return Qt.rgba(0.72, 0.74, 0.76, 1)
    if (alarming)
      return Qt.rgba(0.97, 0.93, 0.90, 1)
    if (running)
      return Qt.rgba(0.96, 0.96, 0.97, 1)
    return Qt.rgba(0.90, 0.91, 0.92, 1)
  }
  readonly property color eyeColor: alarming
    ? Qt.rgba(0.22, 0.10, 0.10, 1)
    : Qt.rgba(0.13, 0.13, 0.14, 1)
  readonly property color highlightColor: Qt.rgba(1, 1, 1, gleam)
  readonly property color shadeColor: Qt.rgba(0, 0, 0, running ? 0.16 : 0.22)

  readonly property real openLid: {
    if (!installed || (alarming && !running)) return 0.14
    if (!running) return 0.40
    return 1
  }
  property real blinkLid: 1
  readonly property real lid: Math.max(0.08, openLid * blinkLid)

  property real gleam: 0.22

  onRunningChanged: if (!running) {
    blinkLid = 1
    gleam = 0.18
  }

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Rectangle {
    id: head
    anchors.fill: parent
    anchors.margins: Math.max(0.5, iconSize * 0.03)
    radius: width / 2
    color: root.bodyColor
    antialiasing: true
    clip: true

    Rectangle {
      width: parent.width * 0.78
      height: parent.height * 0.70
      radius: width / 2
      x: parent.width * 0.28
      y: parent.height * 0.36
      color: root.shadeColor
      antialiasing: true
    }

    Rectangle {
      width: parent.width * 0.58
      height: parent.height * 0.46
      radius: width / 2
      x: parent.width * 0.04
      y: parent.height * 0.06
      color: root.highlightColor
      antialiasing: true
    }

    Item {
      id: pair
      width: parent.width * 0.44
      height: parent.height * 0.46
      x: parent.width * 0.42
      y: parent.height * 0.24
      rotation: root.eyeTilt
      transformOrigin: Item.Center

      Rectangle {
        id: leftEye
        width: Math.max(2, pair.width * 0.30)
        height: Math.max(3, pair.height * 0.92 * root.lid)
        radius: width / 2
        color: root.eyeColor
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        antialiasing: true
      }

      Rectangle {
        id: rightEye
        width: leftEye.width
        height: leftEye.height
        radius: leftEye.radius
        color: root.eyeColor
        x: pair.width - width
        anchors.verticalCenter: parent.verticalCenter
        antialiasing: true
      }
    }
  }

  SequentialAnimation on gleam {
    running: root.running && !root.alarming
    loops: Animation.Infinite
    NumberAnimation { to: 0.40; duration: 1600; easing.type: Easing.InOutSine }
    NumberAnimation { to: 0.18; duration: 1600; easing.type: Easing.InOutSine }
  }

  SequentialAnimation {
    id: blink
    running: root.running
    loops: Animation.Infinite
    PauseAnimation { duration: root.alarming ? 1600 : 4600 }
    NumberAnimation { target: root; property: "blinkLid"; to: 0.08; duration: 70; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "blinkLid"; to: 1; duration: 110; easing.type: Easing.OutCubic }
    PauseAnimation { duration: root.alarming ? 900 : 2400 }
  }
}
