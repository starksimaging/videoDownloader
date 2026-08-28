//
//  YTDLPProgress.swift
//  VideoDownloader
//

import Foundation

struct YTDLPProgress: Equatable {
    static let linePrefix = "VDPROGRESS:"
    static let template = "download:VDPROGRESS:%(progress._percent_str)s|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s"

    let percent: Double?
    let downloadedBytes: Int64?
    let totalBytes: Int64?
    let estimatedTotalBytes: Int64?
    let bytesPerSecond: Double?
    let etaSeconds: Int?

    var effectiveTotalBytes: Int64? {
        totalBytes ?? estimatedTotalBytes
    }

    var usesEstimatedTotal: Bool {
        totalBytes == nil && estimatedTotalBytes != nil
    }

    var calculatedPercent: Double? {
        if let percent, percent.isFinite {
            return min(max(percent, 0), 100)
        }

        guard let downloadedBytes,
              let total = effectiveTotalBytes,
              total > 0 else { return nil }
        let result = Double(downloadedBytes) / Double(total) * 100
        return result.isFinite ? min(max(result, 0), 100) : nil
    }
}

func parseYTDLPProgressLine(_ line: String) -> YTDLPProgress? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix(YTDLPProgress.linePrefix) else { return nil }

    let payload = String(trimmed.dropFirst(YTDLPProgress.linePrefix.count))
    let fields = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    guard fields.count >= 6 else { return nil }

    return YTDLPProgress(
        percent: numericDouble(fields[0].replacingOccurrences(of: "%", with: "")),
        downloadedBytes: numericInt64(fields[1]),
        totalBytes: numericInt64(fields[2]),
        estimatedTotalBytes: numericInt64(fields[3]),
        bytesPerSecond: numericDouble(fields[4]),
        etaSeconds: numericDouble(fields[5]).map { Int($0) }
    )
}

private func numericDouble(_ value: String) -> Double? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          !["na", "n/a", "none", "null"].contains(trimmed.lowercased()),
          let number = Double(trimmed),
          number.isFinite else { return nil }
    return number
}

private func numericInt64(_ value: String) -> Int64? {
    guard let number = numericDouble(value),
          number >= 0,
          number <= Double(Int64.max) else { return nil }
    return Int64(number)
}

final class NewlineRecordBuffer {
    private var pending = ""
    private let lock = NSLock()

    func append(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pending += String(decoding: data, as: UTF8.self)
        var records = pending.components(separatedBy: "\n")
        pending = records.removeLast()
        return records.map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
    }

    func finish() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard !pending.isEmpty else { return nil }
        defer { pending = "" }
        return pending.hasSuffix("\r") ? String(pending.dropLast()) : pending
    }
}
