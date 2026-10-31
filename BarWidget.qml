import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.mohiitp.essentials"
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: "Essentials"
    iconComponent: Component {
      Item {
        Image {
          id: svgIcon
          anchors.centerIn: parent
          source: Qt.resolvedUrl("icon.svg")
          width: Style.bar.iconCanvas
          height: Style.bar.iconCanvas
          sourceSize.width: Style.bar.iconCanvas * 2
          sourceSize.height: Style.bar.iconCanvas * 2
          fillMode: Image.PreserveAspectFit
          visible: false
          layer.enabled: true
        }
        MultiEffect {
          source: svgIcon
          anchors.fill: svgIcon
          colorization: 1.0
          colorizationColor: root.bar ? root.bar.barForeground : "#ffffff"
        }
      }
    }
    onPressed: function(button) { if (button === Qt.LeftButton) root.toggle() }
  }
}
