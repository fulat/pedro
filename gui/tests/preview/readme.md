# Preview integration check

This check exercises the actual PAPI preview providers and the actual Liquid QML
window. It generates all fixtures under the CMake binary directory using Qt,
Cairo and FFmpeg. FFmpeg is needed only to generate test media, not by Pedro's
runtime API.

```bash
cmake -S . -B build -G Ninja -DPEDRO_BUILD_IMAGE=OFF \
    -DPEDRO_BUILD_PREVIEW_TESTS=ON
cmake --build build --target pedro-preview-check
```

Use `-DPEDRO_PREVIEW_FFMPEG=/absolute/path/to/ffmpeg` if FFmpeg is not on PATH.
Run `./setup.sh --preview` to install only the new native preview libraries,
or `./setup.sh` for the complete host setup. Install the
FFmpeg command-line tool separately for these checks. No OS image is built.

The check covers Glycin image loading, PDF page pixels/navigation, literal text,
large-text bounds, unsupported/corrupt files, superseded loads, GStreamer video
frames/audio, pause/resume, seeking, volume/mute, sibling navigation, closing the
window and closing during an asynchronous load. It fails on QML engine warnings.

See `papi/gui/preview/readme.md` for the provider API and current format boundaries.
`pedro-gui --preview /absolute/file` is also available for development diagnostics;
it uses the same internal window rather than a separate preview executable.
