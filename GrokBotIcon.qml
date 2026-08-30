import QtQuick
import qs.Commons

// x.ai/bot idle face (dark theme: light body, dark eye holes).
// Positions are the official rest pose at radius 100, scaled to the icon:
// inner  (21.42, -43.32), outer (62.98, -53.90), tilt \\ ~26°.
// Animation is the same as the page: blink, gaze drift, pointer follow,
// 0.5% breath. No float.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool running: false
  property bool alarming: false
  property bool installed: true

  readonly property real radius: Math.max(4, width / 2 - Math.max(0.5, iconSize * 0.03))

  readonly property color bodyColor: {
    if (!installed)
      return Qt.rgba(color.r, color.g, color.b, 0.45)
    if (alarming)
      return Qt.rgba(Math.min(1, color.r + 0.04), Math.max(0, color.g - 0.04), Math.max(0, color.b - 0.06), 1)
    return color
  }
  readonly property color eyeColor: {
    var l = 0.2126 * bodyColor.r + 0.7152 * bodyColor.g + 0.0722 * bodyColor.b
    if (l > 0.5)
      return Qt.rgba(0.08, 0.08, 0.09, 1)
    return Qt.rgba(0.98, 0.98, 0.98, 1)
  }

  property real t: 0
  property real followX: 0
  property real followY: 0
  property real followMix: 0

  readonly property bool awake: installed && !alarming
  readonly property real wander: followMix > 0.4 ? 0.12 : (running ? 1.0 : 0.75)

  readonly property real driftX: awake ? (Math.sin(t / 3.7 + 2.1) * 0.035 + Math.sin(t / 11.3) * 0.02) * wander : 0
  readonly property real driftY: awake ? (Math.sin(t / 4.3 + 0.7) * 0.028 + Math.sin(t / 9.1 + 1.3) * 0.018) * wander : 0
  readonly property real gazeX: driftX + followX * followMix
  readonly property real gazeY: driftY + followY * followMix
  readonly property real breath: awake ? 1 + Math.sin(t / 3.4 * Math.PI * 2) * 0.005 : 1
  readonly property real lid: awake ? blinkLidAt(t) : (installed ? 0.40 : 0.14)
  readonly property real tilt: -26

  function blinkLidAt(time) {
    var period = 3.15
    var local = time % period
    var k
    if (local >= 0 && local <= 0.18) {
      k = local / 0.18
      return k < 0.45 ? 1 - k / 0.45 : (k - 0.45) / 0.55
    }
    var n = Math.floor(time / period)
    if (n % 5 === 0 && local >= 0.42 && local <= 0.60) {
      k = (local - 0.42) / 0.18
      return k < 0.45 ? 1 - k / 0.45 : (k - 0.45) / 0.55
    }
    return 1
  }

  function followFrom(px, py) {
    if (width <= 1 || height <= 1) return
    followX = Math.max(-0.22, Math.min(0.22, (px / width - 0.5) * 0.44))
    followY = Math.max(-0.18, Math.min(0.18, (py / height - 0.5) * 0.36))
    followMix = 1
  }

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Component.onCompleted: t = Date.now() / 1000

  Timer {
    interval: 33
    running: root.awake
    repeat: true
    onTriggered: {
      root.t = Date.now() / 1000
      if (hover.hovered)
        root.followFrom(hover.point.position.x, hover.point.position.y)
      else
        root.followMix = 0
    }
  }

  Behavior on followX { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
  Behavior on followY { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
  Behavior on followMix { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }

  HoverHandler {
    id: hover
    enabled: root.awake
  }

  property real orbit: 0
  SequentialAnimation on orbit {
    running: root.installed && !root.alarming
    loops: Animation.Infinite
    NumberAnimation { from: 0; to: 360; duration: 14000; easing.type: Easing.Linear }
  }

  Item {
    anchors.centerIn: parent
    width: root.radius * 2
    height: root.radius * 2 * root.breath

    Orbit {
      hue: Qt.rgba(0.96, 0.55, 0.70, 0.9)
      tilt: 28
      spin: root.orbit
      fat: 1.42
    }
    Orbit {
      hue: Qt.rgba(0.98, 0.72, 0.48, 0.85)
      tilt: -18
      spin: -root.orbit * 0.85
      fat: 1.28
    }
    Orbit {
      hue: Qt.rgba(0.45, 0.82, 0.86, 0.88)
      tilt: 52
      spin: root.orbit * 1.1 + 40
      fat: 1.18
    }

    Rectangle {
      id: head
      anchors.fill: parent
      radius: width / 2
      color: root.bodyColor
      antialiasing: true
      clip: true
      z: 2

      Eye {
        rx: 0.2142
        ry: -0.4332
        squeeze: 0.87
      }
      Eye {
        rx: 0.6298
        ry: -0.5390
        squeeze: 0.64
      }
    }
  }

  component Orbit: Rectangle {
    property color hue: "white"
    property real tilt: 0
    property real spin: 0
    property real fat: 1.3
    visible: root.installed && root.width >= 20
    opacity: root.running ? 1 : 0.7
    anchors.centerIn: parent
    width: parent.width * fat
    height: parent.height * 0.42
    radius: height / 2
    color: "transparent"
    border.color: hue
    border.width: Math.max(1.4, parent.width * 0.04)
    rotation: tilt + spin
    antialiasing: true
    z: 1
  }

  component Eye: Rectangle {
    property real rx: 0
    property real ry: 0
    property real squeeze: 1

    width: Math.max(2.6, head.width * 0.145 * squeeze)
    height: Math.max(4.2, head.height * 0.32 * root.lid)
    radius: width / 2
    color: root.eyeColor
    antialiasing: true
    rotation: root.tilt
    x: head.width / 2 + (rx + root.gazeX) * (head.width / 2) - width / 2
    y: head.height / 2 + (ry + root.gazeY) * (head.height / 2) - height / 2
  }
}
