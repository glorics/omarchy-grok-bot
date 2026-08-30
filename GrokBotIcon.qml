import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.Commons

// Real x.ai/bot mark: official HEAD path + 25 official eye rings from the
// website JS (2wb8j23k0ritc.js). Idle lerps expressions 0 and 8; blink
// flashes expression 4. Same viewBox, same lerpRing as production.
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

  readonly property bool awake: installed && !alarming
  readonly property real s: width / 259
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
      return Qt.rgba(0.09, 0.09, 0.10, 1)
    return Qt.rgba(0.98, 0.98, 0.98, 1)
  }

  readonly property string headPath: mark && mark.head ? mark.head : fallbackHead
  readonly property string eye0Path: ringPath(eyeRing(0))
  readonly property string eye1Path: ringPath(eyeRing(1))

  // Official idle head (blob). Used until JSON loads.
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

  function expr(id) {
    if (!mark || !mark.expressions) return null
    var i = Math.max(0, Math.min(mark.expressions.length - 1, id))
    return mark.expressions[i]
  }

  function eyeRing(which) {
    var a = expr(0)
    var b = expr(8)
    var c = expr(4)
    if (!a) return []
    var look = lerpRing(a[which], b ? b[which] : a[which], Math.max(0, Math.min(1, mix * 0.72 + follow * 0.55)))
    if (c && blink > 0.01)
      look = lerpRing(look, c[which], blink)
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
    PauseAnimation { duration: 2600 }
    NumberAnimation { target: root; property: "mix"; to: 1; duration: 700; easing.type: Easing.InOutCubic }
    PauseAnimation { duration: 2600 }
    NumberAnimation { target: root; property: "mix"; to: 0; duration: 700; easing.type: Easing.InOutCubic }
  }

  SequentialAnimation {
    running: root.awake && root.mark
    loops: Animation.Infinite
    PauseAnimation { duration: 2970 }
    NumberAnimation { target: root; property: "blink"; to: 1; duration: 80; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "blink"; to: 0; duration: 100; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 240 }
    NumberAnimation { target: root; property: "blink"; to: 1; duration: 80; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "blink"; to: 0; duration: 110; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 9800 }
  }

  HoverHandler {
    id: hover
    enabled: root.awake
    onHoveredChanged: if (!hovered) root.follow = 0
  }

  Timer {
    interval: 33
    running: hover.hovered && root.awake
    repeat: true
    onTriggered: {
      if (root.width <= 1) return
      var nx = hover.point.position.x / root.width
      root.follow = Math.max(-1, Math.min(1, (0.5 - nx) * 1.6))
    }
  }

  Shape {
    id: markShape
    width: 259
    height: 259
    x: 15 * root.s
    y: 15 * root.s
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
