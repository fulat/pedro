#include <glycin.h>

#include <pedro/papi/gui/preview/image/provider.h>

#include <limits>

namespace Pedro::Papi::Gui::Preview::Image {

    Provider::Provider() : Preview::Provider(QStringLiteral("image")) {
    }

    void Provider::open(const QUrl& source) {

        run([source] {
            State result;
            result.kind = QStringLiteral("image");
            GError* error = nullptr;
            auto* file = g_file_new_for_uri(source.toEncoded().constData());
            auto* loader = gly_loader_new(file);
            g_object_unref(file);
            gly_loader_set_accepted_memory_formats(loader, GLY_MEMORY_SELECTION_R8G8B8A8);
            gly_loader_set_apply_transformations(loader, true);
            auto* image = gly_loader_load(loader, &error);
            g_object_unref(loader);

            if (image) {
                const quint64 pixels = quint64(gly_image_get_width(image)) * gly_image_get_height(image);

                if (pixels > 40000000) {
                    result.error = QStringLiteral("This image is too large to preview.");
                } else {
                    auto* frame = gly_image_next_frame(image, &error);

                    if (frame) {
                        const auto width = gly_frame_get_width(frame);
                        const auto height = gly_frame_get_height(frame);
                        const auto stride = gly_frame_get_stride(frame);
                        gsize length = 0;
                        const auto* bytes = static_cast<const uchar*>(g_bytes_get_data(gly_frame_get_buf_bytes(frame), &length));

                        if (gly_frame_get_memory_format(frame) == GLY_MEMORY_R8G8B8A8 && width > 0 && height > 0 && quint64(width) * 4 <= stride && quint64(stride) * height <= length && width <= std::numeric_limits<int>::max() && height <= std::numeric_limits<int>::max()) {
                            result.frame = QImage(bytes, int(width), int(height), stride, QImage::Format_RGBA8888).copy();
                        } else {
                            result.error = QStringLiteral("The image loader returned an unsupported pixel format.");
                        }

                        g_object_unref(frame);
                    }
                }

                g_object_unref(image);
            }

            if (error) {
                result.error = QString::fromUtf8(error->message);
                g_error_free(error);
            }

            if (result.frame.isNull() && result.error.isEmpty()) {
                result.error = QStringLiteral("The image could not be loaded.");
            }

            return result;
        });
    }

}
