//
//  InodeWriter.swift
//  WorkPlot
//
//  Inode-preserving file rewrite shared by every bad_query write path so
//  ownership, flags and xattrs survive an edit.
//

import Foundation

struct InodeWriterError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum InodeWriter {
    /// Rewrites the existing inode so ownership, flags and xattrs survive.
    static func writeInPlace(_ data: Data, to path: String) throws {
        func errnoMessage(_ context: String) -> String {
            "\(context) (errno=\(errno): \(String(cString: strerror(errno))))"
        }

        let fd = open(path, O_WRONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            throw InodeWriterError(message: errnoMessage("Failed to open file"))
        }
        defer { close(fd) }

        guard ftruncate(fd, 0) == 0, lseek(fd, 0, SEEK_SET) == 0 else {
            throw InodeWriterError(message: errnoMessage("Failed to reset file contents"))
        }

        var written = 0
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            while written < data.count {
                let n = write(fd, raw.baseAddress! + written, data.count - written)
                if n < 0 && errno == EINTR { continue }
                if n <= 0 { break }
                written += n
            }
        }
        guard written == data.count, fsync(fd) == 0 else {
            throw InodeWriterError(message: errnoMessage("Failed to write file"))
        }
    }
}
