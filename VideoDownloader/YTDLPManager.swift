//
//  YTDLPManager.swift
//  VideoDownloader
//

import Foundation

final class YTDLPManager {
    enum UpdateChannel: String, CaseIterable {
        case stable
        case nightly

        var displayName: String {
            rawValue.capitalized
        }
    }

    enum ManagerError: LocalizedError {
        case missingBundledExecutable
        case applicationSupportUnavailable
        case directoryCreation(Error)
        case installation(Error)
        case permission(Error)
        case launch(Error)
        case invalidExecutable(String)
        case updateFailed(status: Int32, message: String)
        case packageManaged(String)
        case noInternet(String)
        case backupRestoration(Error)

        var errorDescription: String? {
            switch self {
            case .missingBundledExecutable:
                return "The bundled yt-dlp executable is missing from the application resources."
            case .applicationSupportUnavailable:
                return "The Application Support directory could not be located."
            case .directoryCreation(let error):
                return "Could not create the yt-dlp support directory: \(error.localizedDescription)"
            case .installation(let error):
                return "Could not install the bundled yt-dlp executable: \(error.localizedDescription)"
            case .permission(let error):
                return "Could not make yt-dlp executable: \(error.localizedDescription)"
            case .launch(let error):
                return "Could not launch yt-dlp: \(error.localizedDescription)"
            case .invalidExecutable(let message):
                return "yt-dlp did not pass verification. \(message)"
            case .updateFailed(let status, let message):
                return "yt-dlp update failed with exit code \(status). \(message)"
            case .packageManaged(let message):
                return "yt-dlp cannot self-update because it reports being managed by a package manager. \(message)"
            case .noInternet(let message):
                return "yt-dlp could not check for updates. Check your internet connection. \(message)"
            case .backupRestoration(let error):
                return "The yt-dlp backup could not be restored: \(error.localizedDescription)"
            }
        }
    }

    struct CommandResult {
        let status: Int32
        let output: String
    }

    static let shared = YTDLPManager()

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let workQueue = DispatchQueue(label: "com.videodownloader.ytdlp-manager", qos: .utility)
    private let stateLock = NSLock()
    private var updateInProgress = false

    private let lastCheckKey = "YTDLPManager.lastSuccessfulUpdateCheck"
    private let channelKey = "YTDLPManager.updateChannel"
    private let checkInterval: TimeInterval = 24 * 60 * 60

