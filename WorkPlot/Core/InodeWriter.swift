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
    /// Rewrites and verifies an existing inode. Any write or validation failure
    /// restores the bytes that were present before the operation.
    static func writeVerifiedInPlace(
        _ data: Data,
        to path: String,
        validator: ((Data) -> Bool)? = nil
    ) throws {
        let url = URL(fileURLWithPath: path)
        let original: Data
        do {
            original = try Data(contentsOf: url)
        } catch {
            throw InodeWriterError(message: "Failed to snapshot original file: \(error.localizedDescription)")
        }

        do {
            try writeInPlace(data, to: path)
            let written = try Data(contentsOf: url)
            guard (validator ?? { $0 == data })(written) else {
                throw InodeWriterError(message: "Post-write verification failed")
            }
        } catch {
            let writeError = error
            do {
                try writeInPlace(original, to: path)
                guard try Data(contentsOf: url) == original else {
                    throw InodeWriterError(message: "Rollback verification failed")
                }
            } catch {
                throw InodeWriterError(
                    message: "\(writeError.localizedDescription); rollback failed: \(error.localizedDescription)"
                )
            }
            throw writeError
        }
    }

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
