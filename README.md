# Video Downloader

Video Downloader is a macOS AppKit app for downloading online video or audio with bundled command-line tools.

The app is built with Swift, AppKit, and `Main.storyboard`. It keeps the downloader workflow simple: paste a URL, choose a folder, choose a download mode, and watch progress/output in the in-app log.

The current interface uses a dark cinematic background, a translucent glass-style content panel, purple/blue accents, styled input rows, a large Download button, and footer feature cards. The UI is AppKit-only; it does not use SwiftUI or third-party UI libraries.

## Features

- Download video as MP4.
- Download audio only as MP3.
- Let `yt-dlp` and bundled `ffmpeg` merge requested streams into the final MP4.
- Reveal the final downloaded file in Finder.
- Show download progress and command output in the app log.
- Automatically install and update a writable copy of bundled `yt-dlp`.
- Choose the Stable or Nightly `yt-dlp` update channel.
- Recover automatically from a damaged installation or failed update.
- Use bundled `ffmpeg` and `ffprobe` instead of Homebrew paths.
- Modern AppKit interface with background imagery, translucent panels, and responsive layout.

## Interface

The visible interface is built programmatically in `ViewController.swift`, while the app still launches through `Main.storyboard`.

The main screen includes:

- Full-window background image.
- Dark readability overlay.
- Centered glass-style panel.
- App icon, title, and subtitle.
- URL input row.
- Save folder row.
- Download type popup.
- Quality popup for UI selection.
- Large purple Download button.
- Status, progress, installed `yt-dlp` version, update channel, update button, reveal, clear log, and log output area.
- Footer cards for Safe & Secure, Fast Downloads, and High Quality.

### Background Asset

The background image view looks for an asset named exactly:

```text
DownloaderBackground
```

Add this as an Image Set in:

```text
VideoDownloader/Assets.xcassets
```

If the asset is missing, the app falls back to a dark gradient background so the UI still builds and runs.

## Download Modes

### Video MP4

Video mode uses the app-managed writable `yt-dlp` with bundled `ffmpeg` and `ffprobe`.

`yt-dlp` selects MP4 video and M4A audio when available and uses the bundled
`ffmpeg` to merge separate streams when needed:

```sh
yt-dlp --ffmpeg-location "[resourcePath]" -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]" --merge-output-format mp4 -o "[selectedFolder]/%(title)s.%(ext)s" "[url]"
```

The MP4 produced by yt-dlp is the final file. The app does not perform a second
transcode or create an additional compatibility copy.

### Audio Only MP3

Audio mode uses `yt-dlp` audio extraction:

```sh
yt-dlp --ffmpeg-location "[resourcePath]" -x --audio-format mp3 --audio-quality 0 -o "[selectedFolder]/%(title)s.%(ext)s" "[url]"
```

The important options are:

- `-x` extracts audio.
- `--audio-format mp3` converts the audio to MP3.
- `--audio-quality 0` requests the best MP3 quality.

## yt-dlp Installation and Updates

The app bundle contains a known-good `yt-dlp` executable, but normal downloads do not run that bundled file directly. `YTDLPManager` installs a writable copy at:

```text
~/Library/Application Support/VideoDownloader/bin/yt-dlp
```

On first launch, the manager:

1. Creates the `VideoDownloader/bin` Application Support directories if needed.
2. Copies the bundled `yt-dlp` fallback into that directory.
3. Applies executable permissions (`0755`).
4. Runs `yt-dlp --version` to verify the installation.

Every download asks `YTDLPManager` for the executable URL. If the writable copy is missing, damaged, lacks executable permission, cannot launch, or fails its version check, the manager replaces it with a fresh bundled copy and verifies it again.

### Automatic Update Checking

After the interface and log view are ready, the app asynchronously prepares `yt-dlp` and checks for updates. A successful update-check date is stored in `UserDefaults`, so automatic checks run no more than once every 24 hours.

