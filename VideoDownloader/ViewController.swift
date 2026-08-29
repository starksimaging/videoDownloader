//
//  ViewController.swift
//  VideoDownloader
//
//  Created by Jon Starks on 5/13/26.
//

import Cocoa
import Darwin

class ViewController: NSViewController, NSTextFieldDelegate {

    private let defaultLaunchContentSize = NSSize(width: 900, height: 1000)
    private let minimumUsableContentSize = NSSize(width: 850, height: 960)
    private var didConfigureLaunchWindow = false

    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var modePopupButton: NSPopUpButton!
    @IBOutlet weak var folderLabel: NSTextField!
    @IBOutlet var logTextView: NSTextView!
    @IBOutlet weak var preserveChaptersCheckbox: NSButton!
    @IBOutlet weak var videoTitleLabel: NSTextField!
    @IBOutlet weak var videoUploaderLabel: NSTextField!

    var progressIndicator: NSProgressIndicator!
    var statusLabel: NSTextField!
    var progressPercentageLabel: NSTextField!
    var progressDetailsLabel: NSTextField!
    var revealButton: NSButton!
    var qualityPopupButton: NSPopUpButton!
    var ytDLPUpdateButton: NSButton!
    var ytDLPChannelPopup: NSPopUpButton!
    var ytDLPVersionLabel: NSTextField!
    var downloadButton: NSButton!
    var stopButton: NSButton!
    var saveTranscriptCheckbox: NSButton!
    var selectedFolder: URL?
    var lastDownloadedFileURL: URL?
    var downloadStartDate: Date?
    private var activeDownloadProcess: Process?
    private var isPreparingDownload = false
    private var metadataProcess: Process?
    private var metadataWorkItem: DispatchWorkItem?
    private var metadataURL: String?
    private var metadataTitle: String?
    private var videoInformationView: NSView!
    private var downloadWasCancelled = false
    private var acceptsProgressUpdates = false

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureLaunchWindowIfNeeded()
        view.window?.makeFirstResponder(urlTextField)
    }

    private func configureLaunchWindowIfNeeded() {
        guard !didConfigureLaunchWindow, let window = view.window else { return }
        didConfigureLaunchWindow = true

        window.title = "Video Downloader"

        // The interface is taller than the small storyboard placeholder window.
        // contentMinSize keeps normal resizing available while preventing the
        // controls from being hidden by an unusably small window.
        window.contentMinSize = minimumUsableContentSize

        // If macOS window restoration brings back an old tiny frame, replace it
        // with a usable launch size. A larger user-saved size is left alone.
        let currentContentSize = window.contentLayoutRect.size
        if currentContentSize.width < minimumUsableContentSize.width ||
            currentContentSize.height < minimumUsableContentSize.height {
            window.setContentSize(defaultLaunchContentSize)
            window.center()
        }
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
        urlField.delegate = self
        let urlRow = makeInputRow(
            symbolName: "link",
            title: "Video URL",
            subtitle: "Enter the video URL",
            trailingView: urlField
        )

        let headlineLabel = makeVideoTitleLabel()
        let uploaderLabel = makeLabel("", size: 14, weight: .regular, color: .secondaryLabelColor, alignment: .left)
        let informationCard = makeVideoInformationCard(titleLabel: headlineLabel, uploaderLabel: uploaderLabel)
        informationCard.isHidden = true

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

        let chaptersCheckbox = NSButton(checkboxWithTitle: "Preserve Chapters", target: nil, action: nil)
        chaptersCheckbox.translatesAutoresizingMaskIntoConstraints = false
        chaptersCheckbox.state = .on
        chaptersCheckbox.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        chaptersCheckbox.contentTintColor = .white
        chaptersCheckbox.toolTip = "Embed available yt-dlp chapter markers and save the video metadata"

        let transcriptCheckbox = NSButton(checkboxWithTitle: "Save Transcript", target: nil, action: nil)
        transcriptCheckbox.translatesAutoresizingMaskIntoConstraints = false
        transcriptCheckbox.state = .on
        transcriptCheckbox.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        transcriptCheckbox.contentTintColor = .white
        transcriptCheckbox.toolTip = "Save available English captions as a plain-text transcript"
        let companionOptions = makeHorizontalStack(spacing: 18, views: [chaptersCheckbox, transcriptCheckbox])

        let chaptersCard = makeInputRow(
            symbolName: "list.bullet.rectangle",
            title: "Chapter Markers",
            subtitle: "Keep chapters when the source provides them",
            trailingView: companionOptions
        )

        let downloadButton = GradientButton(title: "Download", target: self, action: #selector(downloadClicked(_:)))
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        downloadButton.symbolName = "arrow.down.to.line.compact"

        let stopButton = GradientButton(title: "Stop", target: self, action: #selector(stopDownload(_:)))
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        stopButton.symbolName = "stop.fill"
        stopButton.isEnabled = false
        let downloadControls = makeHorizontalStack(spacing: 12, views: [downloadButton, stopButton])
        downloadControls.distribution = .fillEqually

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

        let percentageLabel = makeLabel("0%", size: 13, weight: .semibold, color: .white, alignment: .right)
        percentageLabel.setContentHuggingPriority(.required, for: .horizontal)
        let progressRow = makeHorizontalStack(spacing: 12, views: [progressBar, percentageLabel])
        progressBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let statusSubtitle = makeLabel("Enter a URL and click Download to start.", size: 12, weight: .regular, color: NSColor.white.withAlphaComponent(0.66), alignment: .left)

        let clearButton = makePlainIconButton(title: "Clear Log", symbolName: "xmark.circle", action: #selector(clearLogClicked(_:)))
        let finderButton = makePlainIconButton(title: "Reveal", symbolName: "clock", action: #selector(revealInFinderClicked(_:)))
        finderButton.isEnabled = false
        let updateButton = makePlainIconButton(title: "Check for yt-dlp Updates", symbolName: "arrow.triangle.2.circlepath", action: #selector(checkForYTDLPUpdatesClicked(_:)))
        let channelPopup = makePopup(items: YTDLPManager.UpdateChannel.allCases.map(\.displayName))
        channelPopup.target = self
        channelPopup.action = #selector(ytDLPChannelChanged(_:))
        channelPopup.selectItem(withTitle: YTDLPManager.shared.selectedChannel.displayName)
        channelPopup.toolTip = "Choose the yt-dlp update channel"
        let versionLabel = makeLabel("yt-dlp: preparing…", size: 11, weight: .regular, color: NSColor.white.withAlphaComponent(0.66), alignment: .left)

        let statusCopy = NSStackView(views: [progressLabel, progressRow, statusSubtitle])
        statusCopy.translatesAutoresizingMaskIntoConstraints = false
        statusCopy.orientation = .vertical
        statusCopy.alignment = .leading
        statusCopy.spacing = 5

        let statusActions = makeHorizontalStack(spacing: 10, views: [channelPopup, updateButton, finderButton, clearButton])
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

        [appIcon, titleLabel, subtitleLabel, urlRow, informationCard, folderRow, selectorRow, chaptersCard, downloadControls, statusPanel, footerRow].forEach {
            stack.addArrangedSubview($0)
        }

        view.addSubview(backgroundView)
        view.addSubview(overlayView)
        view.addSubview(panel)
        panel.addSubview(stack)

        urlTextField = urlField
        modePopupButton = modePopup
        qualityPopupButton = qualityPopup
        preserveChaptersCheckbox = chaptersCheckbox
        saveTranscriptCheckbox = transcriptCheckbox
        videoTitleLabel = headlineLabel
        videoUploaderLabel = uploaderLabel
        videoInformationView = informationCard
        folderLabel = pathLabel
        logTextView = textView
        progressIndicator = progressBar
        statusLabel = progressLabel
        progressPercentageLabel = percentageLabel
        progressDetailsLabel = statusSubtitle
        revealButton = finderButton
        ytDLPUpdateButton = updateButton
        ytDLPChannelPopup = channelPopup
        ytDLPVersionLabel = versionLabel
        self.downloadButton = downloadButton
        self.stopButton = stopButton
        statusCopy.insertArrangedSubview(versionLabel, at: 2)

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
            informationCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            folderRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            selectorRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            chaptersCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            downloadControls.widthAnchor.constraint(equalTo: stack.widthAnchor),
            downloadButton.heightAnchor.constraint(equalToConstant: 52),
            stopButton.heightAnchor.constraint(equalTo: downloadButton.heightAnchor),
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
            progressRow.widthAnchor.constraint(equalTo: statusCopy.widthAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 8),
            percentageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            scrollView.widthAnchor.constraint(equalTo: statusStack.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 76)
        ])

        prepareYTDLPAndCheckForUpdates()
    }

    private func makeVideoTitleLabel() -> NSTextField {
        let label = makeLabel("", size: 28, weight: .semibold, color: .labelColor, alignment: .left)
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.cell?.wraps = true
        label.cell?.truncatesLastVisibleLine = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func makeVideoInformationCard(titleLabel: NSTextField, uploaderLabel: NSTextField) -> NSView {
        let card = RoundedPanelView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.46)
        card.borderColor = NSColor.separatorColor.withAlphaComponent(0.38)
        card.cornerRadius = 13

        let copyStack = NSStackView(views: [titleLabel, uploaderLabel])
        copyStack.translatesAutoresizingMaskIntoConstraints = false
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 6
        card.addSubview(copyStack)

        NSLayoutConstraint.activate([
            copyStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            copyStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            copyStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            copyStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            titleLabel.widthAnchor.constraint(equalTo: copyStack.widthAnchor),
            uploaderLabel.widthAnchor.constraint(equalTo: copyStack.widthAnchor)
        ])
        return card
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
        if isPreparingDownload || activeDownloadProcess?.isRunning == true {
            appendLog("A download is already running.\n")
            return
        }

        // If the URL field is still being edited, AppKit may keep the newest text
        // in a temporary field editor. Read from that editor first, then fall back
        // to the text field's stored value.
        let url = currentURLText()

        guard !url.isEmpty else {
            appendLog("Please enter a video URL.\n")
            return
        }

        // Do not refetch metadata that was already resolved for this URL.
        if metadataURL != url {
            fetchVideoMetadata(for: url)
        }

        guard let folder = selectedFolder else {
            appendLog("Please choose a download folder.\n")
            return
        }

        // Capture the live checkbox value at the instant the download is requested.
        // Preparing/updating the writable yt-dlp executable is asynchronous, so the
        // rest of this download must not re-read a UI control that may change later.
        let shouldPreserveChapters = preserveChaptersCheckbox.state == .on
        let shouldSaveTranscript = saveTranscriptCheckbox.state == .on

        // This app uses helper programs bundled inside the app, not Homebrew.
        // Homebrew paths such as /opt/homebrew/bin/ffmpeg should not be used for distribution.
        guard let resourcePath = Bundle.main.resourcePath else {
            appendLog("Error: Could not find the app bundle Resources folder.\n")
            return
        }

        let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil)
        let ffprobePath = Bundle.main.path(forResource: "ffprobe", ofType: nil)

        appendLog("Resource path: \(resourcePath)\n")
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

        guard validateExecutable(path: ffmpegPath, name: "ffmpeg"),
              validateExecutable(path: ffprobePath, name: "ffprobe") else {
            return
        }

        isPreparingDownload = true
        setDownloadControls(isDownloading: false, isPreparing: true)
        statusLabel.stringValue = "Preparing yt-dlp..."
        YTDLPManager.shared.executableURL(log: { [weak self] in self?.appendLog($0) }) { [weak self] result in
            guard let self else { return }
            self.isPreparingDownload = false
            switch result {
            case .success(let executableURL):
                self.startDownload(
                    sourceURL: url,
                    folder: folder,
                    ytDLPURL: executableURL,
                    resourcePath: resourcePath,
                    ffprobePath: ffprobePath,
                    shouldPreserveChapters: shouldPreserveChapters,
                    shouldSaveTranscript: shouldSaveTranscript
                )
            case .failure(let error):
                self.setDownloadControls(isDownloading: false)
                self.statusLabel.stringValue = "yt-dlp unavailable"
                self.appendLog("Error preparing yt-dlp: \(error.localizedDescription)\n")
            }
        }
    }

    @IBAction func stopDownload(_ sender: NSButton) {
        guard let process = activeDownloadProcess, process.isRunning else { return }

        downloadWasCancelled = true
        acceptsProgressUpdates = false
        sender.isEnabled = false
        statusLabel.stringValue = "Stopping download…"
        progressDetailsLabel.stringValue = ""
        appendLog("User requested download cancellation.\n")

        let rootPID = process.processIdentifier
        let childPIDs = descendantProcessIDs(of: rootPID)
        childPIDs.reversed().forEach { kill($0, SIGTERM) }
        process.terminate()

        if !childPIDs.isEmpty {
            appendLog("Requested termination of \(childPIDs.count) child process\(childPIDs.count == 1 ? "" : "es") belonging to this download.\n")
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) { [weak self, weak process] in
            guard let process else { return }
            var forcedTermination = false

            for pid in childPIDs where kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
                forcedTermination = true
            }
            if process.isRunning {
                kill(rootPID, SIGKILL)
                forcedTermination = true
            }

            if forcedTermination {
                DispatchQueue.main.async {
                    self?.appendLog("Forced termination of processes that did not exit gracefully.\n")
                }
            }
        }
    }

    private func setDownloadControls(isDownloading: Bool, isPreparing: Bool = false) {
        downloadButton.isEnabled = !isDownloading && !isPreparing
        stopButton.isEnabled = isDownloading
    }

    /// Returns only descendants whose parent chain begins at this app-owned process.
    private func descendantProcessIDs(of parentPID: pid_t) -> [pid_t] {
        var descendants: [pid_t] = []
        var pending = [parentPID]

        while let parent = pending.popLast() {
            var capacity = 16
            while true {
                var children = [pid_t](repeating: 0, count: capacity)
                let byteCount = Int32(children.count * MemoryLayout<pid_t>.size)
                let result = proc_listchildpids(parent, &children, byteCount)
                guard result > 0 else { break }

                let count = Int(result)
                if count < capacity {
                    let validChildren = children.prefix(count).filter { $0 > 0 }
                    descendants.append(contentsOf: validChildren)
                    pending.append(contentsOf: validChildren)
                    break
                }
                capacity *= 2
            }
        }

        return descendants
    }

    private func startDownload(
        sourceURL url: String,
        folder: URL,
        ytDLPURL: URL,
        resourcePath: String,
        ffprobePath: String,
        shouldPreserveChapters: Bool,
        shouldSaveTranscript: Bool
    ) {
        guard activeDownloadProcess?.isRunning != true else {
            appendLog("A download is already running.\n")
            setDownloadControls(isDownloading: true)
            return
        }
        appendLog("yt-dlp path: \(ytDLPURL.path)\n")
        appendLog("Selected output folder: \(folder.path)\n")

        // yt-dlp uses this template to choose the final filename in the selected folder.
        let outputTemplate = folder.appendingPathComponent("%(title)s.%(ext)s").path
        let isAudioOnlyMode = modePopupButton.titleOfSelectedItem == "Audio Only MP3"
        let process = Process()
        process.executableURL = ytDLPURL
        let existingSubtitleFiles = TranscriptProcessor.subtitleFiles(in: folder)

        var arguments = [
            "--newline",
            "--progress-template", YTDLPProgress.template,
            "--print", "after_move:filepath"
        ]
        arguments += ytDLPConfigurationArguments(logRuntimeStatus: true)

        if shouldSaveTranscript {
            appendLog("Transcript requested.\n")
            appendLog("Requesting manually created English subtitles; auto-generated English captions will be used as fallback.\n")
            arguments += [
                "--write-subs",
                "--write-auto-subs",
                "--sub-langs", "en.*",
                "--sub-format", "vtt"
            ]
        }

        if shouldPreserveChapters {
            appendLog("Chapter preservation enabled.\n")
            appendLog("Adding --embed-chapters to yt-dlp.\n")
            arguments += chapterArguments(preservingChapters: true)
        } else {
            appendLog("Chapter preservation disabled.\n")
        }

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
                // Prefer MP4 video with M4A audio and let yt-dlp perform any required merge.
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
        let outputBuffer = NewlineRecordBuffer()
        let errorBuffer = NewlineRecordBuffer()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // FileHandle callbacks deliver arbitrary chunks, so buffer until complete newline records exist.
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let lines = outputBuffer.append(data)
            DispatchQueue.main.async {
                lines.forEach { self?.handleProcessOutputLine($0) }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            let lines = errorBuffer.append(data)
            DispatchQueue.main.async {
                lines.forEach { self?.handleProcessOutputLine($0) }
            }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            DispatchQueue.main.async {
                guard let self else { return }
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                if !self.downloadWasCancelled {
                    if let line = outputBuffer.finish() { self.handleProcessOutputLine(line) }
                    if let line = errorBuffer.finish() { self.handleProcessOutputLine(line) }
                }
                if self.activeDownloadProcess === finishedProcess {
                    self.activeDownloadProcess = nil
                }
                self.acceptsProgressUpdates = false
                self.setDownloadControls(isDownloading: false)
                self.findDownloadedFileIfNeeded()
                self.appendLog("\nyt-dlp finished with exit code \(finishedProcess.terminationStatus).\n")

                if self.downloadWasCancelled {
                    if shouldSaveTranscript {
                        let created = TranscriptProcessor.newlyCreatedSubtitleFiles(in: folder, excluding: existingSubtitleFiles)
                        TranscriptProcessor.removeCreatedSubtitleFiles(created)
                    }
                    self.statusLabel.stringValue = "Download stopped"
                    self.progressDetailsLabel.stringValue = ""
                    self.appendLog("yt-dlp process terminated.\n")
                    return
                }

                if finishedProcess.terminationStatus != 0 {
                    self.finishProgress(exitCode: finishedProcess.terminationStatus)
                    self.appendLog("Error: yt-dlp exited with non-zero status \(finishedProcess.terminationStatus).\n")
                    return
                }

                self.appendLog("yt-dlp download completed.\n")

                if isAudioOnlyMode {
                    self.completeProgress()
                    self.statusLabel.stringValue = "Audio MP3 download complete"
                    self.appendLog("Audio Only MP3 download complete.\n")
                    if shouldSaveTranscript { self.createTranscript(in: folder, excluding: existingSubtitleFiles) }
                    return
                }

                guard let downloadedFileURL = self.lastDownloadedFileURL else {
                    self.finishProgress(exitCode: 1)
                    self.appendLog("Error: yt-dlp finished, but the downloaded MP4 could not be found.\n")
                    return
                }

                self.lastDownloadedFileURL = downloadedFileURL
                self.revealButton.isEnabled = true
                self.finishProgress(exitCode: 0)
                self.statusLabel.stringValue = "Download complete: \(downloadedFileURL.lastPathComponent)"
                self.appendLog("Download complete: \(downloadedFileURL.path)\n")

                if shouldSaveTranscript { self.createTranscript(in: folder, excluding: existingSubtitleFiles) }

                if shouldPreserveChapters {
                    self.appendLog("Checking final MP4 for embedded chapters...\n")
                    self.verifyEmbeddedChapters(
                        in: downloadedFileURL,
                        ffprobePath: ffprobePath
                    )
                }
            }
        }

        do {
            resetProgress()
            appendLog("Live yt-dlp progress reporting enabled.\n")
            appendLog("Starting yt-dlp...\n")
            appendLog("Saving to: \(outputTemplate)\n\n")
            activeDownloadProcess = process
            try process.run()
            acceptsProgressUpdates = true
            setDownloadControls(isDownloading: true)
        } catch {
            activeDownloadProcess = nil
            acceptsProgressUpdates = false
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            setDownloadControls(isDownloading: false)
            statusLabel.stringValue = "Download could not start"
            appendLog("Error running yt-dlp: \(error)\n")
        }
    }

    private func prepareYTDLPAndCheckForUpdates() {
        YTDLPManager.shared.executableURL(log: { [weak self] in self?.appendLog($0) }) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let executableURL):
                self.appendLog("Using writable yt-dlp at \(executableURL.path).\n")
                self.runYTDLPUpdate(manual: false)
            case .failure(let error):
                self.ytDLPVersionLabel.stringValue = "yt-dlp unavailable"
                self.appendLog("Error preparing yt-dlp: \(error.localizedDescription)\n")
            }
        }
    }

    @objc private func checkForYTDLPUpdatesClicked(_ sender: NSButton) {
        guard activeDownloadProcess == nil, !isPreparingDownload else {
            appendLog("Wait for the current download to finish before updating yt-dlp.\n")
            return
        }
        runYTDLPUpdate(manual: true)
    }

    @objc private func ytDLPChannelChanged(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem,
              let channel = YTDLPManager.UpdateChannel(rawValue: title.lowercased()) else { return }
        YTDLPManager.shared.selectedChannel = channel
        appendLog("yt-dlp update channel set to \(channel.displayName).\n")
    }

    private func runYTDLPUpdate(manual: Bool) {
        YTDLPManager.shared.checkForUpdates(
            manual: manual,
            log: { [weak self] in self?.appendLog($0) },
            stateChanged: { [weak self] isUpdating in
                self?.ytDLPUpdateButton.isEnabled = !isUpdating
                self?.ytDLPChannelPopup.isEnabled = !isUpdating
                self?.ytDLPUpdateButton.title = isUpdating ? "Updating yt-dlp…" : "Check for yt-dlp Updates"
                if isUpdating {
                    self?.ytDLPVersionLabel.stringValue = "yt-dlp: updating…"
                }
            },
            completion: { [weak self] result in
                switch result {
                case .success(let version):
                    self?.ytDLPVersionLabel.stringValue = "yt-dlp: \(version)"
                case .failure(let error):
                    self?.ytDLPVersionLabel.stringValue = "yt-dlp update failed"
                    self?.appendLog("yt-dlp update error: \(error.localizedDescription)\n")
                }
            }
        )
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
        text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .forEach(handleProcessOutputLine)
    }

    func handleProcessOutputLine(_ line: String) {
        if let progress = parseYTDLPProgressLine(line) {
            updateProgress(progress)
            return
        }
        appendLog(line + "\n")
        if line.localizedCaseInsensitiveContains("subtitles") || line.localizedCaseInsensitiveContains("captions") {
            statusLabel.stringValue = "Retrieving transcript…"
        }
        updatePostProcessingStatus(from: line)
        updateDownloadedFile(from: line)
    }

    func updatePostProcessingStatus(from text: String) {
        if text.contains("[Merger]") {
            statusLabel.stringValue = "Merging video and audio..."
        } else if text.contains("[EmbedChapters]") || text.localizedCaseInsensitiveContains("embedding chapters") {
            statusLabel.stringValue = "Embedding chapters..."
        }
    }

    func resetProgress() {
        downloadWasCancelled = false
        lastDownloadedFileURL = nil
        downloadStartDate = Date()
        revealButton.isEnabled = selectedFolder != nil
        progressIndicator.doubleValue = 0
        progressPercentageLabel.stringValue = "0%"
        progressDetailsLabel.stringValue = ""
        statusLabel.stringValue = "Starting download..."
    }

    func finishProgress(exitCode: Int32) {
        if exitCode == 0 {
            completeProgress()
            statusLabel.stringValue = "Download complete"
        } else {
            statusLabel.stringValue = "Download ended with exit code \(exitCode)"
        }
    }

    func updateProgress(_ progress: YTDLPProgress) {
        guard acceptsProgressUpdates, !downloadWasCancelled else { return }
        if let percent = progress.calculatedPercent {
            progressIndicator.doubleValue = percent
            progressPercentageLabel.stringValue = percent >= 100 ? "100%" : String(format: "%.1f%%", percent)
        }
        statusLabel.stringValue = "Downloading…"
        progressDetailsLabel.stringValue = progressDetails(for: progress)
    }

    private func completeProgress() {
        progressIndicator.doubleValue = 100
        progressPercentageLabel.stringValue = "100%"
    }

    private func progressDetails(for progress: YTDLPProgress) -> String {
        var details: [String] = []
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        formatter.isAdaptive = true

        if let downloaded = progress.downloadedBytes {
            let downloadedText = formatter.string(fromByteCount: downloaded)
            if let total = progress.effectiveTotalBytes {
                let marker = progress.usesEstimatedTotal ? "~" : ""
                details.append("\(downloadedText) of \(marker)\(formatter.string(fromByteCount: total))")
            } else {
                details.append("\(downloadedText) downloaded")
            }
        }
        if let speed = progress.bytesPerSecond, speed > 0 {
            details.append("\(formatter.string(fromByteCount: Int64(speed)))/s")
        }
        if let eta = progress.etaSeconds, eta >= 0 {
            details.append("ETA \(formattedETA(eta))")
        }
        return details.joined(separator: " · ")
    }

    private func formattedETA(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func createTranscript(in folder: URL, excluding existingFiles: Set<URL>) {
        let candidates = TranscriptProcessor.newlyCreatedSubtitleFiles(in: folder, excluding: existingFiles)
        guard let subtitleURL = TranscriptProcessor.bestSubtitle(from: candidates, matching: lastDownloadedFileURL),
              let mediaURL = lastDownloadedFileURL else {
            statusLabel.stringValue = "Download complete — no transcript available"
            appendLog("No English transcript available for this video.\n")
            return
        }

        statusLabel.stringValue = "Creating transcript…"
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                let transcriptURL = try TranscriptProcessor.createTranscript(from: subtitleURL, beside: mediaURL)
                TranscriptProcessor.removeCreatedSubtitleFiles(candidates)
                DispatchQueue.main.async {
                    guard self?.downloadWasCancelled != true else { return }
                    self?.statusLabel.stringValue = "Transcript saved."
                    self?.appendLog("Transcript saved: \(transcriptURL.path)\n")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = "Download complete — transcript unavailable"
                    self?.appendLog("Transcript could not be created: \(error.localizedDescription)\n")
                    self?.appendLog("Preserved subtitle file for troubleshooting: \(subtitleURL.path)\n")
                }
            }
        }
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

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field === urlTextField else { return }
        let url = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard url != metadataURL else { return }
        clearVideoMetadata()
        metadataWorkItem?.cancel()
        if metadataProcess?.isRunning == true {
            metadataProcess?.terminate()
        }
        metadataProcess = nil

        guard isValidMetadataURL(url) else { return }
        let workItem = DispatchWorkItem { [weak self] in self?.fetchVideoMetadata(for: url) }
        metadataWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: workItem)
    }

    private func isValidMetadataURL(_ value: String) -> Bool {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return false }
        return true
    }

    private func clearVideoMetadata() {
        metadataURL = nil
        metadataTitle = nil
        videoTitleLabel.stringValue = ""
        videoTitleLabel.toolTip = nil
        videoUploaderLabel.stringValue = ""
        videoInformationView.isHidden = true
    }

    private func fetchVideoMetadata(for url: String) {
        guard isValidMetadataURL(url), metadataURL != url else { return }
        metadataURL = url
        appendLog("Retrieving video information…\n")

        YTDLPManager.shared.executableURL(log: { [weak self] in self?.appendLog($0) }) { [weak self] result in
            guard let self, self.metadataURL == url else { return }
            switch result {
            case .failure(let error):
                self.metadataURL = nil
                self.appendLog("Could not retrieve video information: \(error.localizedDescription)\n")
            case .success(let executableURL):
                self.runMetadataExtraction(for: url, executableURL: executableURL)
            }
        }
    }

    private func runMetadataExtraction(for url: String, executableURL: URL) {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = ytDLPConfigurationArguments(logRuntimeStatus: false) + [
            "--skip-download",
            "--no-playlist",
            "--dump-single-json",
            url
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        metadataProcess = process

        DispatchQueue.global(qos: .utility).async { [weak self, weak process] in
            guard let self, let process else { return }
            do {
                try process.run()
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let errorText = String(data: errorData, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    guard self.metadataURL == url else { return }
                    self.metadataProcess = nil
                    guard process.terminationStatus == 0,
                          let object = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
                          let title = object["title"] as? String,
                          !title.isEmpty else {
                        self.metadataURL = nil
                        self.appendLog("Could not retrieve video information. \(errorText.trimmingCharacters(in: .whitespacesAndNewlines))\n")
                        return
                    }

                    let uploader = (object["channel"] as? String)
                        ?? (object["uploader"] as? String)
                        ?? "Unknown channel"
                    self.metadataTitle = title
                    self.videoTitleLabel.stringValue = title
                    self.videoTitleLabel.toolTip = title
                    self.videoUploaderLabel.stringValue = uploader
                    self.videoInformationView.isHidden = false
                    self.appendLog("Video information loaded: \(title) — \(uploader)\n")
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.metadataURL == url else { return }
                    self.metadataProcess = nil
                    self.metadataURL = nil
                    self.appendLog("Could not launch yt-dlp for video information: \(error.localizedDescription)\n")
                }
            }
        }
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

    /// GUI applications do not inherit the interactive shell's PATH, so a Deno
    /// installation in ~/.deno/bin is otherwise invisible to yt-dlp when the app
    /// is launched from Xcode or Finder.
    func availableDenoPath() -> String? {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            Bundle.main.path(forResource: "deno", ofType: nil),
            homeDirectory.appendingPathComponent(".deno/bin/deno").path,
            "/opt/homebrew/bin/deno",
            "/usr/local/bin/deno",
            "/usr/bin/deno"
        ].compactMap { $0 }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Metadata inspection and downloads share these arguments so JavaScript/EJS
    /// extraction behavior and yt-dlp's normal config/cookie handling stay identical.
    func ytDLPConfigurationArguments(logRuntimeStatus: Bool) -> [String] {
        guard let denoPath = availableDenoPath() else {
            if logRuntimeStatus {
                appendLog("Warning: Deno was not found. YouTube may reject some media requests.\n")
            }
            return []
        }
        if logRuntimeStatus {
            appendLog("Deno JavaScript runtime enabled: \(denoPath)\n")
        }
        return ["--js-runtimes", "deno:\(denoPath)"]
    }

    /// yt-dlp chapters are timestamped sections supplied by the video's publisher.
    /// Embedding them does not require writing a separate JSON metadata sidecar.
    func chapterArguments(preservingChapters: Bool) -> [String] {
        preservingChapters
            ? ["--embed-chapters"]
            : []
    }

    private func verifyEmbeddedChapters(
        in mediaURL: URL,
        ffprobePath: String
    ) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            let outputPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: ffprobePath)
            process.arguments = [
                "-v", "quiet",
                "-print_format", "json",
                "-show_chapters",
                mediaURL.path
            ]
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            var chapters: [[String: Any]] = []
            var failureMessage: String?
            do {
                try process.run()
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus == 0,
                   let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    chapters = root["chapters"] as? [[String: Any]] ?? []
                } else {
                    failureMessage = "ffprobe exited with status \(process.terminationStatus)."
                }
            } catch {
                failureMessage = "ffprobe could not be launched: \(error.localizedDescription)"
            }

            let chapterLines = chapters.map { chapter -> String in
                let start = Double(chapter["start_time"] as? String ?? "")
                    ?? chapter["start_time"] as? Double
                    ?? 0
                let tags = chapter["tags"] as? [String: Any]
                let title = tags?["title"] as? String ?? "Untitled chapter"
                return "\(self?.chapterTimestamp(start) ?? "00:00") — \(title)"
            }

            DispatchQueue.main.async {
                if let failureMessage {
                    self?.appendLog("Warning: \(failureMessage)\n")
                }
                if chapterLines.isEmpty {
                    self?.appendLog("Warning: No chapters were found in the final MP4.\n")
                } else {
                    self?.appendLog("Embedded chapters verified: \(chapterLines.count) chapters\n")
                    self?.appendLog("\(chapterLines.joined(separator: "\n"))\n")
                }
            }
        }
    }

    private func chapterTimestamp(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
