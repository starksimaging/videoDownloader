//
//  TranscriptProcessor.swift
//  VideoDownloader
//

import Foundation

struct TranscriptProcessor {
    enum TranscriptError: LocalizedError {
        case unreadableSubtitle
        case emptyTranscript

        var errorDescription: String? {
            switch self {
            case .unreadableSubtitle: return "The downloaded subtitle file could not be read."
            case .emptyTranscript: return "The subtitle file did not contain readable transcript text."
            }
        }
    }

    nonisolated static func subtitleFiles(in folder: URL) -> Set<URL> {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return Set(urls.filter { $0.pathExtension.lowercased() == "vtt" })
    }

    nonisolated static func newlyCreatedSubtitleFiles(in folder: URL, excluding existing: Set<URL>) -> [URL] {
        subtitleFiles(in: folder)
            .subtracting(existing)
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    nonisolated static func bestSubtitle(from candidates: [URL], matching mediaURL: URL?) -> URL? {
        guard !candidates.isEmpty else { return nil }
        guard let mediaURL else { return candidates.first }
        let mediaBase = mediaURL.deletingPathExtension().lastPathComponent
        return candidates.first { $0.lastPathComponent.hasPrefix(mediaBase + ".") } ?? candidates.first
    }

    nonisolated static func createTranscript(from subtitleURL: URL, beside mediaURL: URL) throws -> URL {
        guard let data = FileManager.default.contents(atPath: subtitleURL.path),
              let vtt = String(data: data, encoding: .utf8) else {
            throw TranscriptError.unreadableSubtitle
        }
        let transcript = plainText(fromVTT: vtt)
        guard !transcript.isEmpty else { throw TranscriptError.emptyTranscript }

        let destination = mediaURL.deletingPathExtension().appendingPathExtension("txt")
        try transcript.write(to: destination, atomically: true, encoding: .utf8)
        return destination
    }

    nonisolated static func removeCreatedSubtitleFiles(_ urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "vtt" {
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated static func plainText(fromVTT vtt: String) -> String {
        let normalized = vtt.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var assembled = ""

        for block in blocks {
            let cueLines = block.components(separatedBy: "\n").compactMap(cleanCueLine)
            guard !cueLines.isEmpty else { continue }
            let cue = collapseRollingLines(cueLines)
            assembled = merge(assembled, with: cue)
        }

        let words = assembled.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return "" }

        var paragraphs: [String] = []
        var paragraph: [String] = []
        for word in words {
            paragraph.append(word)
            let endsSentence = word.last.map { ".!?".contains($0) } ?? false
            if (paragraph.count >= 70 && endsSentence) || paragraph.count >= 100 {
                paragraphs.append(paragraph.joined(separator: " "))
                paragraph.removeAll(keepingCapacity: true)
            }
        }
        if !paragraph.isEmpty { paragraphs.append(paragraph.joined(separator: " ")) }
        return paragraphs.joined(separator: "\n\n") + "\n"
    }

    nonisolated private static func cleanCueLine(_ rawLine: String) -> String? {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty,
              line != "WEBVTT",
              !line.hasPrefix("NOTE"),
              !line.hasPrefix("Kind:"),
              !line.hasPrefix("Language:"),
              !line.contains("-->") else { return nil }
        if Int(line) != nil { return nil }

        line = line.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        line = decodeEntities(line)
        line = line.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? nil : line
    }

    nonisolated private static func collapseRollingLines(_ lines: [String]) -> String {
        lines.reduce("") { current, line in merge(current, with: line) }
    }

    nonisolated private static func merge(_ existing: String, with incoming: String) -> String {
        guard !incoming.isEmpty else { return existing }
        guard !existing.isEmpty else { return incoming }
        if existing == incoming || existing.hasSuffix(incoming) { return existing }
        if incoming.hasPrefix(existing) { return incoming }

        let oldWords = existing.split(separator: " ").map(String.init)
        let newWords = incoming.split(separator: " ").map(String.init)
        let maximumOverlap = min(oldWords.count, newWords.count)
        if maximumOverlap > 0 {
            for count in stride(from: maximumOverlap, through: 1, by: -1) {
                if oldWords.suffix(count).elementsEqual(newWords.prefix(count)) {
                    return (oldWords + newWords.dropFirst(count)).joined(separator: " ")
                }
            }
        }
        return existing + " " + incoming
    }

    nonisolated private static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
