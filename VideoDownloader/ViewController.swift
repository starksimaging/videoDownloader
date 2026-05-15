//
//  ViewController.swift
//  VideoDownloader
//
//  Created by Jon Starks on 5/13/26.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var folderLabel: NSTextField!
    @IBOutlet var logTextView: NSTextView!

    var progressIndicator: NSProgressIndicator!
    var statusLabel: NSTextField!
    var revealButton: NSButton!
    var selectedFolder: URL?
    var lastDownloadedFileURL: URL?
    var downloadStartDate: Date?
    var currentProcess: Process?

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    func buildInterface() {
        view.subviews.removeAll()

        let urlField = NSTextField()
        urlField.placeholderString = "Video URL"
        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.isEditable = true
        urlField.isSelectable = true

        let chooseButton = NSButton(title: "Choose Folder", target: self, action: #selector(chooseFolderClicked(_:)))
        chooseButton.translatesAutoresizingMaskIntoConstraints = false
        chooseButton.bezelStyle = .rounded

        let pathLabel = NSTextField(labelWithString: "No folder selected")
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.textColor = .secondaryLabelColor

        let downloadButton = NSButton(title: "Download Video", target: self, action: #selector(downloadClicked(_:)))
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.bezelStyle = .rounded

        let clearButton = NSButton(title: "Clear Log", target: self, action: #selector(clearLogClicked(_:)))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .rounded

        let finderButton = NSButton(title: "Reveal in Finder", target: self, action: #selector(revealInFinderClicked(_:)))
        finderButton.translatesAutoresizingMaskIntoConstraints = false
        finderButton.bezelStyle = .rounded
        finderButton.isEnabled = false

        let progressBar = NSProgressIndicator()
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.doubleValue = 0

        let progressLabel = NSTextField(labelWithString: "Idle")
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.lineBreakMode = .byTruncatingMiddle
        progressLabel.textColor = .secondaryLabelColor

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .lineBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        view.addSubview(urlField)
        view.addSubview(chooseButton)
        view.addSubview(pathLabel)
        view.addSubview(downloadButton)
        view.addSubview(clearButton)
        view.addSubview(finderButton)
        view.addSubview(progressBar)
        view.addSubview(progressLabel)
        view.addSubview(scrollView)

        urlTextField = urlField
        folderLabel = pathLabel
        logTextView = textView
        progressIndicator = progressBar
        statusLabel = progressLabel
        revealButton = finderButton

        NSLayoutConstraint.activate([
            urlField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            urlField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            urlField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            chooseButton.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 12),
            chooseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            pathLabel.centerYAnchor.constraint(equalTo: chooseButton.centerYAnchor),
            pathLabel.leadingAnchor.constraint(equalTo: chooseButton.trailingAnchor, constant: 12),
            pathLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            downloadButton.topAnchor.constraint(equalTo: chooseButton.bottomAnchor, constant: 12),
            downloadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            clearButton.centerYAnchor.constraint(equalTo: downloadButton.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            finderButton.centerYAnchor.constraint(equalTo: downloadButton.centerYAnchor),
            finderButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -12),

            progressBar.topAnchor.constraint(equalTo: downloadButton.bottomAnchor, constant: 12),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 6),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])

        view.window?.makeFirstResponder(urlTextField)
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDLPPath)

        var arguments = [
            "--newline",
            "--print",
            "after_move:filepath",
            // Prefer QuickTime-compatible MP4 video with M4A audio.
            // Static ffmpeg and ffprobe builds are required so the app works on Macs without Homebrew.
            "--ffmpeg-location", resourcePath,
            "-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]",
            "--merge-output-format", "mp4",
            "-o", outputTemplate,
            url
        ]

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
        let videoExtensions = ["mp4", "mkv", "webm", "mov", "m4v", "avi", "flv", "wmv"]
        return videoExtensions.contains(fileURL.pathExtension.lowercased())
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
