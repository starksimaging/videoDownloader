# VideoDownloader Setup Notes

- The app is an AppKit app that uses `Main.storyboard`.
- The bundled downloader executable must be named `yt-dlp` and should be part of the `VideoDownloader` app target.
- Bundled media tools must be named `ffmpeg` and `ffprobe`. Put them in the `VideoDownloader` folder and make sure they are copied into the app bundle as resources.
- Do not bundle Homebrew `ffmpeg` or `ffprobe` binaries. Homebrew builds are usually dynamic binaries that depend on libraries in `/opt/homebrew/Cellar/...`, so they can work on the build Mac but fail on another Mac with an error such as `dyld: Library not loaded`.
- Do not use `/opt/homebrew/bin/yt-dlp`, `/opt/homebrew/bin/ffmpeg`, or `/opt/homebrew/bin/ffprobe` in app code.
- Use static or universal macOS builds of `ffmpeg` and `ffprobe` instead. Universal builds are best if the app should run on both Apple Silicon and Intel Macs.
- After replacing the files, select each one in Xcode and confirm Target Membership is checked for the `VideoDownloader` target.
- In Xcode, check the app target's Build Phases and make sure Copy Bundle Resources contains exactly one copy of each:
  - `yt-dlp`
  - `ffmpeg`
  - `ffprobe`
- The target has a build phase named `Make Bundled Tools Executable` that marks bundled tools executable:

```sh
chmod +x "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/yt-dlp"
chmod +x "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/ffmpeg"
chmod +x "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/ffprobe"
```

- The app passes the app bundle's Resources folder to yt-dlp using `--ffmpeg-location Bundle.main.resourcePath`, so yt-dlp can find both `ffmpeg` and `ffprobe`.
- The app logs the resolved `yt-dlp`, `ffmpeg`, `ffprobe`, Resources path, selected output folder, and full yt-dlp arguments at the start of each download.
- The app validates that all three bundled tools exist and are executable before it starts a download.
- The QuickTime-friendly yt-dlp arguments are equivalent to:

```sh
yt-dlp --ffmpeg-location "[resourcePath]" -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]" --merge-output-format mp4 -o "[selectedFolder]/%(title)s.%(ext)s" "[url]"
```

## Replacing Homebrew ffmpeg

1. Delete the Homebrew-built `ffmpeg` and `ffprobe` files from the project.
2. Download static or universal macOS builds of both tools.
3. Rename the files exactly:
   - `ffmpeg`
   - `ffprobe`
4. Put both files in the `VideoDownloader` project folder beside `yt-dlp`.
5. In Xcode, add both files to the project if they are not visible.
6. Select each file and make sure Target Membership includes `VideoDownloader`.
7. Build and run the app.
8. Start a download and check the app log. It should show real paths for all four diagnostics:
   - `Resource path`
   - `yt-dlp path`
   - `ffmpeg path`
   - `ffprobe path`
9. If the app will be shared with Intel Macs, confirm `ffmpeg` and `ffprobe` are universal binaries, not arm64-only binaries.

- App Sandbox is disabled for this learning project. If you enable it later, writing to user-selected folders and launching bundled command-line tools can require additional entitlements or security-scoped resource handling.