Installation, version checks, updates, and verification run away from the main thread. Standard output and standard error from the updater are displayed in the existing application log.

### Manual Updates and Channels

The status area includes a **Check for yt-dlp Updates** button and an update-channel popup.

- **Stable** is the default and uses `yt-dlp -U`.
- **Nightly** uses `yt-dlp --update-to nightly`.

The selected channel is stored in `UserDefaults`. Manual checks are not subject to the 24-hour automatic-check limit. While an update is running, the button and channel popup are disabled, the interface shows an updating status, and additional update attempts are rejected.

After an update, the manager runs:

```sh
yt-dlp --version
```

The operation is only considered successful when this command exits with status `0` and returns a non-empty version. The verified version is written to the log and displayed in the status area.

### Backup and Recovery

Before replacing or updating an existing executable, the manager preserves:

```text
~/Library/Application Support/VideoDownloader/bin/yt-dlp.backup
```

If an update fails or leaves `yt-dlp` unable to run, the manager restores the backup, reapplies executable permissions, and verifies the restored version. If no usable backup exists, it reinstalls the bundled fallback.

The updater also reports clear errors for missing bundle resources, directory creation or permission failures, process-launch failures, network failures, invalid updated executables, update failures, and backup-restoration failures. If `yt-dlp` reports that it is managed by a package manager and cannot self-update, the app explains that explicitly. The normal app-managed copy originates from the bundled official executable and is writable.

## Bundled Tools

The app bundle must contain:

- `yt-dlp`
- `ffmpeg`
- `ffprobe`

`yt-dlp` is the installation and recovery source. Bundled `ffmpeg` and `ffprobe` continue to be used directly for media processing.

```swift
Bundle.main.url(forResource: "yt-dlp", withExtension: nil)
```

The app passes the bundle Resources folder to the writable `yt-dlp` process with:

```text
--ffmpeg-location [Bundle.main.resourcePath]
```

This lets the writable `yt-dlp` find bundled `ffmpeg` and `ffprobe` without relying on Homebrew.

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
5. `Assets.xcassets` contains the optional `DownloaderBackground` Image Set for the polished background.
6. `Main.storyboard` still has the main scene's custom class set to `ViewController`.
7. `YTDLPManager.swift` has Target Membership checked for the app target.

## Build And Test

From Xcode:

1. Open `VideoDownloader.xcodeproj`.
2. Select the `VideoDownloader` scheme.
3. Build and run on My Mac.
4. Paste a supported video URL.
5. Choose a download folder.
6. Select `Video MP4` or `Audio Only MP3`.
7. Click Download and watch the status/progress/log section.
8. Use Reveal after a successful download to open the output in Finder.
9. Click **Check for yt-dlp Updates** and confirm the controls disable while the updater runs.
10. Switch between Stable and Nightly and confirm the selected channel persists after relaunch.

For a command-line compile check without signing:

```sh
xcodebuild -project VideoDownloader.xcodeproj -scheme VideoDownloader -configuration Debug -derivedDataPath /private/tmp/VideoDownloaderDerivedData CODE_SIGNING_ALLOWED=NO build
```

For normal app launching, use Xcode or a signed build so macOS can open the app bundle correctly.

## Runtime Diagnostics

At the start of a download, the app logs:

- Resource path
- Writable Application Support `yt-dlp` path
- `ffmpeg` path
- `ffprobe` path
- Selected output folder
- Full `yt-dlp` arguments
- Selected mode

At launch and during updates, it also logs installation or repair actions, updater output, backup restoration, and the verified installed version.

If a tool is missing or not executable, the app stops before starting the download and prints a clear error in the log. A broken writable `yt-dlp` is repaired from its backup or the bundled fallback before it is returned to a download process.

## Sandbox Note

App Sandbox is disabled for this learning project. If you enable App Sandbox later, launching bundled command-line tools and writing to user-selected folders may require additional entitlements or security-scoped resource handling.