    init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.defaults = defaults
    }

    var selectedChannel: UpdateChannel {
        get {
            guard let value = defaults.string(forKey: channelKey),
                  let channel = UpdateChannel(rawValue: value) else {
                return .stable
            }
            return channel
        }
        set {
            defaults.set(newValue.rawValue, forKey: channelKey)
        }
    }

    var bundledExecutableURL: URL? {
        Bundle.main.url(forResource: "yt-dlp", withExtension: nil)
    }

    var writableExecutableURL: URL? {
        guard let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return supportURL
            .appendingPathComponent("VideoDownloader", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("yt-dlp", isDirectory: false)
    }

    private var backupURL: URL? {
        writableExecutableURL?.deletingLastPathComponent().appendingPathComponent("yt-dlp.backup")
    }

    func shouldPerformAutomaticCheck(now: Date = Date()) -> Bool {
        guard let lastCheck = defaults.object(forKey: lastCheckKey) as? Date else {
            return true
        }
        return now.timeIntervalSince(lastCheck) >= checkInterval
    }

    /// Installs or repairs the writable copy, then returns the URL downloads must use.
    func executableURL(log: @escaping (String) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        workQueue.async {
            do {
                let executableURL = try self.ensureInstalled(log: log)
                self.finishOnMain(.success(executableURL), completion: completion)
            } catch {
                self.finishOnMain(.failure(error), completion: completion)
            }
        }
    }

    /// Launch-time checks are throttled; manual checks always run.
    func checkForUpdates(
        manual: Bool,
        log: @escaping (String) -> Void,
        stateChanged: @escaping (Bool) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard manual || shouldPerformAutomaticCheck() else {
            logOnMain(log, "Automatic yt-dlp update check skipped (checked successfully within the last 24 hours).\n")
            workQueue.async {
                do {
                    let executableURL = try self.ensureInstalled(log: log)
                    let version = try self.verifiedVersion(at: executableURL)
                    self.finishOnMain(.success(version), completion: completion)
                } catch {
                    self.finishOnMain(.failure(error), completion: completion)
                }
            }
            return
        }

        stateLock.lock()
        guard !updateInProgress else {
            stateLock.unlock()
            logOnMain(log, "A yt-dlp update is already in progress.\n")
            return
        }
        updateInProgress = true
        stateLock.unlock()

        DispatchQueue.main.async { stateChanged(true) }

        workQueue.async {
            let result: Result<String, Error>
            do {
                result = .success(try self.performUpdate(log: log))
            } catch {
                result = .failure(error)
            }

            self.stateLock.lock()
            self.updateInProgress = false
            self.stateLock.unlock()

            DispatchQueue.main.async {
                stateChanged(false)
                completion(result)
            }
        }
    }

    private func ensureInstalled(log: @escaping (String) -> Void) throws -> URL {
        guard let executableURL = writableExecutableURL else {
            throw ManagerError.applicationSupportUnavailable
        }

        do {
            try fileManager.createDirectory(
                at: executableURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ManagerError.directoryCreation(error)
        }

        if fileManager.fileExists(atPath: executableURL.path) {
            do {
                try setExecutablePermissions(at: executableURL)
                _ = try verifiedVersion(at: executableURL)
                return executableURL
            } catch {
                logOnMain(log, "The installed yt-dlp copy is missing, damaged, or cannot execute. Reinstalling the bundled fallback.\n")
            }
        }

        try installBundledFallback(at: executableURL, preserveExisting: true, log: log)
        let version = try verifiedVersion(at: executableURL)
        logOnMain(log, "Installed bundled yt-dlp fallback (version \(version)) at \(executableURL.path).\n")
        return executableURL
    }

    private func installBundledFallback(at destinationURL: URL, preserveExisting: Bool, log: @escaping (String) -> Void) throws {
        guard let bundledURL = bundledExecutableURL,
              fileManager.fileExists(atPath: bundledURL.path) else {
            throw ManagerError.missingBundledExecutable
        }

        if preserveExisting && fileManager.fileExists(atPath: destinationURL.path) {
            try createBackup(of: destinationURL)
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: bundledURL, to: destinationURL)
        } catch {
            throw ManagerError.installation(error)
        }

        do {
            try setExecutablePermissions(at: destinationURL)
        } catch {
            throw ManagerError.permission(error)
        }
        logOnMain(log, "Copied bundled yt-dlp into writable Application Support storage.\n")
    }

    private func performUpdate(log: @escaping (String) -> Void) throws -> String {
        let executableURL = try ensureInstalled(log: log)
        let oldVersion = try verifiedVersion(at: executableURL)
        try createBackup(of: executableURL)

        let channel = selectedChannel
        let arguments = channel == .stable ? ["-U"] : ["--update-to", "nightly"]
        logOnMain(log, "Checking for yt-dlp updates on the \(channel.displayName) channel (installed: \(oldVersion))...\n")

        let updateResult: CommandResult
        do {
            updateResult = try run(executableURL: executableURL, arguments: arguments, streamOutput: log)
        } catch {
            throw ManagerError.launch(error)
        }

        guard updateResult.status == 0 else {
            try restoreBackupAfterFailure(log: log)
            throw classifiedUpdateError(status: updateResult.status, output: updateResult.output)
        }

        do {
            let version = try verifiedVersion(at: executableURL)
            defaults.set(Date(), forKey: lastCheckKey)
            logOnMain(log, "yt-dlp update verified successfully. Installed version: \(version)\n")
            return version
        } catch {
            try restoreBackupAfterFailure(log: log)
            throw ManagerError.invalidExecutable("The updated file was unusable; the previous version was restored.")
        }
    }

    private func verifiedVersion(at executableURL: URL) throws -> String {
        guard fileManager.fileExists(atPath: executableURL.path),
              fileManager.isExecutableFile(atPath: executableURL.path) else {
            throw ManagerError.invalidExecutable("The executable is missing or lacks execute permission.")
        }

        let result: CommandResult
        do {
            result = try run(executableURL: executableURL, arguments: ["--version"], streamOutput: nil)
        } catch {
            throw ManagerError.launch(error)
        }

        let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.status == 0, !version.isEmpty else {
            throw ManagerError.invalidExecutable("Version check exited with code \(result.status) and returned no valid version.")
        }
        return version.components(separatedBy: .newlines).first ?? version
    }

    private func createBackup(of executableURL: URL) throws {
        guard let backupURL else { throw ManagerError.applicationSupportUnavailable }
        do {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: executableURL, to: backupURL)
            try setExecutablePermissions(at: backupURL)
        } catch {
            throw ManagerError.installation(error)
        }
    }

    private func restoreBackupAfterFailure(log: @escaping (String) -> Void) throws {
        guard let executableURL = writableExecutableURL, let backupURL,
              fileManager.fileExists(atPath: backupURL.path) else {
            logOnMain(log, "No yt-dlp backup was available for recovery; reinstalling the bundled fallback.\n")
            guard let destination = writableExecutableURL else { throw ManagerError.applicationSupportUnavailable }
            try installBundledFallback(at: destination, preserveExisting: false, log: log)
            _ = try verifiedVersion(at: destination)
            return
        }

        do {
            if fileManager.fileExists(atPath: executableURL.path) {
                try fileManager.removeItem(at: executableURL)
            }
            try fileManager.copyItem(at: backupURL, to: executableURL)
            try setExecutablePermissions(at: executableURL)
            let restoredVersion = try verifiedVersion(at: executableURL)
            logOnMain(log, "Restored yt-dlp.backup successfully (version \(restoredVersion)).\n")
        } catch {
            throw ManagerError.backupRestoration(error)
        }
    }

    private func setExecutablePermissions(at url: URL) throws {
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func run(
        executableURL: URL,
        arguments: [String],
        streamOutput: ((String) -> Void)?
    ) throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let outputLock = NSLock()
        var collectedOutput = ""

        func capture(_ data: Data) {
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            outputLock.lock()
            collectedOutput += text
            outputLock.unlock()
            if let streamOutput {
                logOnMain(streamOutput, text)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { capture($0.availableData) }
        errorPipe.fileHandleForReading.readabilityHandler = { capture($0.availableData) }
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }

        process.waitUntilExit()
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        capture(outputPipe.fileHandleForReading.readDataToEndOfFile())
        capture(errorPipe.fileHandleForReading.readDataToEndOfFile())

        outputLock.lock()
        let output = collectedOutput
        outputLock.unlock()
        return CommandResult(status: process.terminationStatus, output: output)
    }

    private func classifiedUpdateError(status: Int32, output: String) -> Error {
        let lowercased = output.lowercased()
        if lowercased.contains("package manager") || lowercased.contains("installed yt-dlp with") {
            return ManagerError.packageManaged(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if lowercased.contains("network") || lowercased.contains("internet") ||
            lowercased.contains("timed out") || lowercased.contains("name or service not known") ||
            lowercased.contains("could not resolve") || lowercased.contains("connection") {
            return ManagerError.noInternet(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return ManagerError.updateFailed(
            status: status,
            message: output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func logOnMain(_ log: @escaping (String) -> Void, _ message: String) {
        DispatchQueue.main.async { log(message) }
    }

    private func finishOnMain<T>(_ result: Result<T, Error>, completion: @escaping (Result<T, Error>) -> Void) {
        DispatchQueue.main.async { completion(result) }
    }
}
