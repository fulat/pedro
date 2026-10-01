pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../desktop" as Desktop

// Presentation only. Directory enumeration and operations will come from PAPI.
Rectangle {
    id: browser
    readonly property bool light: Backend.appearanceMode === "light"
    readonly property color ink: light ? "#202b3c" : "#edf2f8"
    readonly property color muted: light ? "#67758a" : "#9caabc"
    readonly property color card: light ? "#ffffff" : "#29323e"
    readonly property color line: light ? "#dce3ed" : "#394453"
    readonly property color accent: "#438cff"
    property string location: "home"
    readonly property var places: ["home", "favorites", "recent", "documents", "downloads", "images", "music", "videos", "computer", "trash"]
    property string selectedPlace: ""
    radius: 10
    color: light ? "#f1f4f8" : "#202630"

    function label(key) {
        return qsTranslate("Pedro", "files.browser." + key);
    }

    component Caption: Text {
        color: browser.ink
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    component Action: Controls.Button {
        id: action
        property bool emphasized: false
        implicitHeight: 34
        leftPadding: 12
        rightPadding: 12
        hoverEnabled: true
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        contentItem: Text {
            text: action.text
            color: action.emphasized ? "white" : browser.ink
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 9
            color: action.emphasized ? browser.accent : action.hovered ? (browser.light ? "#e4ecf7" : "#364356") : browser.card
            border.color: action.emphasized ? browser.accent : browser.line
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Controls.ScrollView {
            Layout.preferredWidth: browser.width < 650 ? 140 : 175
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 4
                Caption {
                    Layout.leftMargin: 12
                    Layout.bottomMargin: 12
                    text: browser.label("places")
                    color: browser.muted
                    font.pixelSize: 11
                }
                Repeater {
                    model: browser.places
                    delegate: Action {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.rightMargin: 12
                        text: browser.label(modelData)
                        emphasized: browser.location === modelData
                        onClicked: {
                            browser.location = modelData;
                            browser.selectedPlace = "";
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: browser.line }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Action { text: "‹"; enabled: false }
                Action { text: "›"; enabled: false }
                Caption {
                    Layout.fillWidth: true
                    text: browser.label("home") + (browser.location === "home" ? "" : "  ›  " + browser.label(browser.location))
                    font.bold: true
                }
                Controls.TextField {
                    Layout.preferredWidth: Math.min(220, browser.width * 0.22)
                    implicitHeight: 34
                    placeholderText: browser.label("search")
                    placeholderTextColor: browser.muted
                    color: browser.ink
                    background: Rectangle { radius: 9; color: browser.card; border.color: browser.line }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Action { text: browser.label("new") + "  +"; emphasized: true }
                Action { text: browser.label("share") }
                Item { Layout.fillWidth: true }
                Action { text: browser.label("view") + "  ▦" }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 96
                radius: 12
                color: browser.light ? "#e0edff" : "#2a3c55"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14
                    Desktop.Icon { kind: "folder"; Layout.preferredWidth: 56; Layout.preferredHeight: 56 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Caption { text: browser.label(browser.location); font.pixelSize: 20; font.bold: true; Layout.fillWidth: true }
                        Caption { text: browser.label("intro"); color: browser.muted; Layout.fillWidth: true }
                    }
                }
            }

            Caption { text: browser.label("folders"); font.bold: true; font.pixelSize: 15 }

            Controls.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                GridLayout {
                    width: parent.width
                    columns: browser.width > 950 ? 3 : browser.width > 650 ? 2 : 1
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: ["documents", "downloads", "images", "music", "videos"]
                        delegate: Rectangle {
                            id: tile
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.minimumWidth: 100
                            height: 92
                            radius: 10
                            color: tileHover.hovered ? (browser.light ? "#e5efff" : "#334660") : browser.card
                            border.color: browser.selectedPlace === modelData ? browser.accent : browser.line
                            HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: browser.selectedPlace = tile.modelData }
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8
                                Desktop.Icon { kind: "folder"; Layout.preferredWidth: 38; Layout.preferredHeight: 38 }
                                Caption { text: browser.label(tile.modelData); Layout.fillWidth: true; font.bold: true }
                            }
                        }
                    }
                }
            }
            Caption {
                Layout.fillWidth: true
                text: browser.label("preview")
                color: browser.muted
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        Rectangle { visible: browser.width >= 900; Layout.fillHeight: true; width: 1; color: browser.line }
        ColumnLayout {
            visible: browser.width >= 900
            Layout.preferredWidth: 190
            Layout.fillHeight: true
            Layout.leftMargin: 18
            spacing: 14
            Desktop.Icon { kind: "folder"; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 88; Layout.preferredHeight: 88 }
            Caption {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: browser.label(browser.selectedPlace || browser.location)
                font.bold: true
                font.pixelSize: 16
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: browser.line }
            Caption { text: browser.label("information"); font.bold: true }
            Caption { text: browser.label("type") + ": " + browser.label("folder"); color: browser.muted }
            Caption { text: browser.label("preview"); Layout.fillWidth: true; wrapMode: Text.WordWrap; color: browser.muted; font.pixelSize: 12 }
            Item { Layout.fillHeight: true }
        }
    }
}
