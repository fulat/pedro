#include <gio/gio.h>

#include <pedro/papi/io/content/icon.h>

namespace Pedro::Papi::Io::Content {

    bool isDocument(const QString& type) {

        return type == "application/x-empty" || type == "inode/x-empty" || type.startsWith(QStringLiteral("text/")) || type == "application/pdf" || type == "application/json" || type == "application/xml" || type.contains(QStringLiteral("officedocument")) || type.contains(QStringLiteral("opendocument")) || type == "application/msword" || type == "application/rtf";
    }

    QString visualType(const QString& type) {

        if (type == "application/x-shellscript" || type == "text/x-shellscript" || type == "application/x-sh") {
            return QStringLiteral("shell");
        }

        if (type == "application/x-executable" || type == "application/x-pie-executable" || type == "application/x-sharedlib") {
            return QStringLiteral("executable");
        }

        return isDocument(type) ? QStringLiteral("document") : QStringLiteral("themed");
    }

    QStringList iconNames(const QString& type) {
        QStringList names;
        if (!type.isEmpty()) {
            const auto encoded = type.toUtf8();
            auto* icon = g_content_type_get_icon(encoded.constData());
            if (icon && G_IS_THEMED_ICON(icon)) {
                const auto* candidates = g_themed_icon_get_names(G_THEMED_ICON(icon));
                for (int index = 0; candidates && candidates[index]; ++index) {
                    names.append(QString::fromUtf8(candidates[index]));
                }
            }
            if (icon) {
                g_object_unref(icon);
            }
            auto* generic = g_content_type_get_generic_icon_name(encoded.constData());
            if (generic) {
                names.append(QString::fromUtf8(generic));
                g_free(generic);
            }
        }
        names.append(QStringLiteral("text-x-generic"));
        names.removeDuplicates();
        return names;
    }

}
