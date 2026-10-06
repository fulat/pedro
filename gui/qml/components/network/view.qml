pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../toggle" as Toggle
Pane {
    id: root
    padding: 0
    background: Item {}
    palette.window: "#191d24"
    palette.base: "#20252d"
    palette.button: "#303640"
    palette.text: "#eef0f3"
    palette.buttonText: "#eef0f3"
    palette.windowText: "#eef0f3"
    palette.highlight: "#607184"
    palette.highlightedText: "#ffffff"
    property string page: "home"
    property bool details: false
    property string proxyMode: "off"
    property bool vpnEditor: false
    function tr(key) { return qsTranslate("Pedro", "settings.network." + key); }
    function open(name) { page = name; details = false; }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        ColumnLayout {
            Layout.preferredWidth: 170
            Layout.maximumWidth: 170
            Layout.fillHeight: true
            spacing: 4
            Label { text: root.tr("title"); color: "#f0f1f3"; font.pixelSize: 20; font.weight: Font.DemiBold; Layout.margins: 16 }
            Repeater {
                model: ["home", "wifi", "ethernet", "vpn", "proxy", "advanced", "diagnostics"]
                delegate: Button {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    text: root.tr(modelData)
                    onClicked: root.open(modelData)
                    contentItem: Label { text: parent.text; color: "#e3e5e9"; font.pixelSize: 13; padding: 10 }
                    background: Rectangle { radius: 8; color: root.page === modelData ? "#34404f" : parent.hovered ? "#16ffffff" : "transparent" }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
            Item { Layout.fillHeight: true }
        }
        Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: "#25ffffff" }
        ScrollView {
            id: settingsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.visible: ScrollBar.vertical.size < 1
            ColumnLayout {
                width: settingsScroll.availableWidth
                spacing: 10
                Label { text: root.tr(root.page === "home" ? "title" : root.page); color: "#f0f1f3"; font.pixelSize: 26; font.weight: Font.DemiBold; Layout.margins: 24 }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.bottomMargin: 24
                    spacing: 10
                    ColumnLayout {
                        visible: root.page === "home"
                        Layout.fillWidth: true
                        SettingRow { title: "Wi-Fi"; icon: "../../../assets/icons/wifi.svg"; detail: !Backend.wifiAvailable ? root.tr("unavailable") : Backend.wifiConnected ? Backend.connectedWifiName : root.tr("off"); onActivated: root.open("wifi") }
                        SettingRow { title: "Ethernet"; icon: "../../../assets/icons/ethernet.svg"; detail: Backend.networkConnection.type === "ethernet" ? root.tr("connected") + " · " + Backend.networkConnection.name : root.tr("disconnected"); onActivated: root.open("ethernet") }
                        SettingRow { title: "VPN"; detail: root.tr("notIntegrated"); onActivated: root.open("vpn") }
                        SettingRow { title: "Proxy"; detail: root.tr("notIntegrated"); onActivated: root.open("proxy") }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#25ffffff" }
                        SettingRow { title: root.tr("advanced"); detail: root.tr("advancedHint"); onActivated: root.open("advanced") }
                    }
                    ColumnLayout {
                        visible: root.page === "wifi"
                        Layout.fillWidth: true
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: Backend.wifiAvailable ? "Wi-Fi" : root.tr("unavailable"); color: "#eef0f3"; Layout.fillWidth: true }
                            Toggle.Switch { interactive: Backend.wifiAvailable; active: Backend.wifiAvailable && Backend.wifiEnabled; onToggled: state => Backend.setWifiEnabled(state) }
                        }
                        SettingRow { title: root.tr("current"); detail: Backend.wifiConnected ? Backend.connectedWifiName : root.tr("disconnected"); onActivated: root.details = !root.details }
                        Label { text: root.tr("available"); color: "#a9adb5"; font.pixelSize: 12 }
                        Repeater { model: Backend.wifiNetworks; delegate: SettingRow { required property var modelData; title: modelData.name; detail: modelData.secured ? root.tr("secured") : root.tr("openNetwork"); onActivated: root.details = true } }
                        SettingRow { title: root.tr("known"); detail: root.tr("notIntegrated"); onActivated: root.details = true }
                        ColumnLayout {
                            visible: root.details
                            Layout.fillWidth: true
                            Label { text: root.tr("networkDetails"); color: "#eef0f3"; font.pixelSize: 16 }
                            CheckBox { text: root.tr("autoConnect"); enabled: false }
                            CheckBox { text: root.tr("metered"); enabled: false }
                            Button { text: root.tr("forget"); enabled: false }
                            Label { text: root.tr("pending"); color: "#a9adb5"; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                    }
                    ColumnLayout {
                        visible: root.page === "ethernet"
                        Layout.fillWidth: true
                        SettingRow { title: root.tr("status"); detail: Backend.networkConnection.type === "ethernet" ? root.tr("connected") : root.tr("disconnected"); navigable: false }
                        SettingRow { title: root.tr("connectionName"); detail: Backend.networkConnection.type === "ethernet" ? Backend.networkConnection.name : "—"; navigable: false }
                        SettingRow { title: root.tr("speed"); detail: "—"; navigable: false }
                        SettingRow { title: root.tr("ip"); detail: "—"; navigable: false }
                        SettingRow { title: root.tr("automatic"); detail: root.tr("notIntegrated"); navigable: false }
                        SettingRow { title: root.tr("advanced"); onActivated: root.details = !root.details }
                    }
                    ColumnLayout {
                        visible: root.page === "vpn"
                        Layout.fillWidth: true
                        Label { text: root.tr("vpnHint"); color: "#a9adb5"; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        Button { text: root.tr("addVpn"); onClicked: root.vpnEditor = !root.vpnEditor }
                        SettingField { visible: root.vpnEditor; title: root.tr("connectionName"); placeholder: root.tr("vpnName") }
                        Button { visible: root.vpnEditor; text: root.tr("import"); enabled: false }
                        SettingRow { title: root.tr("savedVpn"); detail: root.tr("notIntegrated"); navigable: false }
                        CheckBox { text: root.tr("autoConnect"); enabled: false }
                        Button { text: root.tr("connect"); enabled: false }
                        Button { text: root.tr("disconnect"); enabled: false }
                        Button { text: root.tr("removeVpn"); enabled: false }
                    }
                    ColumnLayout {
                        visible: root.page === "proxy"
                        Layout.fillWidth: true
                        RowLayout {
                            Repeater { model: ["off", "automaticMode", "manual"]; delegate: RadioButton { required property string modelData; text: root.tr(modelData); checked: root.proxyMode === modelData; onClicked: root.proxyMode = modelData } }
                        }
                        SettingField { visible: root.proxyMode === "automaticMode"; title: root.tr("pac"); placeholder: "https://…" }
                        Repeater {
                            model: root.proxyMode === "manual" ? ["HTTP", "HTTPS", "SOCKS"] : []
                            delegate: ColumnLayout { required property string modelData; Layout.fillWidth: true; Label { text: modelData + " Proxy"; color: "#eef0f3" } SettingField { title: root.tr("host"); placeholder: "proxy.example.com" } SettingField { title: root.tr("port"); placeholder: "8080" } }
                        }
                        Label { text: root.tr("pending"); color: "#a9adb5"; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        Button { text: root.tr("apply"); enabled: false }
                    }
                    ColumnLayout {
                        visible: root.page === "advanced"
                        Layout.fillWidth: true
                        Repeater {
                            model: ["ipSettings", "dns", "routes", "known", "sharing", "airplane", "hardware"]
                            delegate: SettingRow { required property string modelData; title: root.tr(modelData); onActivated: root.details = !root.details }
                        }
                        SettingRow { title: root.tr("diagnostics"); onActivated: root.open("diagnostics") }
                    }
                    ColumnLayout {
                        visible: root.details && (root.page === "ethernet" || root.page === "advanced")
                        Layout.fillWidth: true
                        Label { text: root.tr("ipSettings"); color: "#eef0f3"; font.pixelSize: 16 }
                        ComboBox { model: ["IPv4", "IPv6"]; Layout.fillWidth: true }
                        ComboBox { model: [root.tr("dhcp"), root.tr("manual")]; Layout.fillWidth: true }
                        Repeater { model: ["ip", "subnet", "gateway", "dns", "routes", "mac", "interface"]; delegate: SettingField { required property string modelData; title: root.tr(modelData); placeholder: "—" } }
                        CheckBox { text: root.tr("metered"); enabled: false }
                        CheckBox { visible: root.page === "advanced"; text: root.tr("sharing"); enabled: false }
                        CheckBox { visible: root.page === "advanced"; text: root.tr("airplane"); enabled: false }
                        Label { text: root.tr("pending"); color: "#a9adb5"; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        Button { text: root.tr("apply"); enabled: false }
                    }
                    ColumnLayout {
                        visible: root.page === "diagnostics"
                        Layout.fillWidth: true
                        SettingRow { title: root.tr("networkConnected"); detail: Backend.networkConnection.type !== "none" ? root.tr("connected") : root.tr("disconnected"); navigable: false }
                        Repeater { model: ["gatewayReachable", "internet", "dnsWorking"]; delegate: SettingRow { required property string modelData; title: root.tr(modelData); detail: root.tr("notChecked"); navigable: false } }
                        Button { text: root.tr("runDiagnostics"); enabled: false }
                        Button { text: root.tr("viewDetails"); onClicked: root.details = !root.details }
                        Label { visible: root.details; text: root.tr("diagnosticsPending"); color: "#a9adb5"; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    component SettingRow: Loader {
        property string title
        property string detail: ""
        property url icon
        property bool navigable: true
        signal activated()
        Layout.fillWidth: true
        source: "row.qml"
        onLoaded: {
            item.title = Qt.binding(() => title);
            item.detail = Qt.binding(() => detail);
            item.icon = Qt.binding(() => icon);
            item.navigable = Qt.binding(() => navigable);
            item.activated.connect(() => activated());
        }
    }
    component SettingField: Loader {
        property string title
        property string placeholder: ""
        Layout.fillWidth: true
        source: "field.qml"
        onLoaded: {
            item.title = Qt.binding(() => title);
            item.placeholder = Qt.binding(() => placeholder);
        }
    }
}
