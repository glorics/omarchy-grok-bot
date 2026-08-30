import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.Commons

// Real x.ai/bot mark: official HEAD path + 25 eye rings (2wb8j23k0ritc.js).
// Moods and frame lists come from the production state table in
// 1em52idajmaks.js. Head fill is the Omarchy icon color; eyes use the
// theme background — same pairing as other bar symbols.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool running: false
  property bool alarming: false
  property bool installed: true

  property var mark: null
  property int fromId: 0
  property int toId: 0
  property real mix: 1
  property real blink: 0
  property real follow: 0
  property real nowMs: 0
  property string mood: "idle"
  property int frameIndex: 0

  readonly property bool awake: installed && !alarming
  readonly property real s: width / 259
  readonly property color bodyColor: root.color
  readonly property color eyeColor: Color.background
  readonly property real wobble: {
    if (mood === "playful" || mood === "searching" || mood === "excited")
      return 2.4
    if (mood === "curious" || mood === "confused" || mood === "laughing")
      return 1.6
    return 1.0
  }

  // Official face-only states. Morph overlays (orbit, radar, pencil, …)
  // stay off — they do not read at bar size.
  readonly property var liveCatalog: [
    { name: "idle", frames: [0, 8], hold: [2800, 5200], stay: [6000, 10000] },
    { name: "humming", frames: [0, 8], hold: [3500, 7000], stay: [5000, 9000] },
    { name: "curious", frames: [3, 21, 0, 15], hold: [1800, 3200], stay: [5000, 8000] },
    { name: "thinking", frames: [8, 16, 14, 17, 5], hold: [2000, 3600], stay: [5000, 9000] },
    { name: "listening", frames: [10, 1, 19], hold: [2800, 5000], stay: [5000, 8000] },
    { name: "happy", frames: [2, 11, 17, 19], hold: [2500, 4500], stay: [4500, 8000] },
    { name: "playful", frames: [2, 17, 11, 8], hold: [1500, 3000], stay: [4000, 7000] },
    { name: "searching", frames: [15, 9, 3, 20, 12, 18], hold: [1000, 1800], stay: [4000, 7000] },
    { name: "working", frames: [7, 16, 11, 10], hold: [1800, 3200], stay: [5000, 8000] },
    { name: "surprised", frames: [3, 21], hold: [2500, 4000], stay: [2800, 4200] },
    { name: "proud", frames: [15, 8, 2], hold: [3500, 6000], stay: [4500, 7000] },
    { name: "laughing", frames: [2, 11, 17], hold: [1200, 2400], stay: [3500, 5500] },
    { name: "excited", frames: [2, 17, 21, 3, 11], hold: [1100, 2000], stay: [3500, 5500] }
  ]
  readonly property var restCatalog: [
    { name: "idle", frames: [0, 8], hold: [3500, 7000], stay: [7000, 12000] },
    { name: "humming", frames: [0, 8], hold: [4000, 8000], stay: [6000, 10000] },
    { name: "drowsy", frames: [4, 22, 13], hold: [4000, 8000], stay: [6000, 10000] },
    { name: "bored", frames: [4, 22, 0], hold: [3500, 6000], stay: [6000, 10000] },
    { name: "shy", frames: [0, 24, 13], hold: [3000, 5500], stay: [5000, 8000] },
    { name: "curious", frames: [3, 21, 0, 15], hold: [1800, 3200], stay: [5000, 8000] },
    { name: "confused", frames: [14, 5, 8], hold: [2200, 3800], stay: [4500, 7000] },
    { name: "sad", frames: [4, 13, 22], hold: [4000, 7000], stay: [5000, 8000] }
  ]

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

  function expr(frameId) {
    if (!mark || !mark.expressions) return null
    var n = Math.max(0, Math.min(mark.expressions.length - 1, frameId))
    return mark.expressions[n]
  }

  function moodTable() {
    return root.running ? liveCatalog : restCatalog
  }

  function currentMood() {
    var rows = moodTable()
    for (var slot = 0; slot < rows.length; slot++) {
      if (rows[slot].name === mood)
        return rows[slot]
    }
    return rows[0]
  }

  function randMs(pair) {
    return Math.round(pair[0] + Math.random() * (pair[1] - pair[0]))
  }

  function goTo(frameId) {
    if (frameId === toId && mix >= 0.99) return
    fromId = mix >= 0.5 ? toId : fromId
    toId = frameId
    mix = 0
    mixAnim.restart()
  }

  function advanceFrame() {
    var row = currentMood()
    if (!row || !row.frames || row.frames.length === 0) return
    var n = row.frames.length
    frameIndex = (frameIndex + 1 + Math.floor(Math.random() * Math.max(0, n - 1))) % n
    goTo(row.frames[frameIndex])
    holdTimer.interval = randMs(row.hold)
  }

  function pickMood() {
    var rows = moodTable()
    if (!rows || rows.length === 0) return
    var slot = Math.floor(Math.random() * rows.length)
    if (rows[slot].name === mood && rows.length > 1)
      slot = (slot + 1 + Math.floor(Math.random() * (rows.length - 1))) % rows.length
    mood = rows[slot].name
    frameIndex = 0
    goTo(rows[slot].frames[0])
    holdTimer.interval = randMs(rows[slot].hold)
    moodTimer.interval = randMs(rows[slot].stay)
    holdTimer.restart()
    moodTimer.restart()
  }

  function eyeRing(which) {
    var a = expr(fromId)
    var b = expr(toId)
    var c = expr(4)
    if (!a) return []
    var look = lerpRing(a[which], b ? b[which] : a[which], Math.max(0, Math.min(1, mix)))
    if (follow !== 0) {
      var gaze = expr(follow > 0 ? 0 : 8)
      if (gaze)
        look = lerpRing(look, gaze[which], Math.min(0.55, Math.abs(follow) * 0.45))
    }
    if (c && blink > 0.01)
      look = lerpRing(look, c[which], blink)
    return look
  }

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  onRunningChanged: if (mark) Qt.callLater(pickMood)
  onAwakeChanged: if (awake && mark) Qt.callLater(pickMood)

  FileView {
    id: markFile
    path: decodeURIComponent(Qt.resolvedUrl("official-mark.json").toString().replace(/^file:\/\//, ""))
    printErrors: false
    onLoaded: {
      try {
        root.mark = JSON.parse(markFile.text())
        root.pickMood()
      } catch (e) { }
    }
  }

  NumberAnimation {
    id: mixAnim
    target: root
    property: "mix"
    from: 0
    to: 1
    duration: 480
    easing.type: Easing.InOutCubic
  }

  Timer {
    id: holdTimer
    interval: 3200
    running: root.awake && root.mark
    repeat: true
    onTriggered: root.advanceFrame()
  }

  Timer {
    id: moodTimer
    interval: 7000
    running: root.awake && root.mark
    repeat: true
    onTriggered: root.pickMood()
  }

  Timer {
    id: blinkTimer
    interval: 4500 + Math.random() * 5000
    running: root.awake && root.mark && mood !== "drowsy"
    repeat: true
    onTriggered: {
      blinkAnim.restart()
      interval = 5000 + Math.random() * 9000
    }
  }

  SequentialAnimation {
    id: blinkAnim
    NumberAnimation { target: root; property: "blink"; to: 1; duration: 70; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "blink"; to: 0; duration: 110; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 80 }
    NumberAnimation { target: root; property: "blink"; to: 1; duration: 70; easing.type: Easing.OutQuad }
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
        root.follow = Math.max(-1, Math.min(1, (0.5 - nx) * 1.6))
      } else {
        root.follow = 0
      }
    }
  }

  Shape {
    id: markShape
    width: 259
    height: 259
    x: 15 * root.s + 2 * Math.sin(root.nowMs / 1000 * 0.4) * root.s * root.wobble
    y: 15 * root.s + 1.5 * Math.sin(root.nowMs / 1000 * 0.3) * root.s * root.wobble
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
