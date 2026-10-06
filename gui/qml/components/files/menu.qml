pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Window
import "../icon" as Icon
import "options.js" as Options

Controls.Menu {
    id: menu
    objectName: "filesBackgroundMenu"
    property var directory
    property var controller
    property Item backdrop
    readonly property bool canCreate: !!directory && String(directory.location).startsWith("file:")
    signal informationRequested()
    signal emptyRequested()
    width: 260
    height: Math.max(1, contentItem.implicitHeight + topPadding + bottomPadding)
    padding: 6
    popupType: Controls.Popup.Window
    cascade: true
    delegate: Action {}
    background: Surface {}
    component Surface: Loader {
        source: "../entry/surface.qml"
        onLoaded: {
            item.sourceBackdrop = Qt.binding(() => menu.backdrop);
            item.frosted = true;
            item.cornerRadius = 12;
        }
    }
    component Action: Controls.MenuItem {
        id: action
        property string symbol: subMenu === organizationMenu ? "organization" : ""
        implicitHeight: visible ? 34 : 0
        leftPadding: 12
        rightPadding: 12
        hoverEnabled: true
        indicator: Item {}
        arrow: Item {}
        contentItem: Item {
            Icon.Tinted {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                source: action.symbol.length ? "../../../assets/icons/" + action.symbol + ".svg" : ""
                opacity: action.enabled ? 1 : 0.4
            }
            Text {
                x: 30
                width: Math.max(0, parent.width - 52)
                text: action.text
                color: "white"
                font.pixelSize: 13
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                opacity: action.enabled ? 1 : 0.4
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: action.checked
                text: "✓"
                color: "white"
            }
            Icon.Tinted {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                visible: !!action.subMenu
                source: "../../../assets/icons/chevron.svg"
                tint: "white"
            }
        }
        background: Rectangle {
            radius: 6
            color: action.enabled && (action.hovered || action.highlighted) ? "#26ffffff" : "transparent"
        }
    }
    Action {
        visible: !menu.directory || !String(menu.directory.location).startsWith("trash:")
        objectName: "filesCreateFolder"
        text: qsTranslate("Pedro", "desktop.menu.folder")
        symbol: "folder"
        enabled: menu.canCreate
        onTriggered: menu.directory.createFolder(text)
    }
    Action {
        visible: !menu.directory || !String(menu.directory.location).startsWith("trash:")
        objectName: "filesCreateFile"
        text: qsTranslate("Pedro", "desktop.menu.file")
        symbol: "file"
        enabled: menu.canCreate
        onTriggered: menu.directory.createFile(text)
    }
    Action {
        visible: !!menu.directory && String(menu.directory.location).startsWith("trash:")
        text: qsTranslate("Pedro", "trash.empty")
        symbol: "trash"
        enabled: !!menu.directory && !Backend.trash.busy && menu.directory.folders.length + menu.directory.files.length > 0
        onTriggered: menu.emptyRequested()
    }
    Action {
        objectName: "filesPaste"
        text: qsTranslate("Pedro", "folder.menu.paste")
        symbol: "paste"
        visible: menu.canCreate
        enabled: menu.canCreate && Backend.clipboard.canPaste && Backend.clipboard.canPasteInto(menu.directory.location)
        onTriggered: Backend.clipboard.paste(menu.directory.location)
    }
    Controls.MenuSeparator {}
    Action {
        text: qsTranslate("Pedro", "desktop.menu.select")
        objectName: "filesSelectAll"
        symbol: "free"
        enabled: !!menu.controller && !!menu.directory && menu.directory.count > 0
        onTriggered: menu.controller.selectAll(menu.directory)
    }
    Controls.Menu {
        id: organizationMenu
        title: qsTranslate("Pedro", "desktop.menu.organization")
        objectName: "filesBackgroundOrganizationMenu"
        enabled: !!menu.controller
        width: 260
        padding: 6
        popupType: Controls.Popup.Window
        background: Surface {}
        delegate: Action {}
        Repeater {
            model: Options.views()
            delegate: Action {
                required property var modelData
                objectName: "filesBackgroundView-" + modelData.key
                text: qsTranslate("Pedro", modelData.label)
                symbol: modelData.icon
                checkable: true
                checked: !!menu.controller && menu.controller.viewMode === modelData.key
                onTriggered: { menu.controller.viewMode = modelData.key; menu.close(); }
            }
        }
        Controls.MenuSeparator {}
        Repeater {
            model: Options.sorting()
            delegate: Action {
                required property var modelData
                objectName: "filesBackgroundSort-" + modelData.key
                text: qsTranslate("Pedro", "desktop.menu." + (modelData.key === "modified" ? "date" : modelData.key))
                symbol: modelData.icon
                checkable: true
                checked: !!menu.controller && menu.controller.sortKey === modelData.key
                onTriggered: { menu.controller.sortKey = modelData.key; menu.close(); }
            }
        }
        Controls.MenuSeparator {}
        Action {
            text: qsTranslate("Pedro", "files.menu.kind")
            objectName: "filesBackgroundKind"
            symbol: "file"
            onTriggered: { menu.controller.sortKey = "type"; menu.close(); }
        }
    }
    Action {
        text: qsTranslate("Pedro", "files.menu.options")
        objectName: "filesBackgroundOptions"
        symbol: "settings"
        enabled: false
    }
    Controls.MenuSeparator {}
    Action {
        text: qsTranslate("Pedro", "folder.menu.properties")
        symbol: "info"
        onTriggered: menu.informationRequested()
    }
}
