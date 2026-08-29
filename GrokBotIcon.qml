import QtQuick
import qs.Commons

// Monochrome Grok Bot mark: round head, two capsule eyes. Recolors with the
// bar/panel foreground so it follows the theme instead of shipping a bitmap.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property real eyeTilt: -18

  readonly property real luminance: 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
  readonly property color eyeColor: luminance > 0.5
    ? Qt.rgba(color.r * 0.14, color.g * 0.14, color.b * 0.14, 1)
    : Qt.rgba(Math.min(1, color.r + 0.62), Math.min(1, color.g + 0.62), Math.min(1, color.b + 0.62), 1)

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Rectangle {
    id: head
    anchors.fill: parent
    anchors.margins: Math.max(0.5, iconSize * 0.04)
    radius: width / 2
    color: root.color
    antialiasing: true
  }

  Rectangle {
    id: leftEye
    width: head.width * 0.16
    height: head.height * 0.36
    radius: width / 2
    color: root.eyeColor
    x: head.x + head.width * 0.34
    y: head.y + head.height * 0.28
    rotation: root.eyeTilt
    antialiasing: true
  }

  Rectangle {
    id: rightEye
    width: leftEye.width
    height: leftEye.height
    radius: leftEye.radius
    color: root.eyeColor
    x: head.x + head.width * 0.52
    y: leftEye.y
    rotation: root.eyeTilt
    antialiasing: true
  }
}
