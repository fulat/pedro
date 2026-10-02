pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../icon" as Icon
import "../../scripts/theme.js" as Theme

Item {
    id: root

    signal settingsRequested

    property bool ipRevealed: false
    property bool ipCopied: false
    property bool menuHovered: false

    onMenuHoveredChanged: {
        if (menuHovered) {
            revealTimer.stop();
        } else if (ipRevealed) {
            revealTimer.restart();
        }
    }

    onIpRevealedChanged: {
        if (ipRevealed && !menuHovered) {
            revealTimer.restart();
        } else {
            revealTimer.stop();
        }
    }
    readonly property string ipAddress: Backend.networkConnection.ipAddress
    readonly property string connectionName: Backend.networkConnection.name

    function hideIp() {
        ipRevealed = false;
        ipCopied = false;
        copiedTimer.stop();
        revealTimer.stop();
    }

    onVisibleChanged: hideIp()
    onIpAddressChanged: hideIp()
    onConnectionNameChanged: hideIp()

    readonly property bool connected: Backend.networkConnection.type !== "none"

    Timer {
        id: revealTimer
        interval: 5000
        onTriggered: root.hideIp()
    }

    Timer {
        id: copiedTimer
        interval: 1600
        onTriggered: root.ipCopied = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 12
                spacing: 18

                Rectangle {
                    Layout.minimumWidth: 40
                    Layout.maximumWidth: 40
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: Theme.cardSurface
                    border.width: 1
                    border.color: root.connected ? Theme.cardBorderStrong : Theme.cardBorder

                    Icon.Tinted {
                        anchors.centerIn: parent
                        width: 23
                        height: 23
                        source: "../../../assets/icons/ethernet.svg"
                        tint: Theme.white
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        Layout.fillWidth: true
                        text: Backend.networkConnection.type === "ethernet" ? qsTranslate("Pedro", "settings.network.ethernet") : qsTranslate("Pedro", "network.connection.title")
                        color: Theme.white
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignLeft
                        spacing: 6

                        Rectangle {
                            implicitWidth: 9
                            implicitHeight: 9
                            radius: 4.5
                            color: root.connected ? "#20dda1" : Theme.textMuted
                        }

                        Label {
                            text: qsTranslate("Pedro", root.connected ? "settings.network.connected" : "settings.network.disconnected")
                            color: Theme.textMuted
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            implicitHeight: 1
            color: "#18ffffff"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 128
            radius: 18
            color: "#0fffffff"
            border.color: "#24ffffff"
            antialiasing: true

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 16
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 6

                Detail {
                    title: qsTranslate("Pedro", "settings.network.connectionName")
                    value: Backend.networkConnection.name || "—"
                    icon: "../../../assets/icons/link.svg"
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "#18ffffff"
                }

                Detail {
                    title: qsTranslate("Pedro", "network.popup.localIp")
                    value: root.ipAddress.length === 0 ? "—" : root.ipRevealed ? root.ipAddress : "********"
                    icon: "../../../assets/icons/location.svg"
                    revealable: true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 8

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                source: "footer.qml"
                onLoaded: {
                    item.title = Qt.binding(() => qsTranslate("Pedro", "network.popup.settings"));
                    item.outlined = true;
                    item.activated.connect(root.settingsRequested);
                }
            }
        }
    }

    component Detail: RowLayout {
        id: detail

        required property string title
        required property string value
        required property url icon
        property bool revealable: false

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 18

        Icon.Tinted {
            source: detail.icon
            tint: Theme.white
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
        }

        function copyAddress() {
            if (!revealable || !root.ipRevealed || !root.ipAddress.length) {
                return;
            }

            valueText.selectAll();
            valueText.copy();
            valueText.deselect();
            root.ipCopied = true;
            copiedTimer.restart();
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                text: detail.title
                color: Theme.textMuted
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Rectangle {
                Layout.alignment: Qt.AlignLeft
                Layout.maximumWidth: parent.width
                implicitWidth: valueText.contentWidth + 24
                implicitHeight: valueText.implicitHeight + 12
                radius: height / 2
                color: copyMouse.pressed ? Theme.overlayPressed : copyMouse.containsMouse ? Theme.overlayHover : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }

                ToolTip.visible: detail.revealable && root.ipRevealed && root.ipCopied
                ToolTip.text: qsTranslate("Pedro", "network.popup.ipCopied")

                TextEdit {
                    id: valueText

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    text: detail.value
                    color: Theme.white
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    font.family: detail.revealable ? "monospace" : Qt.font({}).family
                    font.letterSpacing: detail.revealable ? 0.6 : 0
                    readOnly: true
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.NoWrap
                    clip: true
                    activeFocusOnTab: detail.revealable && root.ipRevealed
                    Accessible.role: detail.revealable && root.ipRevealed ? Accessible.Button : Accessible.StaticText
                    Accessible.name: detail.revealable && root.ipRevealed ? qsTranslate("Pedro", "network.popup.copyIp") : detail.value
                    Accessible.onPressAction: detail.copyAddress()
                    Keys.onReturnPressed: detail.copyAddress()
                    Keys.onEnterPressed: detail.copyAddress()
                    Keys.onSpacePressed: detail.copyAddress()
                }

                MouseArea {
                    id: copyMouse
                    objectName: "ipCopyTarget"
                    anchors.fill: parent
                    enabled: detail.revealable && root.ipRevealed && root.ipAddress.length > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: detail.copyAddress()
                }
            }
        }

        ToolButton {
            id: revealButton

            visible: detail.revealable
            enabled: root.ipAddress.length > 0
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            checkable: true
            checked: root.ipRevealed
            onClicked: {
                root.ipCopied = false;
                copiedTimer.stop();
                root.ipRevealed = !root.ipRevealed;
            }
            Accessible.name: qsTranslate("Pedro", root.ipRevealed ? "network.popup.hideIp" : "network.popup.showIp")
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name

            contentItem: Item {
                Icon.Tinted {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: root.ipRevealed ? "../../../assets/icons/eye.svg" : "../../../assets/icons/hidden.svg"
                    tint: Theme.textMuted
                }
            }

            background: Rectangle {
                radius: 16
                color: revealButton.down ? Theme.overlayPressed : revealButton.hovered ? Theme.overlayHover : "transparent"
            }

            HoverHandler {
                cursorShape: revealButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }
}
