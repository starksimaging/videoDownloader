# VideoDownloader

VideoDownloader is a simple macOS AppKit app for downloading online video or audio with bundled command-line tools.

The app is built with Swift, AppKit, and `Main.storyboard`. It is meant as a learning project and keeps the interface simple: paste a URL, choose a folder, choose a download mode, and read progress/output in the log.

## Features

- Download video as MP4.
- Download audio only as MP3.
- Convert finished video downloads to a QuickTime-compatible MP4.
- Reveal the downloaded or converted file in Finder.
- Show download progress and command output in the app log.
- Use bundled `yt-dlp`, `ffmpeg`, and `ffprobe` instead of Homebrew paths.

## Download Modes

### Video MP4

Video mode uses bundled `yt-dlp` with bundled `ffmpeg` and `ffprobe`.

After `yt-dlp` finishes, the app runs bundled `ffmpeg` again to create a QuickTime-friendly file:

```sh
ffmpeg -i inputFile -c:v libx264 -c:a aac outputFile
```

The converted file is named with `_quicktime` before `.mp4`, for example:

```text
Example Video_quicktime.mp4
```

This extra conversion is useful because VLC can play many codecs that QuickTime cannot. Converting to H.264 video and AAC audio improves compatibility with Apple apps.

### Audio Only MP3

Audio mode uses `yt-dlp` audio extraction:

```sh
yt-dlp --ffmpeg-location "[resourcePath]" -x --audio-format mp3 --audio-quality 0 -o "[selectedFolder]/%(title)s.%(ext)s" "[url]"
```

The important options are:

- `-x` extracts audio.
- `--audio-format mp3` converts the audio to MP3.
- `--audio-quality 0` requests the best MP3 quality.

## Bundled Tools

The app expects these files to be bundled inside the app:

- `yt-dlp`
- `ffmpeg`
- `ffprobe`

The code locates `yt-dlp` with:

```swift
Bundle.main.path(forResource: "yt-dlp", ofType: nil)
```

The code passes the app bundle Resources folder to `yt-dlp` with:

```text
--ffmpeg-location [Bundle.main.resourcePath]
```

This lets `yt-dlp` find bundled `ffmpeg` and `ffprobe`.

## Portability Notes

Do not use Homebrew paths in the app:

- `/opt/homebrew/bin/yt-dlp`
- `/opt/homebrew/bin/ffmpeg`
- `/opt/homebrew/bin/ffprobe`
- `/opt/homebrew/Cellar/...`

Homebrew `ffmpeg` and `ffprobe` binaries are often dynamic binaries. They can work on the Mac that built the app, then fail on another Mac because they still depend on libraries in `/opt/homebrew/Cellar/...`.

For distribution, use static or universal macOS builds of `ffmpeg` and `ffprobe`. Universal builds are best if you want the app to run on both Apple Silicon and Intel Macs.

## Xcode Setup Checklist

In Xcode, select the `VideoDownloader` target and check:

1. Build Phases -> Copy Bundle Resources contains exactly one copy of each:
   - `yt-dlp`
   - `ffmpeg`
   - `ffprobe`
2. Build Phases contains a Run Script named `Make Bundled Tools Executable`.
3. The Run Script includes:

```sh
chmod +x "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/yt-dlp"
chmod +x "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/ffmpeg"
chmod +x "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/ffprobe"
```

4. Each bundled tool has Target Membership checked for the app target.

## Runtime Diagnostics

At the start of a download, the app logs:

- Resource path
- `yt-dlp` path
- `ffmpeg` path
- `ffprobe` path
- Selected output folder
- Full `yt-dlp` arguments
- Selected mode

If a tool is missing or not executable, the app stops before starting the download and prints a clear error in the log.

## Sandbox Note

App Sandbox is disabled for this learning project. If you enable App Sandbox later, launching bundled command-line tools and writing to user-selected folders may require additional entitlements or security-scoped resource handling.

