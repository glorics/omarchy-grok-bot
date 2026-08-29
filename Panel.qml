import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "glorics.grok-bot"
  ipcTarget: "glorics.grok-bot"
  manageIpc: false

  property int actionIndex: 0
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color iconColor: grok.running ? foreground : dim
  readonly property color barIconColor: grok.alarming ? (bar ? bar.urgent : urgent) : (grok.running ? (bar ? bar.barForeground : foreground) : Qt.darker(bar ? bar.barForeground : foreground, 1.55))

  readonly property var actions: buildActions()
  readonly property var selectedAction: actions.length > 0 ? actions[Math.max(0, Math.min(actionIndex, actions.length - 1))] : null

  function buildActions() {
    var rows = []
    if (grok.installed) {
      rows.push({
        id: "open",
        label: grok.running ? "Focus Grok Bot" : "Open Grok Bot",
        hint: "Enter",
        run: function() { grok.launch(); root.close() }
      })
    } else {
      rows.push({
        id: "install",
        label: "Install Linux client",
        hint: "Enter",
        run: function() { grok.openReleases(); root.close() }
      })
    }
    rows.push({
      id: "check",
      label: "Check for updates",
      hint: "U",
      run: function() { grok.checkForUpdates() }
    })
    if (grok.canSelfUpdate && grok.updateAvailable) {
      rows.push({
        id: "update",
        label: grok.updating ? "Updating…" : "Update now",
        hint: "Shift+U",
        run: function() { grok.updateNow() }
      })
    }
    rows.push({
      id: "github",
      label: "Open GitHub",
      hint: "G",
      run: function() { grok.openGitHub(); root.close() }
    })
    return rows
  }

  function selectAction(index) {
    if (actions.length === 0) return
    var wrapped = ((index % actions.length) + actions.length) % actions.length
    actionIndex = wrapped
  }

  function activateCursor() {
    if (!selectedAction) return
    selectedAction.run()
  }

  function heroMeta() {
    if (grok.updating) return "Updating"
    if (grok.crashed) return "Crashed"
    if (grok.updateAvailable) return "Update available"
    if (grok.running) return "Running"
    if (grok.installed) return "Idle"
    return "Not installed"
  }

  function heroDetail() {
    var version = grok.appVersion || grok.installedVersion
    return version !== "" ? version : ""
  }

  function sourceNote() {
    if (!grok.installed) return "Install the unofficial Linux client, then this widget can launch it."
    if (grok.source === "package" && grok.updateAvailable)
      return "Omarchy's grok-bot package is older than the unofficial AppImage on GitHub."
    return ""
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    actionIndex = 0
    if (panelFlick) panelFlick.contentY = 0
    grok.refresh(false)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onActionsChanged: if (actionIndex >= actions.length) actionIndex = Math.max(0, actions.length - 1)

  Service {
    id: grok
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { grok.refresh(false); return "ok" }
    function launch(): string { grok.launch(); return "ok" }
    function update(): string { grok.updateNow(); return "ok" }
    function status(): string { return grok.statusText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: grok.alarming
    iconComponent: Component {
      Item {
        GrokBotIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
          opacity: grok.installed ? 1.0 : 0.55
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) grok.launch()
      else if (buttonCode === Qt.MiddleButton) grok.checkForUpdates()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        root.cursorActive = true
        if (dy !== 0) root.selectAction(root.actionIndex + dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") grok.refresh(false)
        else if (t === "u") grok.checkForUpdates()
        else if (t === "U") grok.updateNow()
        else if (t === "g" || t === "G") { grok.openGitHub(); root.close() }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "Grok Bot"
            meta: root.heroMeta()
            detail: root.heroDetail()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: grok.running || grok.alarming ? 1.0 : 0.7
            iconComponent: Component {
              GrokBotIcon {
                iconSize: Style.font.display
                color: grok.crashed || grok.updateAvailable ? root.urgent : root.iconColor
              }
            }
            trailingControl: Component {
              PanelActionButton {
                iconText: "󰑐"
                tooltipText: "Refresh (R)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: grok.refresh(false)
              }
            }
          }

          Text {
            visible: grok.actionStatus !== "" || grok.lastError !== ""
            width: parent.width
            text: grok.actionStatus !== "" ? grok.actionStatus : grok.lastError
            color: grok.lastError !== "" && grok.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          BorderSurface {
            visible: grok.crashed || (!grok.installed)
            width: parent.width
            implicitHeight: statusText.implicitHeight + Style.spacing.xl * 2
            color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.10)
            borderSpec: Border.flat(Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.35), 1)
            radius: Style.cornerRadius

            Text {
              id: statusText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              text: grok.crashed
                ? "The last session ended unexpectedly. Open Grok Bot to start a new one."
                : "The unofficial Linux client is not installed on this machine."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap
            InfoPair { label: "Status"; value: grok.statusText }
            InfoPair {
              visible: grok.appVersion !== "" || grok.installedVersion !== ""
              label: "Version"
              value: grok.appVersion || grok.installedVersion
            }
            InfoPair {
              visible: grok.latestVersion !== ""
              label: "GitHub"
              value: grok.latestVersion + (grok.updateAvailable ? " · newer" : " · latest")
            }
            InfoPair { label: "Source"; value: grok.sourceLabel }
          }

          Text {
            visible: !grok.installed || (grok.source === "package" && grok.updateAvailable)
            width: parent.width
            text: root.sourceNote()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            id: actionColumn
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.actions
              ActionRow {
                required property var modelData
                required property int index
                width: actionColumn.width
                action: modelData
                rowIndex: index
              }
            }
          }

          Text {
            width: parent.width
            topPadding: Style.space(2)
            text: "Unofficial Linux client · glorics/grok-bot-linux"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    Text {
      text: label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item {
      width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
      height: 1
    }
    Text {
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property var action: null
    property int rowIndex: 0

    hasCursor: root.cursorActive && root.actionIndex === rowIndex
    foreground: root.foreground
    implicitHeight: actionInner.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.actionIndex = actionRow.rowIndex
      }
      onClicked: if (actionRow.action) actionRow.action.run()
    }

    Row {
      id: actionInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        width: parent.width - hint.implicitWidth - parent.spacing
        text: actionRow.action ? actionRow.action.label : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: hint
        text: actionRow.action ? actionRow.action.hint : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
