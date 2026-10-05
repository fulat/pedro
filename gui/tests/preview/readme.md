# Preview integration check

This check exercises the actual PAPI preview providers and the actual Liquid QML
window. It generates all fixtures under the CMake binary directory using Qt,
Cairo and either FFmpeg or GStreamer CLI. These tools generate test media;
Pedro's runtime uses its existing native providers.

```bash
cmake -S . -B build -G Ninja -DPEDRO_BUILD_IMAGE=OFF \
    -DPEDRO_BUILD_PREVIEW_TESTS=ON
cmake --build build --target pedro-preview-check
```

The check finds `ffmpeg` or `gst-launch-1.0` on PATH. The GStreamer generator
requires `videotestsrc`, `audiotestsrc`, `avenc_mpeg4`, `mp4mux` and `wavenc`.
Use `-DPEDRO_PREVIEW_FFMPEG=/absolute/path/to/tool` to select the generator.
Run `./setup.sh --preview` to install only the new native preview libraries,
or `./setup.sh` for the complete host setup. Install the
FFmpeg command-line tool separately only if the GStreamer generator is unavailable. No OS image is built.

The check covers Glycin image loading, PDF page pixels/navigation, literal text,
large-text bounds, unsupported/corrupt files, superseded loads, GStreamer video
frames/audio, pause/resume, seeking, volume/mute, sibling navigation, closing the
window and closing during an asynchronous load. It also checks external image/PDF/video renames, preserved zoom/page/playback/window geometry, renames after atomic text saves, native PAPI rename/cut, moves of containing folders, clean external text refresh and draft protection after conflicts/deletion. It fails on QML engine warnings.

See `papi/gui/preview/readme.md` for the provider API and current format boundaries.
`pedro-gui --preview /absolute/file` is also available for development diagnostics;
it uses the same internal window rather than a separate preview executable.
