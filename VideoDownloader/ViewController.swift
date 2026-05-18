//
//  ViewController.swift
//  VideoDownloader
//
//  Created by Jon Starks on 5/13/26.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var modePopupButton: NSPopUpButton!
    @IBOutlet weak var folderLabel: NSTextField!
    @IBOutlet var logTextView: NSTextView!

    var progressIndicator: NSProgressIndicator!
    var statusLabel: NSTextField!
    var revealButton: NSButton!
    var qualityPopupButton: NSPopUpButton!
    var selectedFolder: URL?
    var lastDownloadedFileURL: URL?
    var downloadStartDate: Date?
    var currentProcess: Process?

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.title = "Video Downloader"
        view.window?.minSize = NSSize(width: 880, height: 760)
        view.window?.makeFirstResponder(urlTextField)
    }

    func buildInterface() {
        view.subviews.removeAll()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        let backgroundView = BackgroundImageView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        // Add DownloaderBackground to Assets.xcassets as an Image Set to use the
        // supplied cinematic mockup background. This view falls back gracefully
        // while the asset is not present.
        backgroundView.image = NSImage(named: "DownloaderBackground")

        let overlayView = NSView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor

        let panel = RoundedPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.fillColor = NSColor(calibratedWhite: 0.08, alpha: 0.58)
        panel.borderColor = NSColor.white.withAlphaComponent(0.16)
        panel.cornerRadius = 22
        panel.shadowOpacity = 0.42
        panel.shadowRadius = 28

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14

        let appIcon = makeAppIconView()
        let titleLabel = makeLabel("Video Downloader", size: 34, weight: .bold, color: .white, alignment: .center)
        let subtitleLabel = makeLabel("Download videos and audio from your favorite websites", size: 15, weight: .regular, color: NSColor.white.withAlphaComponent(0.84), alignment: .center)

        let urlField = makeInputField(placeholder: "https://www.youtube.com/watch?v=...")
        let urlRow = makeInputRow(
            symbolName: "link",
            title: "Video URL",
            subtitle: "Enter the video URL",
            trailingView: urlField
        )

        let pathLabel = makeValueLabel("No folder selected")
        let chooseButton = makeSecondaryButton(title: "Choose Folder", action: #selector(chooseFolderClicked(_:)))
        let folderControls = makeHorizontalStack(spacing: 12, views: [pathLabel, chooseButton])
        let folderRow = makeInputRow(
            symbolName: "folder",
            title: "Save To",
            subtitle: "Choose download location",
            trailingView: folderControls
        )

        let modePopup = makePopup(items: ["Video MP4", "Audio Only MP3"])
        let typeCard = makeSelectorCard(
            symbolName: "music.note",
            title: "Download Type",
            subtitle: "Select what you want to download",
            control: modePopup
        )

        let qualityPopup = makePopup(items: ["Best Available", "1080p", "720p", "480p"])
        let qualityCard = makeSelectorCard(
            symbolName: "gearshape",
            title: "Quality",
            subtitle: "Select video quality",
            control: qualityPopup
        )

        let selectorRow = makeHorizontalStack(spacing: 12, views: [typeCard, qualityCard])
        selectorRow.distribution = .fillEqually

        let downloadButton = GradientButton(title: "Download", target: self, action: #selector(downloadClicked(_:)))
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        downloadButton.symbolName = "arrow.down.to.line.compact"

        let progressBar = NSProgressIndicator()
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.doubleValue = 0
        progressBar.controlSize = .small
        progressBar.style = .bar

        let progressLabel = makeLabel("Ready to download", size: 14, weight: .semibold, color: .white, alignment: .left)
        progressLabel.lineBreakMode = .byTruncatingMiddle

        let statusSubtitle = makeLabel("Enter a URL and click Download to start.", size: 12, weight: .regular, color: NSColor.white.withAlphaComponent(0.66), alignment: .left)

        let clearButton = makePlainIconButton(title: "Clear Log", symbolName: "xmark.circle", action: #selector(clearLogClicked(_:)))
        let finderButton = makePlainIconButton(title: "Reveal", symbolName: "clock", action: #selector(revealInFinderClicked(_:)))
        finderButton.isEnabled = false

        let statusCopy = NSStackView(views: [progressLabel, statusSubtitle, progressBar])
        statusCopy.translatesAutoresizingMaskIntoConstraints = false
        statusCopy.orientation = .vertical
        statusCopy.alignment = .leading
        statusCopy.spacing = 5

        let statusActions = makeHorizontalStack(spacing: 12, views: [finderButton, clearButton])
        let statusTopRow = makeHorizontalStack(spacing: 16, views: [statusCopy, statusActions])
        statusTopRow.alignment = .centerY
        statusCopy.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let scrollView = makeLogScrollView()
        let textView = makeLogTextView()
        scrollView.documentView = textView

        let statusPanel = RoundedPanelView()
        statusPanel.translatesAutoresizingMaskIntoConstraints = false
        statusPanel.fillColor = NSColor(calibratedWhite: 0.12, alpha: 0.50)
        statusPanel.borderColor = NSColor.white.withAlphaComponent(0.14)
        statusPanel.cornerRadius = 14

        let statusStack = NSStackView(views: [statusTopRow, scrollView])
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 10
        statusPanel.addSubview(statusStack)

        let footerRow = makeHorizontalStack(spacing: 12, views: [
            makeFeatureCard(symbolName: "shield", title: "Safe & Secure", subtitle: "No data is collected"),
            makeFeatureCard(symbolName: "bolt", title: "Fast Downloads", subtitle: "Powered by yt-dlp"),
            makeFeatureCard(symbolName: "gearshape", title: "High Quality", subtitle: "Best available formats")
        ])
        footerRow.distribution = .fillEqually

        [appIcon, titleLabel, subtitleLabel, urlRow, folderRow, selectorRow, downloadButton, statusPanel, footerRow].forEach {
            stack.addArrangedSubview($0)
        }

        view.addSubview(backgroundView)
        view.addSubview(overlayView)
        view.addSubview(panel)
        panel.addSubview(stack)

        urlTextField = urlField
        modePopupButton = modePopup
        qualityPopupButton = qualityPopup
        folderLabel = pathLabel
        logTextView = textView
        progressIndicator = progressBar
        statusLabel = progressLabel
        revealButton = finderButton

        let panelWidth = panel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.66)
        panelWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panelWidth,
            panel.widthAnchor.constraint(greaterThanOrEqualToConstant: 720),
            panel.widthAnchor.constraint(lessThanOrEqualToConstant: 980),
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),

            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 34),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 34),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -34),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -28),

            appIcon.widthAnchor.constraint(equalToConstant: 88),
            appIcon.heightAnchor.constraint(equalToConstant: 88),

            urlRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            folderRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            selectorRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            downloadButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            downloadButton.heightAnchor.constraint(equalToConstant: 52),
            statusPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusPanel.heightAnchor.constraint(greaterThanOrEqualToConstant: 152),
            footerRow.widthAnchor.constraint(equalTo: stack.widthAnchor),

            modePopup.widthAnchor.constraint(equalToConstant: 150),
            qualityPopup.widthAnchor.constraint(equalToConstant: 150),

            statusStack.topAnchor.constraint(equalTo: statusPanel.topAnchor, constant: 16),
            statusStack.leadingAnchor.constraint(equalTo: statusPanel.leadingAnchor, constant: 18),
            statusStack.trailingAnchor.constraint(equalTo: statusPanel.trailingAnchor, constant: -18),
            statusStack.bottomAnchor.constraint(equalTo: statusPanel.bottomAnchor, constant: -16),
            statusTopRow.widthAnchor.constraint(equalTo: statusStack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: statusStack.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 76)
        ])
    }

    func makeAppIconView() -> NSView {
        let container = RoundedPanelView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.fillColor = NSColor(calibratedRed: 0.20, green: 0.17, blue: 0.36, alpha: 0.86)
        container.borderColor = NSColor(calibratedRed: 0.54, green: 0.43, blue: 1.0, alpha: 0.72)
        container.cornerRadius = 18
        container.shadowOpacity = 0.28
        container.shadowRadius = 12

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(systemSymbolName: "arrow.down.to.line.compact", accessibilityDescription: "Download")
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 48, weight: .bold)
        imageView.contentTintColor = NSColor(calibratedRed: 0.55, green: 0.35, blue: 1.0, alpha: 1)

        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 54),
            imageView.heightAnchor.constraint(equalToConstant: 54)
        ])

        return container
    }

    func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = alignment
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }

    func makeInputField(placeholder: String) -> NSTextField {
        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.34)]
        )
        field.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        field.textColor = .white
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.55)
        field.focusRingType = .none
        field.wantsLayer = true
        field.layer?.cornerRadius = 8
        field.layer?.borderWidth = 1
        field.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        return field
    }

    func makeValueLabel(_ text: String) -> NSTextField {
        let label = makeLabel(text, size: 14, weight: .regular, color: NSColor.white.withAlphaComponent(0.82), alignment: .left)
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func makeInputRow(symbolName: String, title: String, subtitle: String, trailingView: NSView) -> NSView {
        let row = RoundedPanelView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.fillColor = NSColor(calibratedWhite: 0.12, alpha: 0.52)
        row.borderColor = NSColor.white.withAlphaComponent(0.12)
        row.cornerRadius = 13

        let icon = makeSymbolView(symbolName: symbolName, pointSize: 19)
        let titleLabel = makeLabel(title, size: 14, weight: .semibold, color: .white, alignment: .left)
        let subtitleLabel = makeLabel(subtitle, size: 12, weight: .regular, color: NSColor.white.withAlphaComponent(0.64), alignment: .left)

        let copyStack = NSStackView(views: [titleLabel, subtitleLabel])
        copyStack.translatesAutoresizingMaskIntoConstraints = false
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 2

        row.addSubview(icon)
        row.addSubview(copyStack)
        row.addSubview(trailingView)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 68),

            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 22),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),

            copyStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 18),
            copyStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            copyStack.widthAnchor.constraint(equalToConstant: 170),

            trailingView.leadingAnchor.constraint(equalTo: copyStack.trailingAnchor, constant: 20),
            trailingView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -18),
            trailingView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            trailingView.heightAnchor.constraint(equalToConstant: 40)
        ])

        return row
    }

    func makeSelectorCard(symbolName: String, title: String, subtitle: String, control: NSView) -> NSView {
        let card = RoundedPanelView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.fillColor = NSColor(calibratedWhite: 0.12, alpha: 0.48)
        card.borderColor = NSColor.white.withAlphaComponent(0.12)
        card.cornerRadius = 13

        let icon = makeSymbolView(symbolName: symbolName, pointSize: 19)
        let titleLabel = makeLabel(title, size: 14, weight: .semibold, color: .white, alignment: .left)
        let subtitleLabel = makeLabel(subtitle, size: 12, weight: .regular, color: NSColor.white.withAlphaComponent(0.64), alignment: .left)

        let copyStack = NSStackView(views: [titleLabel, subtitleLabel])
        copyStack.translatesAutoresizingMaskIntoConstraints = false
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 2

        card.addSubview(icon)
        card.addSubview(copyStack)
        card.addSubview(control)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 74),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            copyStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 18),
            copyStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            control.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            control.heightAnchor.constraint(equalToConstant: 38),
            copyStack.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -16)
        ])

        return card
    }

    func makeFeatureCard(symbolName: String, title: String, subtitle: String) -> NSView {
        let card = RoundedPanelView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.fillColor = NSColor(calibratedWhite: 0.10, alpha: 0.42)
        card.borderColor = NSColor.white.withAlphaComponent(0.10)
        card.cornerRadius = 12

        let icon = makeSymbolView(symbolName: symbolName, pointSize: 21)
        let titleLabel = makeLabel(title, size: 13, weight: .medium, color: .white, alignment: .left)
        let subtitleLabel = makeLabel(subtitle, size: 11, weight: .regular, color: NSColor.white.withAlphaComponent(0.62), alignment: .left)

        let copyStack = NSStackView(views: [titleLabel, subtitleLabel])
        copyStack.translatesAutoresizingMaskIntoConstraints = false
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 2

        card.addSubview(icon)
        card.addSubview(copyStack)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 68),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            copyStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            copyStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -14),
            copyStack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }

    func makeSymbolView(symbolName: String, pointSize: CGFloat) -> NSImageView {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        imageView.contentTintColor = NSColor.white.withAlphaComponent(0.86)
        return imageView
    }

    func makePopup(items: [String]) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.addItems(withTitles: items)
        popup.selectItem(at: 0)
        popup.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        popup.contentTintColor = .white
        popup.bezelStyle = .rounded
        popup.wantsLayer = true
        popup.layer?.cornerRadius = 8
        return popup
    }

    func makeSecondaryButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.bezelStyle = .rounded
        button.contentTintColor = NSColor(calibratedRed: 0.78, green: 0.68, blue: 1.0, alpha: 1)
        return button
    }

    func makePlainIconButton(title: String, symbolName: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.contentTintColor = NSColor(calibratedRed: 0.66, green: 0.48, blue: 1.0, alpha: 1)
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        return button
    }

    func makeHorizontalStack(spacing: CGFloat, views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing
        return stack
    }

    func makeLogScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 0.44)
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 10
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        return scrollView
    }

    func makeLogTextView() -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = NSColor.white.withAlphaComponent(0.78)
        textView.backgroundColor = .clear
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        return textView
    }

    @IBAction func chooseFolderClicked(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            selectedFolder = panel.url
            folderLabel.stringValue = panel.url?.path ?? "No folder selected"
            revealButton.isEnabled = true
        }
    }

    @IBAction func downloadClicked(_ sender: NSButton) {
        // If the URL field is still being edited, AppKit may keep the newest text
        // in a temporary field editor. Read from that editor first, then fall back
        // to the text field's stored value.
        let url = currentURLText()

        guard !url.isEmpty else {
            appendLog("Please enter a video URL.\n")
            return
        }

        guard let folder = selectedFolder else {
            appendLog("Please choose a download folder.\n")
            return
        }

        guard currentProcess == nil else {
            appendLog("A download is already running. Please wait for it to finish.\n")
            return
        }

        // This app uses helper programs bundled inside the app, not Homebrew.
        // Homebrew paths such as /opt/homebrew/bin/ffmpeg should not be used for distribution.
        guard let resourcePath = Bundle.main.resourcePath else {
            appendLog("Error: Could not find the app bundle Resources folder.\n")
            return
        }

        guard let ytDLPPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) else {
            appendLog("Error: Could not find bundled yt-dlp in the app bundle.\n")
            appendLog("Check that yt-dlp is included in Copy Bundle Resources.\n")
            return
        }

        let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil)
        let ffprobePath = Bundle.main.path(forResource: "ffprobe", ofType: nil)

        appendLog("Resource path: \(resourcePath)\n")
        appendLog("yt-dlp path: \(ytDLPPath)\n")
        appendLog("ffmpeg path: \(ffmpegPath ?? "Not found")\n")
        appendLog("ffprobe path: \(ffprobePath ?? "Not found")\n")
        appendLog("Selected output folder: \(folder.path)\n")

        guard let ffmpegPath else {
            appendLog("Error: Could not find bundled ffmpeg in the app bundle.\n")
            appendLog("Use a static or universal macOS ffmpeg binary, not Homebrew ffmpeg.\n")
            return
        }

        guard let ffprobePath else {
            appendLog("Error: Could not find bundled ffprobe in the app bundle.\n")
            appendLog("Use a static or universal macOS ffprobe binary, not Homebrew ffprobe.\n")
            return
        }

        guard validateExecutable(path: ytDLPPath, name: "yt-dlp"),
              validateExecutable(path: ffmpegPath, name: "ffmpeg"),
              validateExecutable(path: ffprobePath, name: "ffprobe") else {
            return
        }

        // yt-dlp uses this template to choose the final filename in the selected folder.
        let outputTemplate = folder.appendingPathComponent("%(title)s.%(ext)s").path
        let isAudioOnlyMode = modePopupButton.titleOfSelectedItem == "Audio Only MP3"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDLPPath)

        var arguments = ["--newline", "--print", "after_move:filepath"]

        if isAudioOnlyMode {
            appendLog("Audio Only MP3 mode selected.\n")

            arguments += [
                "--ffmpeg-location", resourcePath,
                // -x tells yt-dlp to extract only the audio track.
                "-x",
                // --audio-format mp3 asks ffmpeg to convert that audio to MP3.
                "--audio-format", "mp3",
                // --audio-quality 0 requests yt-dlp's best MP3 quality setting.
                "--audio-quality", "0",
                "-o", outputTemplate,
                url
            ]
        } else {
            appendLog("Video MP4 mode selected.\n")

            arguments += [
                // Prefer QuickTime-compatible MP4 video with M4A audio.
                // Static ffmpeg and ffprobe builds are required so the app works on Macs without Homebrew.
                "--ffmpeg-location", resourcePath,
                "-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]",
                "--merge-output-format", "mp4",
                "-o", outputTemplate,
                url
            ]
        }

        appendLog("Using app bundle Resources folder for ffmpeg tools.\n")
        appendLog("Full yt-dlp arguments:\n\(formattedArguments(arguments))\n\n")

        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Read yt-dlp's normal output and error output as it runs, without freezing the UI.
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.handleProcessOutput(output)
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.handleProcessOutput(output)
                }
            }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            DispatchQueue.main.async {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                self?.currentProcess = nil
                self?.findDownloadedFileIfNeeded()
                self?.appendLog("\nyt-dlp finished with exit code \(finishedProcess.terminationStatus).\n")

                if finishedProcess.terminationStatus != 0 {
                    self?.finishProgress(exitCode: finishedProcess.terminationStatus)
                    self?.appendLog("Error: yt-dlp exited with non-zero status \(finishedProcess.terminationStatus).\n")
                    return
                }

                if isAudioOnlyMode {
                    self?.progressIndicator.doubleValue = 100
                    self?.statusLabel.stringValue = "Audio MP3 download complete"
                    self?.appendLog("Audio Only MP3 download complete.\n")
                    return
                }

                guard let downloadedFileURL = self?.lastDownloadedFileURL else {
                    self?.finishProgress(exitCode: 1)
                    self?.appendLog("Error: yt-dlp finished, but the downloaded file could not be found for QuickTime conversion.\n")
                    return
                }

                self?.startQuickTimeConversion(inputFileURL: downloadedFileURL, ffmpegPath: ffmpegPath)
            }
        }

        do {
            resetProgress()
            appendLog("Starting yt-dlp...\n")
            appendLog("Saving to: \(outputTemplate)\n\n")
            currentProcess = process
            try process.run()
        } catch {
            currentProcess = nil
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            appendLog("Error running yt-dlp: \(error)\n")
        }
    }

    @IBAction func clearLogClicked(_ sender: NSButton) {
        logTextView.string = ""
    }

    @IBAction func revealInFinderClicked(_ sender: NSButton) {
        if let fileURL = lastDownloadedFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            appendLog("Revealing file in Finder: \(fileURL.path)\n")
            revealInFinder(fileURL)
            return
        }

        guard let folderURL = selectedFolder else {
            appendLog("No download folder selected yet.\n")
            return
        }

        appendLog("Could not find the exact downloaded file, so opening the download folder instead: \(folderURL.path)\n")
        revealInFinder(folderURL)
    }

    func appendLog(_ text: String) {
        logTextView.string += text
        logTextView.scrollToEndOfDocument(nil)
    }

    func handleProcessOutput(_ text: String) {
        appendLog(text)
        updateProgress(from: text)
        updateDownloadedFile(from: text)
    }

    func resetProgress() {
        lastDownloadedFileURL = nil
        downloadStartDate = Date()
        revealButton.isEnabled = selectedFolder != nil
        progressIndicator.doubleValue = 0
        statusLabel.stringValue = "Starting download..."
    }

    func finishProgress(exitCode: Int32) {
        if exitCode == 0 {
            progressIndicator.doubleValue = 100
            statusLabel.stringValue = "Download and conversion complete"
        } else {
            statusLabel.stringValue = "Download ended with exit code \(exitCode)"
        }
    }

    func startQuickTimeConversion(inputFileURL: URL, ffmpegPath: String) {
        let outputFileURL = quickTimeOutputURL(for: inputFileURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-i", inputFileURL.path,
            "-c:v", "libx264",
            "-c:a", "aac",
            outputFileURL.path
        ]

        appendLog("\nStarting QuickTime-compatible MP4 conversion...\n")
        // VLC can play many codecs that QuickTime cannot. This ffmpeg step converts
        // the finished video to H.264 video with AAC audio for better Apple compatibility.
        appendLog("Converting for Apple QuickTime compatibility using bundled ffmpeg.\n")
        appendLog("Input file: \(inputFileURL.path)\n")
        appendLog("Output file: \(outputFileURL.path)\n")
        appendLog("Full ffmpeg arguments:\n\(formattedArguments(process.arguments ?? []))\n\n")

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.appendLog(output)
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.appendLog(output)
                }
            }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            DispatchQueue.main.async {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                self?.currentProcess = nil
                self?.appendLog("\nffmpeg finished with exit code \(finishedProcess.terminationStatus).\n")

                if finishedProcess.terminationStatus == 0 {
                    self?.lastDownloadedFileURL = outputFileURL
                    self?.revealButton.isEnabled = true
                    self?.finishProgress(exitCode: 0)
                    self?.statusLabel.stringValue = "QuickTime MP4 ready: \(outputFileURL.lastPathComponent)"
                    self?.appendLog("QuickTime-compatible file ready: \(outputFileURL.path)\n")
                } else {
                    self?.statusLabel.stringValue = "Conversion ended with exit code \(finishedProcess.terminationStatus)"
                    self?.appendLog("Error: ffmpeg exited with non-zero status \(finishedProcess.terminationStatus).\n")
                }
            }
        }

        do {
            statusLabel.stringValue = "Converting for QuickTime..."
            currentProcess = process
            try process.run()
        } catch {
            currentProcess = nil
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            appendLog("Error running ffmpeg: \(error)\n")
            statusLabel.stringValue = "Conversion failed"
        }
    }

    func quickTimeOutputURL(for inputFileURL: URL) -> URL {
        let folderURL = inputFileURL.deletingLastPathComponent()
        let baseName = inputFileURL.deletingPathExtension().lastPathComponent
        var outputURL = folderURL.appendingPathComponent("\(baseName)_quicktime.mp4")
        var copyNumber = 2

        while FileManager.default.fileExists(atPath: outputURL.path) {
            outputURL = folderURL.appendingPathComponent("\(baseName)_quicktime_\(copyNumber).mp4")
            copyNumber += 1
        }

        return outputURL
    }

    func updateProgress(from text: String) {
        guard let percent = downloadPercent(from: text) else { return }

        progressIndicator.doubleValue = percent
        statusLabel.stringValue = String(format: "Downloading... %.1f%%", percent)
    }

    func downloadPercent(from text: String) -> Double? {
        let pattern = #"\[download\]\s+(\d+(?:\.\d+)?)%"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              let percentRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return Double(text[percentRange])
    }

    func updateDownloadedFile(from text: String) {
        for line in text.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedLine.hasPrefix("/"),
                  trimmedLine != "/",
                  let selectedFolder else {
                continue
            }

            let fileURL = URL(fileURLWithPath: trimmedLine)
            var isDirectory: ObjCBool = false
            let isInsideSelectedFolder = fileURL.path.hasPrefix(selectedFolder.path + "/")

            if isInsideSelectedFolder &&
                FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) &&
                !isDirectory.boolValue {
                lastDownloadedFileURL = fileURL
                revealButton.isEnabled = true
                statusLabel.stringValue = "Ready to reveal: \(fileURL.lastPathComponent)"
                appendLog("Detected downloaded file: \(fileURL.path)\n")
            }
        }
    }

    func revealInFinder(_ url: URL) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let pathExists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        guard pathExists else {
            appendLog("Finder could not reveal this path because it does not exist: \(url.path)\n")
            return
        }

        let didAskFinder: Bool
        if isDirectory.boolValue {
            didAskFinder = NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        } else {
            didAskFinder = NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }

        if didAskFinder {
            appendLog("Finder reveal request sent.\n")
            return
        }

        appendLog("Finder reveal request did not succeed, trying macOS open command.\n")
        openWithFinderFallback(url)
    }

    func openWithFinderFallback(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.path]

        do {
            try process.run()
            appendLog("Open command sent for: \(url.path)\n")
        } catch {
            appendLog("Could not open Finder: \(error.localizedDescription)\n")
        }
    }

    func findDownloadedFileIfNeeded() {
        guard lastDownloadedFileURL == nil,
              let folderURL = selectedFolder,
              let downloadStartDate else {
            return
        }

        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let newestDownloadedFile = fileURLs
            .filter { isLikelyVideoFile($0) }
            .compactMap { fileURL -> (url: URL, modified: Date)? in
                guard let values = try? fileURL.resourceValues(forKeys: keys),
                      values.isRegularFile == true,
                      let modified = values.contentModificationDate,
                      modified >= downloadStartDate.addingTimeInterval(-5) else {
                    return nil
                }

                return (fileURL, modified)
            }
            .max { first, second in
                first.modified < second.modified
            }

        if let newestDownloadedFile {
            lastDownloadedFileURL = newestDownloadedFile.url
            revealButton.isEnabled = true
            statusLabel.stringValue = "Ready to reveal: \(newestDownloadedFile.url.lastPathComponent)"
            appendLog("Detected downloaded file: \(newestDownloadedFile.url.path)\n")
        }
    }

    func isLikelyVideoFile(_ fileURL: URL) -> Bool {
        let mediaExtensions = ["mp3", "mp4", "mkv", "webm", "mov", "m4v", "avi", "flv", "wmv"]
        return mediaExtensions.contains(fileURL.pathExtension.lowercased())
    }

    func currentURLText() -> String {
        view.window?.makeFirstResponder(nil)
        let liveText = urlTextField.currentEditor()?.string
        let text = liveText ?? urlTextField.stringValue
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func validateExecutable(path: String, name: String) -> Bool {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            appendLog("Error: \(name) does not exist at path: \(path)\n")
            return false
        }

        guard fileManager.isExecutableFile(atPath: path) else {
            appendLog("Error: \(name) exists but is not executable: \(path)\n")
            appendLog("Check the Make Bundled Tools Executable build phase.\n")
            return false
        }

        appendLog("\(name) is executable.\n")
        return true
    }

    func formattedArguments(_ arguments: [String]) -> String {
        arguments
            .map { argument in
                argument.contains(" ") ? "\"\(argument)\"" : argument
            }
            .joined(separator: " ")
    }
}
