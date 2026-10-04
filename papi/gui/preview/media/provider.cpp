#include <gst/app/gstappsink.h>
#include <gst/video/video.h>

#include <pedro/papi/gui/preview/media/provider.h>

#include <algorithm>
#include <mutex>

namespace Pedro::Papi::Gui::Preview::Media {

    struct Provider::Data {
            GstElement* pipeline = nullptr;
            GstElement* sink = nullptr;
            GstBus* bus = nullptr;
            bool ended = false;
            bool needsPreroll = true;
    };

    Provider::Provider(const QString& kind) : Preview::Provider(kind), data(std::make_unique<Data>()) {

        static std::once_flag initialized;
        std::call_once(initialized, [] { gst_init(nullptr, nullptr); });
        timer.setInterval(33);
        connect(&timer, &QTimer::timeout, this, &Provider::poll);
    }

    Provider::~Provider() {
        close();
    }

    void Provider::open(const QUrl& source) {

        close();
        data->pipeline = gst_element_factory_make("playbin", nullptr);
        data->sink = gst_element_factory_make("appsink", nullptr);

        if (!data->pipeline || !data->sink) {
            close();
            current.error = QStringLiteral("The GStreamer playback plugins are not installed.");
            emit changed();
            return;
        }

        gst_object_ref_sink(data->sink);
        auto* caps = gst_caps_from_string("video/x-raw,format=RGBA,pixel-aspect-ratio=1/1");
        gst_app_sink_set_caps(GST_APP_SINK(data->sink), caps);
        gst_caps_unref(caps);
        g_object_set(data->sink, "max-buffers", 1u, "drop", TRUE, "sync", TRUE, "wait-on-eos", FALSE, nullptr);
        g_object_set(data->pipeline, "uri", source.toEncoded().constData(), "video-sink", data->sink, "volume", double(current.volume), "mute", current.muted, nullptr);
        data->bus = gst_element_get_bus(data->pipeline);
        current.busy = true;
        current.error.clear();

        if (gst_element_set_state(data->pipeline, current.kind == "video" ? GST_STATE_PAUSED : GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
            current.error = QStringLiteral("This media file could not be played.");
            current.busy = false;
        }

        timer.start();
        emit changed();
    }

    void Provider::close() {

        timer.stop();

        if (data->pipeline) {
            gst_element_set_state(data->pipeline, GST_STATE_NULL);
            gst_object_unref(data->pipeline);
        }

        if (data->sink) {
            gst_object_unref(data->sink);
        }

        if (data->bus) {
            gst_object_unref(data->bus);
        }

        *data = Data{};
        Preview::Provider::close();
    }

    void Provider::togglePlayback() {

        if (!data->pipeline || !current.error.isEmpty()) {
            return;
        }

        if (data->ended) {
            seek(0);
            data->ended = false;
        }

        data->needsPreroll = true;
        gst_element_set_state(data->pipeline, current.playing ? GST_STATE_PAUSED : GST_STATE_PLAYING);
    }

    void Provider::seek(qint64 position) {

        if (data->pipeline && current.seekable) {
            data->needsPreroll = true;
            gst_element_seek_simple(data->pipeline, GST_FORMAT_TIME, GstSeekFlags(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT), std::clamp<qint64>(position, 0, current.duration) * GST_MSECOND);
        }
    }

    void Provider::setVolume(qreal volume) {

        current.volume = std::clamp(volume, 0.0, 1.0);

        if (data->pipeline) {
            g_object_set(data->pipeline, "volume", double(current.volume), nullptr);
        }

        emit changed();
    }

    void Provider::setMuted(bool muted) {

        current.muted = muted;

        if (data->pipeline) {
            g_object_set(data->pipeline, "mute", muted, nullptr);
        }

        emit changed();
    }

    void Provider::poll() {

        while (auto* message = gst_bus_pop(data->bus)) {
            switch (GST_MESSAGE_TYPE(message)) {
            case GST_MESSAGE_ERROR: {
                GError* error = nullptr;
                gchar* debug = nullptr;
                gst_message_parse_error(message, &error, &debug);
                current.error = error ? QString::fromUtf8(error->message) : QStringLiteral("Playback failed.");
                g_clear_error(&error);
                g_free(debug);
                gst_element_set_state(data->pipeline, GST_STATE_NULL);
                current.playing = false;
                current.busy = false;
                timer.stop();
                break;
            }
            case GST_MESSAGE_EOS:
                data->ended = true;
                gst_element_set_state(data->pipeline, GST_STATE_PAUSED);
                current.playing = false;
                current.position = current.duration;
                break;
            case GST_MESSAGE_STATE_CHANGED:
                if (GST_MESSAGE_SRC(message) == GST_OBJECT(data->pipeline) && current.error.isEmpty()) {
                    GstState state;
                    gst_message_parse_state_changed(message, nullptr, &state, nullptr);
                    current.playing = state == GST_STATE_PLAYING;
                    current.busy = state < GST_STATE_PAUSED;
                }
                break;
            case GST_MESSAGE_BUFFERING: {
                gint percent = 0;
                gst_message_parse_buffering(message, &percent);
                current.busy = percent < 100;
                break;
            }
            default:
                break;
            }

            gst_message_unref(message);
        }

        gint64 time = 0;

        if (!data->ended && gst_element_query_position(data->pipeline, GST_FORMAT_TIME, &time)) {
            current.position = time / GST_MSECOND;
        }

        if (gst_element_query_duration(data->pipeline, GST_FORMAT_TIME, &time)) {
            current.duration = std::max<qint64>(0, time / GST_MSECOND);
        }

        auto* query = gst_query_new_seeking(GST_FORMAT_TIME);

        if (gst_element_query(data->pipeline, query)) {
            gboolean seekable = FALSE;
            gst_query_parse_seeking(query, nullptr, &seekable, nullptr, nullptr);
            current.seekable = seekable;
        }

        gst_query_unref(query);
        GstSample* sample = nullptr;

        if (current.playing) {
            sample = gst_app_sink_try_pull_sample(GST_APP_SINK(data->sink), 0);
        } else if (data->needsPreroll) {
            sample = gst_app_sink_try_pull_preroll(GST_APP_SINK(data->sink), 0);
        }

        if (sample) {
            data->needsPreroll = false;
            GstVideoInfo info;
            GstVideoFrame frame;

            if (gst_video_info_from_caps(&info, gst_sample_get_caps(sample)) && gst_video_frame_map(&frame, &info, gst_sample_get_buffer(sample), GST_MAP_READ)) {
                current.frame = QImage(static_cast<const uchar*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 0)), GST_VIDEO_FRAME_WIDTH(&frame), GST_VIDEO_FRAME_HEIGHT(&frame), GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 0), QImage::Format_RGBA8888).copy();
                gst_video_frame_unmap(&frame);
            }

            gst_sample_unref(sample);
        }

        emit changed();
    }

}
