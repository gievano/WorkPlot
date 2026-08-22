//
//  FileSqliteViewerSheet.swift
//  WorkPlot
//
//  Read-only SQLite browser built on the system libsqlite3 (import SQLite3).
//  The database is copied to tmp before opening so sqlite never touches the
//  live inode after the bad_query lease has been released.
//

import SQLite3
import SwiftUI

struct FileSqliteViewerSheet: View {
    let entry: FileEntry

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var tables: [String]?
    @State private var loadError: String?

    var body: some View {
        NavigationView {
            Group {
                if let loadError {
                    ContentUnavailableCompatView(
                        icon: "exclamationmark.triangle",
                        message: loadError
                    )
                } else if let tables {
                    List {
                        Section(header: Text(L10n.shared.tr("sqlite.tables"))) {
                            ForEach(tables, id: \.self) { table in
                                NavigationLink(table) {
                                    SqliteTableRowsView(entry: entry, table: table)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .workPlotScrollBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.shared.tr("common.done")) { dismiss() }
                }
            }
            .alert(
                loadErrorTitle,
                isPresented: Binding(
                    get: { loadError != nil },
                    set: { if !$0 { loadError = nil } }
                )
            ) {
                Button(L10n.shared.tr("common.done"), role: .cancel) {}
            } message: {
                Text(loadError ?? "")
            }
        }
        .task { load() }
    }

    /// sqlite.queryFail carries the detail via %@, so it doubles as the title.
    private var loadErrorTitle: String {
        String(format: L10n.shared.tr("sqlite.queryFail"), "")
    }

    private func load() {
        let path = entry.path
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let names = try SQLiteDatabase.tableNames(ofDatabaseAt: path)
                DispatchQueue.main.async { self.tables = names }
            } catch {
                DispatchQueue.main.async {
                    self.loadError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Table rows

private struct SqliteTableRowsView: View {
    let entry: FileEntry
    let table: String

    @ObservedObject private var l10n = L10n.shared

    @State private var result: QueryResult?
    @State private var queryError: String?

    struct QueryResult {
        let columns: [String]
        let rows: [[String]]
    }

    var body: some View {
        Group {
            if let queryError {
                ContentUnavailableCompatView(
                    icon: "exclamationmark.triangle",
                    message: queryError
                )
            } else if let result {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        Text(result.columns.joined(separator: " | "))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        ForEach(Array(result.rows.enumerated()), id: \.offset) { _, row in
                            Text(row.joined(separator: " | "))
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        Text(String(format: L10n.shared.tr("sqlite.rows"), result.rows.count))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(table)
        .navigationBarTitleDisplayMode(.inline)
        .workPlotScrollBackground()
        .alert(
            String(format: L10n.shared.tr("sqlite.queryFail"), ""),
            isPresented: Binding(
                get: { queryError != nil },
                set: { if !$0 { queryError = nil } }
            )
        ) {
            Button(L10n.shared.tr("common.done"), role: .cancel) {}
        } message: {
            Text(queryError ?? "")
        }
        .task { load() }
    }

    private func load() {
        let path = entry.path
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loaded = try SQLiteDatabase.rows(table: table, inDatabaseAt: path)
                DispatchQueue.main.async {
                    self.result = QueryResult(columns: loaded.columns, rows: loaded.rows)
                }
            } catch {
                DispatchQueue.main.async {
                    self.queryError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - SQLite access

enum SQLiteDatabase {
    struct SQLiteError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func tableNames(ofDatabaseAt sourcePath: String) throws -> [String] {
        try withReadOnlyCopy(of: sourcePath) { database in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(
                database,
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
                -1,
                &statement,
                nil
            ) == SQLITE_OK, let statement else {
                throw SQLiteError(String(cString: sqlite3_errmsg(database)))
            }
            defer { sqlite3_finalize(statement) }

            var names: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let cName = sqlite3_column_text(statement, 0) else { continue }
                names.append(String(cString: cName))
            }
            return names
        }
    }

    static func rows(table: String, inDatabaseAt sourcePath: String) throws -> (columns: [String], rows: [[String]]) {
        try withReadOnlyCopy(of: sourcePath) { database in
            // ponytail: %-escape for String(format:) and double the quotes so the
            // identifier stays inside its quotes; names come from sqlite_master anyway
            let safeName = table
                .replacingOccurrences(of: "%", with: "%%")
                .replacingOccurrences(of: "\"", with: "\"\"")
            let sql = String(format: L10n.shared.tr("sqlite.selectFirst"), safeName)

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                throw SQLiteError(String(cString: sqlite3_errmsg(database)))
            }
            defer { sqlite3_finalize(statement) }

            let columnCount = sqlite3_column_count(statement)
            var columns: [String] = []
            for index in 0..<columnCount {
                guard let cName = sqlite3_column_name(statement, index) else { continue }
                columns.append(String(cString: cName))
            }

            var rows: [[String]] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                var values: [String] = []
                values.reserveCapacity(columnCount)
                for index in 0..<columnCount {
                    if sqlite3_column_type(statement, index) == SQLITE_NULL {
                        values.append("NULL")
                    } else if let cValue = sqlite3_column_text(statement, index) {
                        values.append(String(cString: cValue))
                    } else {
                        values.append("NULL")
                    }
                }
                rows.append(values)
            }
            return (columns, rows)
        }
    }

    /// Copy the database into the app sandbox, open it READONLY, run body,
    /// then always close the handle and delete the copy.
    private static func withReadOnlyCopy<T>(
        of sourcePath: String,
        _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        let data = try FileBrowser.readData(at: sourcePath)
        let temporaryPath = NSTemporaryDirectory() + "workplot-sqlite-\(UUID().uuidString)"
        try data.write(to: URL(fileURLWithPath: temporaryPath), options: .atomic)
        defer { try? FileManager.default.removeItem(atPath: temporaryPath) }

        var handle: OpaquePointer?
        guard sqlite3_open_v2(temporaryPath, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database = handle else {
            let detail = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2 failed"
            sqlite3_close(handle)
            throw SQLiteError(detail)
        }
        defer { sqlite3_close(database) }
        return try body(database)
    }
}
