import QtQuick
import qs.Commons

// Grok Bot mark: glossy orb, two stadium eyes on the right of the face.
// While the box is live the pair glances around the sphere — the painted
// capsules slide and tilt as if they were turning in sockets — then blink.
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
  readonly property color catchColor: luminance > 0.5
    ? Qt.rgba(1, 1, 1, 0.42)
    : Qt.rgba(1, 1, 1, 0.58)
  readonly property color highlightColor: luminance > 0.5
    ? Qt.rgba(1, 1, 1, gleam)
    : Qt.rgba(1, 1, 1, gleam * 0.55)
  readonly property color shadeColor: Qt.rgba(0, 0, 0, luminance > 0.5 ? 0.16 : 0.28)

  readonly property real openLid: {
    if (!installed || (alarming && !running)) return 0.14
    if (!running) return 0.40
    return 1
  }
  property real blinkLid: 1
  readonly property real lid: Math.max(0.08, openLid * blinkLid)

  property real gleam: 0.22
  property real gazeX: 0
  property real gazeY: 0
  property real gazeTilt: 0
  property real breath: 1

  readonly property bool live: running && !alarming
  readonly property bool alert: running && alarming
  readonly property bool drowsy: installed && !running && !alarming

  function resetFace() {
    blinkLid = 1
    gleam = 0.18
    gazeX = 0
    gazeY = 0
    gazeTilt = 0
    breath = 1
  }

  onRunningChanged: if (!running) resetFace()
  onAlarmingChanged: if (alarming) { gazeX = 0; gazeY = 0; gazeTilt = 0 }

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize
  scale: breath
  transformOrigin: Item.Center

  Rectangle {
    id: head
    anchors.fill: parent
    anchors.margins: Math.max(0.5, iconSize * 0.03)
    radius: width / 2
    color: root.color
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
      width: parent.width * 0.48
      height: parent.height * 0.42
      x: parent.width * (0.40 + root.gazeX * 0.13)
      y: parent.height * (0.26 + root.gazeY * 0.11)
      rotation: root.eyeTilt + root.gazeTilt
      transformOrigin: Item.Center

      Eye {
        id: leftEye
        width: Math.max(2, pair.width * 0.36)
        height: Math.max(3, pair.height * 0.90 * root.lid)
        x: 0
        anchors.verticalCenter: parent.verticalCenter
      }

      Eye {
        id: rightEye
        width: leftEye.width
        height: leftEye.height
        x: pair.width - width
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  component Eye: Rectangle {
    color: root.eyeColor
    radius: width / 2
    antialiasing: true
    clip: true

    Rectangle {
      width: Math.max(1, parent.width * 0.45)
      height: Math.max(1, parent.height * 0.28)
      radius: width / 2
      color: root.catchColor
      x: parent.width * (0.18 + root.gazeX * 0.40)
      y: parent.height * (0.14 + root.gazeY * 0.32)
      antialiasing: true
    }
  }

  SequentialAnimation on gleam {
    running: root.live
    loops: Animation.Infinite
    NumberAnimation { to: 0.40; duration: 1600; easing.type: Easing.InOutSine }
    NumberAnimation { to: 0.18; duration: 1600; easing.type: Easing.InOutSine }
  }

  SequentialAnimation on breath {
    running: root.running
    loops: Animation.Infinite
    NumberAnimation { to: 1.045; duration: 2200; easing.type: Easing.InOutSine }
    NumberAnimation { to: 1.0; duration: 2200; easing.type: Easing.InOutSine }
  }

  // Alive: look around the sphere, blink, look again. Holds are long enough
  // that the bar does not flicker; the travel is what reads as "turning."
  SequentialAnimation {
    id: liveLook
    running: root.live
    loops: Animation.Infinite

    PauseAnimation { duration: 1600 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: -0.85; duration: 460; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: 0.12; duration: 460; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: -8; duration: 460; easing.type: Easing.InOutCubic }
    }
    PauseAnimation { duration: 720 }
    SequentialAnimation {
      NumberAnimation { target: root; property: "blinkLid"; to: 0.08; duration: 70; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "blinkLid"; to: 1; duration: 110; easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: 180 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: 0.92; duration: 520; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: -0.18; duration: 520; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: 7; duration: 520; easing.type: Easing.InOutCubic }
    }
    PauseAnimation { duration: 880 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: 0; duration: 380; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: 0; duration: 380; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: 0; duration: 380; easing.type: Easing.InOutCubic }
    }
    PauseAnimation { duration: 1100 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: 0.55; duration: 400; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: -0.88; duration: 400; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: 5; duration: 400; easing.type: Easing.InOutCubic }
    }
    PauseAnimation { duration: 760 }
    SequentialAnimation {
      NumberAnimation { target: root; property: "blinkLid"; to: 0.08; duration: 70; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "blinkLid"; to: 1; duration: 90; easing.type: Easing.OutCubic }
      PauseAnimation { duration: 70 }
      NumberAnimation { target: root; property: "blinkLid"; to: 0.08; duration: 70; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "blinkLid"; to: 1; duration: 120; easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: 200 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: -0.45; duration: 440; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: 0.60; duration: 440; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: -4; duration: 440; easing.type: Easing.InOutCubic }
    }
    PauseAnimation { duration: 640 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: 0; duration: 420; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: 0; duration: 420; easing.type: Easing.InOutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: 0; duration: 420; easing.type: Easing.InOutCubic }
    }
    PauseAnimation { duration: 1800 }
  }

  SequentialAnimation {
    id: alertLook
    running: root.alert
    loops: Animation.Infinite

    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: -0.9; duration: 220; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: -0.2; duration: 220; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: -6; duration: 220; easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: 280 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: 0.9; duration: 220; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: 0.15; duration: 220; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: 6; duration: 220; easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: 240 }
    SequentialAnimation {
      NumberAnimation { target: root; property: "blinkLid"; to: 0.08; duration: 60; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "blinkLid"; to: 1; duration: 90; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: 0; duration: 200; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "gazeY"; to: 0; duration: 200; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "gazeTilt"; to: 0; duration: 200; easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: 700 }
  }

  SequentialAnimation {
    id: idleLook
    running: root.drowsy
    loops: Animation.Infinite

    PauseAnimation { duration: 4200 }
    SequentialAnimation {
      NumberAnimation { target: root; property: "blinkLid"; to: 0.08; duration: 160; easing.type: Easing.InOutQuad }
      NumberAnimation { target: root; property: "blinkLid"; to: 1; duration: 220; easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: 2600 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: -0.55; duration: 900; easing.type: Easing.InOutSine }
      NumberAnimation { target: root; property: "gazeTilt"; to: -5; duration: 900; easing.type: Easing.InOutSine }
    }
    PauseAnimation { duration: 1400 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gazeX"; to: 0; duration: 800; easing.type: Easing.InOutSine }
      NumberAnimation { target: root; property: "gazeTilt"; to: 0; duration: 800; easing.type: Easing.InOutSine }
    }
    PauseAnimation { duration: 3600 }
  }
}
