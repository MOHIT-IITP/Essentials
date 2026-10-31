import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.mohiitp.essentials"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var entries: []
  property string searchText: ""
  property bool editing: false
  property int editingIndex: -1
  property bool stateDirectoryReady: false
  property bool pendingSave: false
  property string statusText: ""
  property bool statusIsError: false
  property string pendingCopy: ""
  readonly property string stateDirectory: Quickshell.env("HOME") + "/.local/state/omarchy"
  readonly property string statePath: stateDirectory + "/io.github.mohiitp.essentials.json"
  readonly property string legacyStatePath: stateDirectory + "/information-holder.json"
  readonly property color contentForeground: Color.popups.text
  readonly property color accentColor: Color.accent
  readonly property color mutedForeground: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.55)
  readonly property color hoverFill: Style.hoverFillFor(contentForeground, accentColor)
  readonly property string contentFontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
  readonly property var filteredEntries: entries.filter(function(entry) {
    var query = searchText.trim().toLowerCase()
    if (query === "") return true
    return String(entry.label || "").toLowerCase().indexOf(query) >= 0 || String(entry.value || "").toLowerCase().indexOf(query) >= 0 || String(entry.group || "").toLowerCase().indexOf(query) >= 0
  })

  function open() { clearStatus(); controller.show(); Qt.callLater(function() { searchField.forceActiveFocus() }) }
  function close() { cancelEdit(); controller.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { popoutSwitchClosing = true; close(); Qt.callLater(function() { popoutSwitchClosing = false }) }
  function switchPanel(direction) { return bar && typeof bar.switchPanelFrom === "function" ? bar.switchPanelFrom(barIdentity, direction) : false }
  function flashStatus(message) { statusTimer.stop(); statusIsError = false; statusText = message; statusTimer.restart() }
  function showError(message) { statusTimer.stop(); statusIsError = true; statusText = message }
  function clearStatus() { statusTimer.stop(); statusIsError = false; statusText = "" }
  function normalizeEntries(payload) {
    if (!payload || !Array.isArray(payload.entries)) return []
    return payload.entries.filter(function(entry) { return entry && typeof entry.label === "string" && typeof entry.value === "string" }).map(function(entry) {
      return { id: String(entry.id || (Date.now() + "-" + Math.random())), label: String(entry.label), value: String(entry.value), group: String(entry.group || "General") }
    })
  }
  function loadState(raw) {
    try { entries = normalizeEntries(JSON.parse(raw || "{}")) }
    catch (error) { entries = []; showError("Could not read saved information") }
  }
  function saveState(nextEntries) {
    entries = nextEntries
    if (!stateDirectoryReady) { pendingSave = true; flashStatus("Preparing local storage…"); return }
    stateFile.setText(JSON.stringify({ version: 1, entries: entries }, null, 2) + "\n")
  }
  function startNewEntry() {
    clearStatus(); editing = true; editingIndex = -1
    labelField.text = ""; valueField.text = ""; groupField.text = "Custom"
    Qt.callLater(function() { labelField.forceActiveFocus() })
  }
  function startEdit(index) {
    var entry = filteredEntries[index]
    if (!entry) return
    clearStatus()
    editing = true
    editingIndex = entries.findIndex(function(candidate) { return candidate.id === entry.id })
    labelField.text = entry.label; valueField.text = entry.value; groupField.text = entry.group
    Qt.callLater(function() { labelField.selectAll(); labelField.forceActiveFocus() })
  }
  function cancelEdit() { editing = false; editingIndex = -1; clearStatus(); Qt.callLater(function() { if (opened) searchField.forceActiveFocus() }) }
  function commitEdit() {
    var label = labelField.text.trim(); var value = valueField.text.trim(); var group = groupField.text.trim() || "General"
    if (label === "" || value === "") { showError("A label and value are required"); return }
    var next = entries.slice()
    var validIndex = editingIndex >= 0 && editingIndex < next.length
    var entry = { id: validIndex ? next[editingIndex].id : (Date.now() + "-" + Math.random()), label: label, value: value, group: group }
    if (validIndex) next[editingIndex] = entry; else next.push(entry)
    saveState(next); editing = false; editingIndex = -1; flashStatus("Saved")
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }
  function deleteEntry(index) {
    var entry = filteredEntries[index]; if (!entry) return
    saveState(entries.filter(function(candidate) { return candidate.id !== entry.id })); flashStatus("Deleted " + entry.label)
  }
  function copyValue(value, label) {
    pendingCopy = value
    copyProcess.running = false
    copyProcess.running = true
    flashStatus("Copied " + label)
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.entries = []
    onFileChanged: reload()
    onSaved: secureStateFileProcess.running = true
  }
  Process {
    id: secureStateFileProcess
    command: ["bash", "-c", "if [ -e \"$1\" ] && [ \"$(stat -c %a \"$1\" 2>/dev/null)\" != \"600\" ]; then chmod 600 \"$1\"; fi", "io.github.mohiitp.essentials-secure", root.statePath]
  }
  Process {
    id: stateDirectoryProcess
    command: [
      "bash", "-c",
      "mkdir -p \"$1\" && if [ ! -e \"$2\" ] && [ -e \"$3\" ]; then mv \"$3\" \"$2\"; fi && if [ ! -e \"$2\" ]; then (umask 077 && printf '{\\n  \"version\": 1,\\n  \"entries\": []\\n}\\n' > \"$2\"); fi && chmod 600 \"$2\"",
      "io.github.mohiitp.essentials-init",
      root.stateDirectory,
      root.statePath,
      root.legacyStatePath
    ]
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.stateDirectoryReady = true
        stateFile.reload()
        if (root.pendingSave) {
          root.pendingSave = false
          root.saveState(root.entries)
        }
      } else {
        root.showError("Could not initialize secure storage")
      }
    }
  }
  Process {
    id: copyProcess
    command: ["bash", "-c", "val=\"$ESSENTIALS_COPY_VALUE\"; unset ESSENTIALS_COPY_VALUE; printf %s \"$val\" | wl-copy", "io.github.mohiitp.essentials-copy"]
    environment: ({ "ESSENTIALS_COPY_VALUE": root.pendingCopy })
    onExited: root.pendingCopy = ""
  }
  Timer {
    id: statusTimer
    interval: 2200
    repeat: false
    onTriggered: if (!root.statusIsError) root.statusText = ""
  }
  Component.onCompleted: stateDirectoryProcess.running = true

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: searchField
    contentWidth: popup.fittedContentWidth(Style.space(440))
    contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(540))
    PanelKeyCatcher {
      anchors.fill: parent
      blocked: root.editing || searchField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      Column {
        id: content
        width: parent.width
        spacing: Style.space(9)
        Row {
          width: parent.width
          spacing: Style.space(7)
          Item {
            width: Style.font.icon
            height: Style.font.icon
            anchors.verticalCenter: parent.verticalCenter
            Image {
              id: panelHeaderIcon
              anchors.fill: parent
              source: Qt.resolvedUrl("icon.svg")
              sourceSize.width: width * 2
              sourceSize.height: height * 2
              fillMode: Image.PreserveAspectFit
              visible: false
              layer.enabled: true
            }
            MultiEffect {
              source: panelHeaderIcon
              anchors.fill: panelHeaderIcon
              colorization: 1.0
              colorizationColor: root.contentForeground
              opacity: 0.75
            }
          }
          Text {
            text: "Essentials"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
        Row {
          visible: !root.editing
          width: parent.width
          spacing: Style.space(8)
          TextField {
            id: searchField
            width: parent.width - addButton.width - parent.spacing
            placeholderText: "Search entries"
            text: root.searchText
            foreground: root.contentForeground
            accent: root.accentColor
            font.family: root.contentFontFamily
            onTextEdited: root.searchText = text
            Keys.onEscapePressed: root.close()
          }
          PanelActionButton {
            id: addButton
            iconText: "󰐕"
            tooltipText: "Add entry"
            foreground: root.mutedForeground
            hoverColor: root.contentForeground
            fontFamily: root.contentFontFamily
            size: searchField.implicitHeight
            focusable: true
            onClicked: root.startNewEntry()
          }
        }
        Column {
          visible: root.editing
          width: parent.width
          spacing: Style.space(6)
          Text {
            text: root.editingIndex >= 0 ? "EDIT ENTRY" : "NEW ENTRY"
            color: root.mutedForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          TextField {
            id: labelField
            width: parent.width
            placeholderText: "Label (for example, GitHub)"
            foreground: root.contentForeground
            accent: root.accentColor
            font.family: root.contentFontFamily
            Keys.onReturnPressed: valueField.forceActiveFocus()
            Keys.onEscapePressed: root.cancelEdit()
          }
          TextField {
            id: valueField
            width: parent.width
            placeholderText: "Value to copy"
            foreground: root.contentForeground
            accent: root.accentColor
            font.family: root.contentFontFamily
            Keys.onReturnPressed: groupField.forceActiveFocus()
            Keys.onEscapePressed: root.cancelEdit()
          }
          TextField {
            id: groupField
            width: parent.width
            placeholderText: "Group (for example, Work)"
            foreground: root.contentForeground
            accent: root.accentColor
            font.family: root.contentFontFamily
            Keys.onReturnPressed: root.commitEdit()
            Keys.onEscapePressed: root.cancelEdit()
          }
          Row {
            spacing: Style.space(2)
            Button {
              text: "Save"
              iconText: "󰄬"
              foreground: root.accentColor
              fontFamily: root.contentFontFamily
              focusable: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(3)
              onClicked: root.commitEdit()
            }
            Button {
              text: "Cancel"
              foreground: root.mutedForeground
              fontFamily: root.contentFontFamily
              focusable: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(3)
              onClicked: root.cancelEdit()
            }
          }
        }
        Flickable {
          id: entriesView
          visible: !root.editing
          width: parent.width
          height: Math.min(entriesColumn.implicitHeight, Style.space(300))
          contentWidth: width
          contentHeight: entriesColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          Column {
            id: entriesColumn
            width: parent.width
            spacing: Style.space(2)
            Text {
              visible: root.filteredEntries.length === 0
              width: parent.width
              text: root.entries.length === 0 ? "No entries yet. Use + to add one." : "No matching entries."
              color: root.mutedForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              topPadding: Style.space(2)
              bottomPadding: Style.space(4)
            }
            Repeater {
              model: root.filteredEntries
              delegate: Rectangle {
                id: entryRow
                required property var modelData
                required property int index
                width: entriesColumn.width
                height: entryColumn.implicitHeight + Style.space(14)
                radius: Style.cornerRadius
                color: rowHover.hovered ? root.hoverFill : "transparent"
                Behavior on color { ColorAnimation { duration: 90 } }

                HoverHandler { id: rowHover }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.copyValue(entryRow.modelData.value, entryRow.modelData.label)
                }

                Column {
                  id: entryColumn
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(2)
                  anchors.topMargin: Style.space(7)
                  anchors.bottomMargin: Style.space(7)
                  spacing: Style.space(3)
                  Row {
                    width: parent.width
                    spacing: Style.space(8)
                    Text {
                      width: Math.max(0, parent.width - groupLabel.width - parent.spacing)
                      text: entryRow.modelData.label
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }
                    Text {
                      id: groupLabel
                      text: entryRow.modelData.group
                      color: root.mutedForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                  Row {
                    width: parent.width
                    spacing: Style.space(6)
                    Text {
                      width: Math.max(0, parent.width - entryActions.width - parent.spacing)
                      text: entryRow.modelData.value
                      color: root.mutedForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                    Row {
                      id: entryActions
                      spacing: Style.space(1)
                      opacity: rowHover.hovered ? 1 : 0
                      enabled: rowHover.hovered
                      Behavior on opacity { NumberAnimation { duration: 90 } }
                      PanelActionButton {
                        iconText: "󰆏"
                        tooltipText: "Copy"
                        foreground: root.mutedForeground
                        hoverColor: root.contentForeground
                        fontFamily: root.contentFontFamily
                        onClicked: root.copyValue(entryRow.modelData.value, entryRow.modelData.label)
                      }
                      PanelActionButton {
                        iconText: "󰏫"
                        tooltipText: "Edit"
                        foreground: root.mutedForeground
                        hoverColor: root.contentForeground
                        fontFamily: root.contentFontFamily
                        onClicked: root.startEdit(entryRow.index)
                      }
                      PanelActionButton {
                        iconText: "󰆴"
                        tooltipText: "Delete"
                        foreground: root.mutedForeground
                        hoverColor: Color.urgent
                        fontFamily: root.contentFontFamily
                        onClicked: root.deleteEntry(entryRow.index)
                      }
                    }
                  }
                }
              }
            }
          }
        }
        Text {
          width: parent.width
          text: root.statusText !== ""
            ? root.statusText
            : (root.editing ? "Enter saves  ·  Esc cancels" : "Click to copy  ·  + add  ·  Esc close")
          color: root.statusIsError
            ? Color.urgent
            : (root.statusText !== "" ? root.accentColor : root.mutedForeground)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
