pragma Singleton

import QtQuick
import Pedro.Papi

QtObject {
	readonly property url wallpapers: Qt.resolvedUrl("../../assets/wallpapers/")

	readonly property url wallpaper: Config.wallpaper
}