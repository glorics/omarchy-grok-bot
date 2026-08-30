import QtQuick
import qs.Commons

// x.ai/bot mascot, dark-theme: light circle, dark stadium eyes as holes.
// Eyes live on a sphere (rest yaw/pitch/roll from the official idle).
// Life is gaze drift, blinking, a 0.5% breath, and pointer follow.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool running: false
  property bool alarming: false
  property bool installed: true

  // Official idle measurements (ball radius = 1).
  readonly property real eyeSplit: 15.46
  readonly property real eyeW: 0.186
  readonly property real eyeH: 0.412
  readonly property real restYaw: 28.49
  readonly property real restPitch: 28.62
  readonly property real restRoll: -13

  readonly property real radius: Math.max(1, width / 2 - Math.max(0.5, iconSize * 0.03))
  readonly property real cx: width / 2
  readonly property real cy: height / 2

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
  property real followYaw: 0
  property real followPitch: 0
  property real followMix: 0

  readonly property bool awake: installed && !alarming
  readonly property real wander: followMix > 0.5 ? 0.15 : (running ? 1.0 : 0.75)

  readonly property real dYaw: awake ? (Math.sin(t / 11.3) * 5.5 + Math.sin(t / 3.7 + 2.1) * 1.6) * wander : 0
  readonly property real dPitch: awake ? (Math.sin(t / 9.1 + 1.3) * 4.2 + Math.sin(t / 4.3 + 0.7) * 1.3) * wander : 0
  readonly property real dRoll: awake ? Math.sin(t / 13.7 + 3.2) * 2.2 * wander : 0
  readonly property real breath: awake ? 1 + Math.sin(t / 3.4 * Math.PI * 2) * 0.005 : 1
  readonly property real lid: awake ? blinkLidAt(t) : (installed ? 0.40 : 0.14)

  readonly property real yaw: restYaw * (1 - followMix) + followYaw * followMix + dYaw
  readonly property real pitch: restPitch * (1 - followMix) + followPitch * followMix + dPitch
  readonly property real roll: restRoll + dRoll

  readonly property var innerEye: eyePose(-1)
  readonly property var outerEye: eyePose(1)

  function deg(d) { return d * Math.PI / 180 }

  function spin(u, v, ang) {
    var c = Math.cos(ang), s = Math.sin(ang)
    return [
      [u[0] * c + v[0] * s, u[1] * c + v[1] * s, u[2] * c + v[2] * s],
      [v[0] * c - u[0] * s, v[1] * c - u[1] * s, v[2] * c - u[2] * s]
    ]
  }

  // Official blink: 0.18s, close fast, open slower. Occasional double.
  function blinkLidAt(time) {
    var period = 3.15
    var local = time % period
    var k
    if (local >= 0 && local <= 0.18) {
      k = local / 0.18
      return k < 0.45 ? 1 - k / 0.45 : (k - 0.45) / 0.55
    }
    // every fifth cycle, a second blink 0.24s later
    var n = Math.floor(time / period)
    if (n % 5 === 0 && local >= 0.42 && local <= 0.60) {
      k = (local - 0.42) / 0.18
      return k < 0.45 ? 1 - k / 0.45 : (k - 0.45) / 0.55
    }
    return 1
  }

  function blinkScale(open) {
    return 0.06 + 0.94 * Math.max(0, Math.min(1, open))
  }

  function eyePose(side) {
    var f = [0, 0, 1]
    var right = [1, 0, 0]
    var down = [0, 1, 0]
    var r
    r = spin(f, right, deg(yaw)); f = r[0]; right = r[1]
    r = spin(down, f, deg(pitch)); down = r[0]; f = r[1]
    r = spin(right, down, deg(roll)); right = r[0]; down = r[1]
    r = spin(f, right, deg(eyeSplit * side))
    var ef = r[0], er = r[1]
    var k = blinkScale(lid)
    return {
      x: ef[0] * radius,
      y: ef[1] * radius,
      a: er[0],
      b: er[1] * k,
      c: down[0],
      d: down[1] * k,
      depth: ef[2]
    }
  }

  function followFrom(px, py) {
    if (width <= 1 || height <= 1) return
    var nx = (px / width) * 2 - 1
    var ny = (py / height) * 2 - 1
    followYaw = Math.max(-40, Math.min(40, nx * 38))
    followPitch = Math.max(-28, Math.min(28, -ny * 28))
    followMix = 1
  }

  function clearFollow() {
    followMix = 0
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
    }
  }

  Behavior on followYaw { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
  Behavior on followPitch { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
  Behavior on followMix { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }

  HoverHandler {
    id: hover
    enabled: root.awake
    onHoveredChanged: if (!hovered) root.clearFollow()
  }

  Item {
    id: ball
    anchors.centerIn: parent
    width: root.radius * 2
    height: root.radius * 2 * root.breath
    transformOrigin: Item.Center

    Rectangle {
      id: head
      anchors.fill: parent
      radius: width / 2
      color: root.bodyColor
      antialiasing: true
      clip: true

      EyeCapsule {
        pose: root.innerEye
        visible: root.innerEye.depth > 0.02
      }
      EyeCapsule {
        pose: root.outerEye
        visible: root.outerEye.depth > 0.02
      }
    }
  }

  component EyeCapsule: Item {
    property var pose: ({ x: 0, y: 0, a: 1, b: 0, c: 0, d: 1, depth: 1 })

    x: head.width / 2
    y: head.height / 2
    width: 0
    height: 0

    Rectangle {
      width: Math.max(2, root.radius * root.eyeW)
      height: Math.max(3, root.radius * root.eyeH)
      radius: width / 2
      color: root.eyeColor
      antialiasing: true
      x: -width / 2
      y: -height / 2
      transform: Matrix4x4 {
        matrix: Qt.matrix4x4(
          pose.a, pose.c, 0, pose.x,
          pose.b, pose.d, 0, pose.y,
          0, 0, 1, 0,
          0, 0, 0, 1)
      }
    }
  }
}
