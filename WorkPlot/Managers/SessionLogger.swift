import Foundation

/// In-memory ring buffer of session events shown in the Session Log viewer.
final class SessionLogger {
    static let shared = SessionLogger()

    private var lines: [String] = []
    private let limit = 300
    private let queue = DispatchQueue(label: "com.workplot.sessionlogger")

    private init() {
        log("session start")
    }

    func log(_ message: String) {
        queue.async {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm:ss"
            self.lines.append("\(formatter.string(from: Date())) \(message)")
            if self.lines.count > self.limit {
                self.lines.removeFirst(self.lines.count - self.limit)
            }
        }
    }

    var text: String {
        queue.sync { lines.joined(separator: "\n") }
    }

    func clear() {
        queue.async { self.lines.removeAll() }
    }
}
