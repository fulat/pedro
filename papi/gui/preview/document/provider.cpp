#include <poppler.h>

#include <pedro/papi/gui/preview/document/provider.h>

#include <QMutex>
#include <QMutexLocker>

#include <algorithm>
#include <cmath>

namespace Pedro::Papi::Gui::Preview::Document {

    struct Provider::Data {
            QUrl source;
            QMutex mutex;
            PopplerDocument* document = nullptr;

            ~Data() {
                if (document) {
                    g_object_unref(document);
                }
            }
    };

    Provider::Provider() : Preview::Provider(QStringLiteral("document")) {
    }

    Provider::~Provider() = default;

    void Provider::open(const QUrl& source) {

        data = std::make_shared<Data>();
        data->source = source;
        render(0);
    }

    void Provider::setPage(int page) {

        if (page < 0 || page >= current.pageCount || page == current.page) {
            return;
        }

        render(page);
    }

    void Provider::render(int pageIndex) {

        const auto input = data;
        run([input, pageIndex] {
            QMutexLocker lock(&input->mutex);
            State result;
            result.kind = QStringLiteral("document");
            result.page = pageIndex;
            GError* error = nullptr;

            if (!input->document) {
                input->document = poppler_document_new_from_file(input->source.toEncoded().constData(), nullptr, &error);
            }

            if (!input->document) {
                result.error = error ? QString::fromUtf8(error->message) : QStringLiteral("The document could not be loaded.");
                g_clear_error(&error);
                return result;
            }

            result.pageCount = poppler_document_get_n_pages(input->document);
            auto* page = poppler_document_get_page(input->document, pageIndex);

            if (!page) {
                result.error = QStringLiteral("This page could not be loaded.");
                return result;
            }

            double width = 0;
            double height = 0;
            poppler_page_get_size(page, &width, &height);

            if (!std::isfinite(width) || !std::isfinite(height) || width <= 0 || height <= 0) {
                result.error = QStringLiteral("This page has an invalid size.");
                g_object_unref(page);
                return result;
            }

            const auto scale = std::min(2.0, 2400.0 / std::max(width, height));
            QImage image(std::max(1, int(std::ceil(width * scale))), std::max(1, int(std::ceil(height * scale))), QImage::Format_ARGB32_Premultiplied);
            if (image.isNull()) {
                result.error = QStringLiteral("There is not enough memory to preview this page.");
                g_object_unref(page);
                return result;
            }

            image.fill(Qt::white);
            auto* surface = cairo_image_surface_create_for_data(image.bits(), CAIRO_FORMAT_ARGB32, image.width(), image.height(), image.bytesPerLine());
            auto* context = cairo_create(surface);
            cairo_scale(context, scale, scale);
            poppler_page_render(page, context);
            cairo_destroy(context);
            cairo_surface_flush(surface);
            cairo_surface_destroy(surface);
            g_object_unref(page);
            result.frame = image;
            return result;
        });
    }

}
