import QtQuick
import qs.Commons

// Grok Bot mark: glossy orb, two stadium eyes on the right of the face,
// tilted clockwise like the official desktop icon. Recolors with the theme.
// Running blinks. Idle squints. Missing/crashed keeps the lids down.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool running: false
  property bool alarming: false
  property bool installed: true
  property real eyeTilt: 16

  readonly property real luminance: 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
  readonly property color eyeColor: luminance > 0.5
    ? Qt.rgba(color.r * 0.12, color.g * 0.12, color.b * 0.12, 1)
    : Qt.rgba(Math.min(1, color.r + 0.72), Math.min(1, color.g + 0.72), Math.min(1, color.b + 0.72), 1)
  readonly property color highlightColor: luminance > 0.5
    ? Qt.rgba(1, 1, 1, gleam)
    : Qt.rgba(1, 1, 1, gleam * 0.55)
  readonly property color shadeColor: Qt.rgba(0, 0, 0, luminance > 0.5 ? 0.16 : 0.28)

  readonly property real openLid: {
    if (!installed || alarming && !running) return 0.14
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
    color: root.color
    antialiasing: true
    clip: true

    // Bottom-right contact shade — the official mark is a lit sphere, not a sticker.
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

    // Official face: both capsules sit on the right, parallel, leaning clockwise.
    Item {
      id: pair
      width: parent.width * 0.48
      height: parent.height * 0.42
      x: parent.width * 0.40
      y: parent.height * 0.26
      rotation: root.eyeTilt
      transformOrigin: Item.Center

      Rectangle {
        id: leftEye
        width: Math.max(2, pair.width * 0.36)
        height: Math.max(3, pair.height * 0.90 * root.lid)
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
