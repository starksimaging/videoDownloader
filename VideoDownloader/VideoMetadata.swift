import Foundation

struct VideoMetadata {
    struct Chapter { let start, end: Double?; let title: String }
    struct Thumbnail { let url: String; let width, height: Int? }
    struct Format {
        enum Kind: String { case combined = "Video + Audio", video = "Video Only", audio = "Audio Only", storyboard = "Storyboard" }
        let id, extensionName, videoCodec, audioCodec, language, protocolName, dynamicRange: String?
        let width, height: Int?
        let fps, bitrate, size, sampleRate: Double?
        let audioChannels: Int?
        let kind: Kind

        var resolution: String {
            if let width, let height { return "\(width)×\(height)" }
            return kind == .audio ? "Audio" : "—"
        }
    }

    let id, title, uploader, uploaderID, channel, channelID, webpageURL: String?
    let duration: Double?
    let description, uploadDate, releaseDate, liveStatus, language: String?
    let viewCount, likeCount, commentCount, subscriberCount: Int64?
    let averageRating: Double?
    let ageLimit: Int?
    let chapters: [Chapter]
    let formats: [Format]
    let thumbnails: [Thumbnail]
    let subtitles, automaticCaptions: [String]
    let categories, tags: [String]
    let extractor, extractorKey, extensionName, selectedFormat, videoCodec, audioCodec: String?
    let width, height: Int?
    let fps, bitrate, fileSize, sampleRate: Double?
    let audioChannels: Int?
    let rawJSON: Data

    init(json data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        func string(_ key: String) -> String? { root[key] as? String }
        func double(_ key: String) -> Double? { Self.double(root[key]) }
        func int(_ key: String) -> Int? { Self.int(root[key]) }
        func int64(_ key: String) -> Int64? { Self.int64(root[key]) }
        id = string("id"); title = string("title"); uploader = string("uploader"); uploaderID = string("uploader_id")
        channel = string("channel"); channelID = string("channel_id"); webpageURL = string("webpage_url") ?? string("original_url")
        duration = double("duration"); description = string("description"); uploadDate = string("upload_date")
        releaseDate = string("release_date"); liveStatus = string("live_status"); language = string("language")
        viewCount = int64("view_count"); likeCount = int64("like_count"); commentCount = int64("comment_count")
        subscriberCount = int64("channel_follower_count"); averageRating = double("average_rating"); ageLimit = int("age_limit")
        categories = root["categories"] as? [String] ?? []; tags = root["tags"] as? [String] ?? []
        subtitles = Self.languageKeys(root["subtitles"]); automaticCaptions = Self.languageKeys(root["automatic_captions"])
        chapters = (root["chapters"] as? [[String: Any]] ?? []).map {
            Chapter(start: Self.double($0["start_time"]), end: Self.double($0["end_time"]), title: $0["title"] as? String ?? "Untitled")
        }
        thumbnails = (root["thumbnails"] as? [[String: Any]] ?? []).compactMap {
            guard let url = $0["url"] as? String else { return nil }
            return Thumbnail(url: url, width: Self.int($0["width"]), height: Self.int($0["height"]))
        }
        formats = (root["formats"] as? [[String: Any]] ?? []).map(Self.parseFormat)
        extractor = string("extractor"); extractorKey = string("extractor_key"); extensionName = string("ext")
        selectedFormat = string("format"); videoCodec = string("vcodec"); audioCodec = string("acodec")
        width = int("width"); height = int("height"); fps = double("fps"); bitrate = double("tbr")
        fileSize = double("filesize") ?? double("filesize_approx"); sampleRate = double("asr"); audioChannels = int("audio_channels")
        rawJSON = data
    }

    var displayUploader: String? { channel ?? uploader }
    var maximumResolution: String? { formats.compactMap(\.height).max().map { "\($0)p" } }
    var resolutions: [String] { unique(formats.compactMap(\.height).sorted().map { "\($0)p" }) }
    var frameRates: [String] { unique(formats.compactMap(\.fps).sorted().map { "\(Self.number($0)) fps" }) }
    var videoCodecs: [String] { unique(formats.compactMap(\.videoCodec).filter { $0 != "none" }.map(Self.friendlyCodec)) }
    var audioCodecs: [String] { unique(formats.compactMap(\.audioCodec).filter { $0 != "none" }.map(Self.friendlyCodec)) }
    var containers: [String] { unique(formats.compactMap(\.extensionName)) }
    var dynamicRanges: [String] { unique(formats.compactMap(\.dynamicRange).filter { !$0.isEmpty && $0 != "SDR" }) }
    var audioLanguages: [String] { unique(formats.filter { $0.kind == .audio || $0.kind == .combined }.compactMap(\.language)) }
    var sampleRates: [String] { unique(formats.compactMap(\.sampleRate).sorted().map { "\(Self.number($0)) Hz" }) }
    var channelCounts: [String] { unique(formats.compactMap(\.audioChannels).sorted().map(String.init)) }
    var aspectRatio: String? {
        guard let width = formats.compactMap(\.width).max(), let height = formats.compactMap(\.height).max(), height > 0 else { return nil }
        let divisor = Self.gcd(width, height); return "\(width / divisor):\(height / divisor)"
    }

    private func unique(_ values: [String]) -> [String] { Array(NSOrderedSet(array: values)) as? [String] ?? values }
    nonisolated private static func languageKeys(_ value: Any?) -> [String] { ((value as? [String: Any])?.keys.sorted()) ?? [] }
    nonisolated private static func parseFormat(_ item: [String: Any]) -> Format {
        let vcodec = item["vcodec"] as? String
        let acodec = item["acodec"] as? String
        let protocolName = item["protocol"] as? String
        let kind: Format.Kind
        if (vcodec?.contains("images") == true) || protocolName == "mhtml" { kind = .storyboard }
        else if vcodec != nil && vcodec != "none" && acodec != nil && acodec != "none" { kind = .combined }
        else if vcodec != nil && vcodec != "none" { kind = .video }
        else { kind = .audio }
        return Format(id: item["format_id"] as? String, extensionName: item["ext"] as? String,
            videoCodec: vcodec, audioCodec: acodec, language: item["language"] as? String,
            protocolName: protocolName, dynamicRange: item["dynamic_range"] as? String,
            width: int(item["width"]), height: int(item["height"]), fps: double(item["fps"]),
            bitrate: double(item["tbr"]), size: double(item["filesize"]) ?? double(item["filesize_approx"]),
            sampleRate: double(item["asr"]), audioChannels: int(item["audio_channels"]), kind: kind)
    }
    nonisolated private static func double(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue ?? Double(value as? String ?? "") }
    nonisolated private static func int(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue ?? Int(value as? String ?? "") }
    nonisolated private static func int64(_ value: Any?) -> Int64? { (value as? NSNumber)?.int64Value ?? Int64(value as? String ?? "") }
    nonisolated static func number(_ value: Double) -> String { value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value) }
    nonisolated static func friendlyCodec(_ value: String) -> String {
        if value.hasPrefix("avc") { return "H.264 / AVC" }; if value.hasPrefix("vp9") { return "VP9" }
        if value.hasPrefix("av01") { return "AV1" }; if value.hasPrefix("opus") { return "Opus" }
        if value.hasPrefix("mp4a") { return "AAC" }; return value
    }
    nonisolated private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}
