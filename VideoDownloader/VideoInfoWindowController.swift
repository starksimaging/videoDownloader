import Cocoa

final class VideoInfoWindowController: NSWindowController {
    private let infoController = VideoInfoViewController()
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Video Info"; window.contentMinSize = NSSize(width: 700, height: 500); window.center()
        super.init(window: window); window.contentViewController = infoController
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func display(_ metadata: VideoMetadata) { infoController.display(metadata); showWindow(nil); window?.makeKeyAndOrderFront(nil) }
}

final class VideoInfoViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var metadata: VideoMetadata?
    private var filteredFormats: [VideoMetadata.Format] = []
    private let overviewStack = NSStackView()
    private let chapterTable = NSTableView()
    private let formatsTable = NSTableView()
    private let rawTextView = NSTextView()
    private let filter = NSSegmentedControl(labels: ["All", "Video", "Audio", "Storyboards"], trackingMode: .selectOne, target: nil, action: nil)

    override func loadView() {
        view = NSView(); view.translatesAutoresizingMaskIntoConstraints = false
        let tabs = NSTabView(); tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.addTabViewItem(tab(title: "Overview", view: makeOverview()))
        tabs.addTabViewItem(tab(title: "Formats", view: makeFormats()))
        tabs.addTabViewItem(tab(title: "Raw Metadata", view: makeRaw()))
        let copy = NSButton(title: "Copy Video Info", target: self, action: #selector(copySummary)); copy.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabs); view.addSubview(copy)
        NSLayoutConstraint.activate([copy.topAnchor.constraint(equalTo: view.topAnchor, constant: 12), copy.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16), tabs.topAnchor.constraint(equalTo: copy.bottomAnchor, constant: 8), tabs.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12), tabs.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), tabs.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)])
    }

    func display(_ metadata: VideoMetadata) {
        _ = view; self.metadata = metadata; filteredFormats = metadata.formats
        overviewStack.arrangedSubviews.forEach { overviewStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        addSection("Basic Information", rows: [("Title", metadata.title), ("Channel / Uploader", metadata.displayUploader), ("Channel ID", metadata.channelID ?? metadata.uploaderID), ("Video ID", metadata.id), ("URL", metadata.webpageURL), ("Duration", Self.duration(metadata.duration)), ("Upload Date", Self.date(metadata.uploadDate)), ("Release Date", Self.date(metadata.releaseDate)), ("Live Status", metadata.liveStatus)])
        addDescription(metadata.description)
        addChapters(metadata.chapters)
        addSection("Video Information", rows: [("Maximum Resolution", metadata.maximumResolution), ("Available Resolutions", metadata.resolutions.joined(separator: ", ")), ("Frame Rates", metadata.frameRates.joined(separator: ", ")), ("Video Codecs", metadata.videoCodecs.joined(separator: ", ")), ("HDR / Dynamic Range", metadata.dynamicRanges.joined(separator: ", ")), ("Aspect Ratio", metadata.aspectRatio), ("Containers", metadata.containers.joined(separator: ", "))])
        addSection("Audio", rows: [("Original Audio", metadata.language), ("Available Languages", metadata.audioLanguages.joined(separator: ", ")), ("Audio Codecs", metadata.audioCodecs.joined(separator: ", ")), ("Sample Rates", metadata.sampleRates.joined(separator: ", ")), ("Channel Counts", metadata.channelCounts.joined(separator: ", "))])
        addSection("Subtitles / Captions", rows: [("Subtitles", metadata.subtitles.joined(separator: ", ")), ("Automatic Captions", metadata.automaticCaptions.joined(separator: ", "))])
        let thumb = metadata.thumbnails.last
        addSection("Thumbnail", rows: [("Resolution", thumb.flatMap { t in t.width.flatMap { w in t.height.map { "\(w)×\($0)" } } }), ("URL", thumb?.url)])
        let nf = NumberFormatter(); nf.numberStyle = .decimal
        func count(_ v: Int64?) -> String? { v.flatMap { nf.string(from: NSNumber(value: $0)) } }
        addSection("Statistics", rows: [("Views", count(metadata.viewCount)), ("Likes", count(metadata.likeCount)), ("Comments", count(metadata.commentCount)), ("Subscribers", count(metadata.subscriberCount)), ("Average Rating", metadata.averageRating.map { String($0) }), ("Age Limit", metadata.ageLimit.map { String($0) })])
        addSection("Categories / Tags", rows: [("Categories", metadata.categories.joined(separator: ", ")), ("Tags", metadata.tags.joined(separator: ", "))])
        addSection("Technical Details", rows: [("Extractor", metadata.extractor), ("Extractor Key", metadata.extractorKey), ("Selected Format", metadata.selectedFormat), ("Extension", metadata.extensionName), ("File Size Estimate", Self.bytes(metadata.fileSize)), ("Bitrate", metadata.bitrate.map { "\(VideoMetadata.number($0)) kbps" }), ("Video Codec", metadata.videoCodec), ("Audio Codec", metadata.audioCodec), ("Dimensions", metadata.width.flatMap { w in metadata.height.map { "\(w)×\($0)" } }), ("FPS", metadata.fps.map(VideoMetadata.number)), ("Sample Rate", metadata.sampleRate.map { "\(VideoMetadata.number($0)) Hz" }), ("Audio Channels", metadata.audioChannels.map(String.init))])
        rawTextView.string = (try? String(data: JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: metadata.rawJSON), options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)) ?? String(data: metadata.rawJSON, encoding: .utf8) ?? ""
        filter.selectedSegment = 0; formatsTable.reloadData()
    }

    private func makeOverview() -> NSView {
        overviewStack.orientation = .vertical; overviewStack.alignment = .leading; overviewStack.spacing = 18; overviewStack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 18, right: 18)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = overviewStack
        overviewStack.translatesAutoresizingMaskIntoConstraints = false; overviewStack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        return scroll
    }
    private func makeFormats() -> NSView {
        let container = NSView(); filter.target = self; filter.action = #selector(filterChanged); filter.selectedSegment = 0; filter.translatesAutoresizingMaskIntoConstraints = false
        let columns = [("id","ID",70.0),("kind","Type",105.0),("resolution","Resolution",100.0),("fps","FPS",55.0),("vcodec","Video Codec",115.0),("acodec","Audio Codec",105.0),("ext","Container",80.0),("bitrate","Bitrate",75.0),("language","Language",90.0),("size","Approx Size",100.0)]
        for (id, title, width) in columns { let c = NSTableColumn(identifier: .init(id)); c.title = title; c.width = width; formatsTable.addTableColumn(c) }
        formatsTable.dataSource = self; formatsTable.delegate = self; formatsTable.usesAlternatingRowBackgroundColors = true
        let scroll = NSScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true; scroll.documentView = formatsTable
        container.addSubview(filter); container.addSubview(scroll)
        NSLayoutConstraint.activate([filter.topAnchor.constraint(equalTo: container.topAnchor, constant: 10), filter.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10), scroll.topAnchor.constraint(equalTo: filter.bottomAnchor, constant: 10), scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor)])
        return container
    }
    private func makeRaw() -> NSView { rawTextView.isEditable = false; rawTextView.isSelectable = true; rawTextView.isRichText = false; rawTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular); let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true; scroll.documentView = rawTextView; return scroll }
    private func tab(title: String, view: NSView) -> NSTabViewItem { let item = NSTabViewItem(); item.label = title; item.view = view; return item }
    private func addSection(_ title: String, rows: [(String, String?)]) {
        let valid = rows.filter { !($0.1?.isEmpty ?? true) }; guard !valid.isEmpty else { return }
        let header = NSTextField(labelWithString: title); header.font = .systemFont(ofSize: 18, weight: .semibold); overviewStack.addArrangedSubview(header)
        for (label, value) in valid { let field = NSTextField(wrappingLabelWithString: "\(label)\n\(value!)"); field.isSelectable = true; field.font = .systemFont(ofSize: 13); field.translatesAutoresizingMaskIntoConstraints = false; field.widthAnchor.constraint(equalTo: overviewStack.widthAnchor, constant: -36).isActive = true; overviewStack.addArrangedSubview(field) }
    }
    private func addDescription(_ value: String?) { guard let value, !value.isEmpty else { return }; let title = NSTextField(labelWithString: "Description"); title.font = .systemFont(ofSize: 18, weight: .semibold); overviewStack.addArrangedSubview(title); let text = NSTextView(); text.string = value; text.isEditable = false; text.isSelectable = true; text.font = .systemFont(ofSize: 13); let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = text; scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.heightAnchor.constraint(equalToConstant: 180).isActive = true; scroll.widthAnchor.constraint(equalTo: overviewStack.widthAnchor, constant: -36).isActive = true; overviewStack.addArrangedSubview(scroll) }
    private func addChapters(_ chapters: [VideoMetadata.Chapter]) { let title = NSTextField(labelWithString: "Chapters"); title.font = .systemFont(ofSize: 18, weight: .semibold); overviewStack.addArrangedSubview(title); if chapters.isEmpty { overviewStack.addArrangedSubview(NSTextField(labelWithString: "No chapters available.")); return }; if chapterTable.tableColumns.isEmpty { for (id, title, width) in [("start","Start",80.0),("end","End",80.0),("title","Chapter",500.0)] { let c = NSTableColumn(identifier: .init(id)); c.title = title; c.width = width; chapterTable.addTableColumn(c) }; chapterTable.dataSource = self; chapterTable.delegate = self }; let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = chapterTable; scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.heightAnchor.constraint(equalToConstant: min(240, CGFloat(chapters.count * 24 + 28))).isActive = true; scroll.widthAnchor.constraint(equalTo: overviewStack.widthAnchor, constant: -36).isActive = true; overviewStack.addArrangedSubview(scroll); chapterTable.reloadData() }
    func numberOfRows(in tableView: NSTableView) -> Int { tableView === formatsTable ? filteredFormats.count : (metadata?.chapters.count ?? 0) }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { let id = tableColumn?.identifier.rawValue ?? ""; let value: String; if tableView === chapterTable { let c = metadata!.chapters[row]; value = id == "start" ? Self.duration(c.start) ?? "—" : id == "end" ? Self.duration(c.end) ?? "—" : c.title } else { let f = filteredFormats[row]; switch id { case "id": value=f.id ?? "—"; case "kind": value=f.kind.rawValue; case "resolution": value=f.resolution; case "fps": value=f.fps.map(VideoMetadata.number) ?? "—"; case "vcodec": value=f.videoCodec.map(VideoMetadata.friendlyCodec) ?? "—"; case "acodec": value=f.audioCodec.map(VideoMetadata.friendlyCodec) ?? "—"; case "ext": value=f.extensionName ?? "—"; case "bitrate": value=f.bitrate.map { "\(VideoMetadata.number($0))k" } ?? "—"; case "language": value=f.language ?? "—"; default: value=Self.bytes(f.size) ?? "—" } }; let cell = NSTextField(labelWithString: value); cell.lineBreakMode = .byTruncatingTail; cell.toolTip = value; return cell }
    @objc private func filterChanged() { guard let metadata else { return }; switch filter.selectedSegment { case 1: filteredFormats = metadata.formats.filter { $0.kind == .video || $0.kind == .combined }; case 2: filteredFormats = metadata.formats.filter { $0.kind == .audio || $0.kind == .combined }; case 3: filteredFormats = metadata.formats.filter { $0.kind == .storyboard }; default: filteredFormats = metadata.formats }; formatsTable.reloadData() }
    @objc private func copySummary() { guard let m = metadata else { return }; let values: [(String, String?)] = [("Title",m.title),("Channel",m.displayUploader),("Duration",Self.duration(m.duration)),("Upload Date",Self.date(m.uploadDate)),("URL",m.webpageURL),("Video ID",m.id),("Maximum Resolution",m.maximumResolution),("Audio Languages",m.audioLanguages.isEmpty ? nil : m.audioLanguages.joined(separator: ", "))]; let lines = values.compactMap { label, value in value.map { "\(label): \($0)" } }; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string) }
    private static func duration(_ seconds: Double?) -> String? { guard let seconds else { return nil }; let total = Int(seconds.rounded()); return total >= 3600 ? String(format: "%d:%02d:%02d", total/3600, total/60%60, total%60) : String(format: "%02d:%02d", total/60, total%60) }
    private static func date(_ value: String?) -> String? { guard let value, value.count == 8 else { return value }; return "\(value.prefix(4))-\(value.dropFirst(4).prefix(2))-\(value.suffix(2))" }
    private static func bytes(_ value: Double?) -> String? { guard let value else { return nil }; let f = ByteCountFormatter(); f.countStyle = .file; return f.string(fromByteCount: Int64(value)) }
}
