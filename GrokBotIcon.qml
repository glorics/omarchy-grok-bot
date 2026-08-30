import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.Commons

// x.ai/bot statement mark: humming (data-state="humming", scaleX -1).
// Frames 0 and 8 are the stadium-eye look-around from production JS.
// Blink is an eye-scale squash (official u.t), not a different expression.
// No orbit overlay — that section of the site does not use one.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool running: false
  property bool alarming: false
  property bool installed: true

  property var mark: null
  property real mix: 0
  property real blink: 0
  property real follow: 0
  property real nowMs: 0

  readonly property bool awake: installed && !alarming
  readonly property real s: width / 259
  readonly property color bodyColor: root.color
  readonly property color eyeColor: Color.background
  readonly property real wobbleX: 2 * Math.sin(nowMs / 1000 * 0.4) * s
  readonly property real wobbleY: 1.5 * Math.sin(nowMs / 1000 * 0.3) * s

  readonly property string headPath: mark && mark.head ? mark.head : fallbackHead
  readonly property string eye0Path: ringPath(eyeRing(0))
  readonly property string eye1Path: ringPath(eyeRing(1))

  readonly property string fallbackHead: "M228.541 114.228C228.541 130.133 225.184 145.994 218.738 160.534C212.674 174.217 203.904 186.669 193.065 196.988C155.933 232.34 99.497 238.596 55.5255 212.24C45.097 205.99 35.6851 198.072 27.7451 188.866C19.1926 178.953 12.3686 167.569 7.65781 155.351C2.60712 142.264 0 128.257 0 114.228C0 98.3219 3.35751 82.4611 9.80315 67.9215C15.8672 54.2382 24.6377 41.7862 35.4767 31.4668C72.6081 -3.88483 129.044 -10.1413 173.016 16.2153C183.444 22.4653 192.856 30.3829 200.796 39.5896C209.349 49.5018 216.173 60.8859 220.883 73.1037C225.934 86.1906 228.541 100.198 228.541 114.228Z"

  function ringPath(pts) {
    if (!pts || pts.length < 2) return ""
    var d = "M" + Number(pts[0][0]).toFixed(2) + " " + Number(pts[0][1]).toFixed(2)
    for (var i = 1; i < pts.length; i++)
      d += "L" + Number(pts[i][0]).toFixed(2) + " " + Number(pts[i][1]).toFixed(2)
    return d + "Z"
  }

  function lerpRing(a, b, t) {
    if (!a || !b) return a || b || []
    var n = Math.min(a.length, b.length)
    var out = []
    for (var i = 0; i < n; i++) {
      out.push([
        a[i][0] + (b[i][0] - a[i][0]) * t,
        a[i][1] + (b[i][1] - a[i][1]) * t
      ])
    }
    return out
  }

  function scaleRingY(pts, sy) {
    if (!pts || pts.length === 0) return pts || []
    var cx = 0, cy = 0, n = pts.length
    for (var i = 0; i < n; i++) {
      cx += pts[i][0]
      cy += pts[i][1]
    }
    cx /= n
    cy /= n
    var out = []
    for (var j = 0; j < n; j++)
      out.push([pts[j][0], cy + (pts[j][1] - cy) * sy])
    return out
  }

  function expr(frameId) {
    if (!mark || !mark.expressions) return null
    var n = Math.max(0, Math.min(mark.expressions.length - 1, frameId))
    return mark.expressions[n]
  }

  function eyeRing(which) {
    var a = expr(0)
    var b = expr(8)
    if (!a) return []
    var t = Math.max(0, Math.min(1, mix))
    if (follow !== 0)
      t = Math.max(0, Math.min(1, t + follow * 0.45))
    var look = lerpRing(a[which], b ? b[which] : a[which], t)
    if (blink > 0.01)
      look = scaleRingY(look, 1 - 0.92 * blink)
    return look
  }

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  FileView {
    id: markFile
    path: decodeURIComponent(Qt.resolvedUrl("official-mark.json").toString().replace(/^file:\/\//, ""))
    printErrors: false
    onLoaded: {
      try { root.mark = JSON.parse(markFile.text()) }
      catch (e) { }
    }
  }

  SequentialAnimation {
    running: root.awake && root.mark
    loops: Animation.Infinite
    PauseAnimation { duration: 1600 }
    NumberAnimation { target: root; property: "mix"; to: 1; duration: 640; easing.type: Easing.InOutCubic }
    PauseAnimation { duration: 1800 }
    NumberAnimation { target: root; property: "mix"; to: 0; duration: 640; easing.type: Easing.InOutCubic }
    PauseAnimation { duration: 900 }
  }

  Timer {
    interval: 2800 + Math.random() * 2200
    running: root.awake && root.mark
    repeat: true
    onTriggered: {
      blinkAnim.restart()
      interval = 3200 + Math.random() * 4200
    }
  }

  SequentialAnimation {
    id: blinkAnim
    NumberAnimation { target: root; property: "blink"; to: 1; duration: 70; easing.type: Easing.OutQuad }
    PauseAnimation { duration: 40 }
    NumberAnimation { target: root; property: "blink"; to: 0; duration: 110; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 80 }
    NumberAnimation { target: root; property: "blink"; to: 1; duration: 70; easing.type: Easing.OutQuad }
    PauseAnimation { duration: 40 }
    NumberAnimation { target: root; property: "blink"; to: 0; duration: 110; easing.type: Easing.OutCubic }
  }

  HoverHandler {
    id: hover
    enabled: root.awake
    onHoveredChanged: if (!hovered) root.follow = 0
  }

  Timer {
    interval: 40
    running: root.awake
    repeat: true
    onTriggered: {
      root.nowMs = Date.now()
      if (hover.hovered && root.width > 1) {
        var nx = hover.point.position.x / root.width
        root.follow = Math.max(-1, Math.min(1, (nx - 0.5) * 1.6))
      } else {
        root.follow = 0
      }
    }
  }

  // Marketing mark is flipped (svg transform: scaleX(-1) on x.ai/bot).
  Item {
    anchors.fill: parent
    transform: Scale {
      xScale: -1
      origin.x: root.width / 2
    }

    Shape {
      id: markShape
      width: 259
      height: 259
      x: 15 * root.s + root.wobbleX
      y: 15 * root.s + root.wobbleY
      transformOrigin: Item.TopLeft
      scale: root.s
      preferredRendererType: Shape.CurveRenderer
      antialiasing: true

      ShapePath {
        fillColor: root.bodyColor
        strokeWidth: 0
        PathSvg { path: root.headPath }
      }
      ShapePath {
        fillColor: root.eyeColor
        strokeWidth: 0
        PathSvg { path: root.eye0Path }
      }
      ShapePath {
        fillColor: root.eyeColor
        strokeWidth: 0
        PathSvg { path: root.eye1Path }
      }
    }
  }
}
