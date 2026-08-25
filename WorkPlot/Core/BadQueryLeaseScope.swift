//
//  BadQueryLeaseScope.swift
//  WorkPlot
//
//  Standardizes the short-lived lease pattern for direct bad_query paths:
//  acquire -> run one operation -> invalidate, even when the body throws.
//

import Foundation

enum BadQueryLeaseError: LocalizedError {
    case acquisitionFailed(String?)

    var errorDescription: String? {
        switch self {
        case .acquisitionFailed(let detail):
            String(
                format: "bad_query lease failed: %@",
                detail ?? "unknown error"
            )
        }
    }
}

enum BadQueryLeaseScope {
    /// Acquires a short-lived sandbox extension for exactly one operation and
    /// guarantees release when `body` returns or throws, so no token leaks
    /// across operations. Long-lived usage stays in GestaltAccess, which
    /// revalidates its lease on every connect().
    static func withLease<T>(forPath path: String, _ body: () throws -> T) throws -> T {
        let handle = try BadQuery.consume(path: path)
        defer { handle.release() }
        return try body()
    }
}
