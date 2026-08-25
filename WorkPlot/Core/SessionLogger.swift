import Foundation

/// In-memory ring buffer of session events shown in the Session Log viewer.
/// Every line is ALSO appended to a file in the app container - canvas fixes
/// demand a full reboot, and a RAM-only log dies exactly when it is needed.
final class SessionLogger {
    static let shared = SessionLogger()

    private var lines: [String] = []
    private let limit = 300
    private let queue = DispatchQueue(label: "com.workplot.sessionlogger")

    private let logFileURL: URL? = {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.log")
    }()

    private init() {
        log("session start")
    }

    func log(_ message: String) {
        queue.async {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm:ss"
            let stamped = "\(formatter.string(from: Date())) \(message)"
            self.lines.append(stamped)
            if self.lines.count > self.limit {
                self.lines.removeFirst(self.lines.count - self.limit)
            }
            // ponytail: plain sequential append; rotate by size only if the
            // file ever grows annoyingly large.
            guard let url = self.logFileURL else { return }
            let data = Data("\(stamped)\n".utf8)
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    var text: String {
        queue.sync { lines.joined(separator: "\n") }
    }

    func clear() {
        queue.async {
            self.lines.removeAll()
            if let url = self.logFileURL {
                try? Data().write(to: url)
            }
        }
    }
}
