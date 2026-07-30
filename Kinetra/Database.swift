import Foundation
import SQLite3

/// Thin hand-written wrapper over the system libsqlite3 C API. No package dependencies.
final class SQLiteDatabase {

    enum DBError: Error, LocalizedError {
        case open(String)
        case prepare(String)
        case step(String)

        var errorDescription: String? {
            switch self {
            case .open(let m): return "Could not open database: \(m)"
            case .prepare(let m): return "Could not prepare statement: \(m)"
            case .step(let m): return "Could not run statement: \(m)"
            }
        }
    }

    private var handle: OpaquePointer?
    private let queue = DispatchQueue(label: "com.kinetra.sqlite")

    // MARK: - Lifecycle

    init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw DBError.open(message)
        }
        handle = db
        try? execute("PRAGMA journal_mode = WAL;")
        try? execute("PRAGMA foreign_keys = ON;")
    }

    deinit {
        if let handle { sqlite3_close(handle) }
    }

    private var lastMessage: String {
        guard let handle else { return "no handle" }
        return String(cString: sqlite3_errmsg(handle))
    }

    // MARK: - Raw helpers

    func execute(_ sql: String) throws {
        try queue.sync {
            var error: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(handle, sql, nil, nil, &error) != SQLITE_OK {
                let message = error.map { String(cString: $0) } ?? lastMessage
                sqlite3_free(error)
                throw DBError.step(message)
            }
        }
    }

    /// Values that can be bound to a statement.
    enum Value {
        case int(Int)
        case double(Double)
        case text(String)
        case null
    }

    @discardableResult
    func run(_ sql: String, _ values: [Value] = []) throws -> Int {
        try queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DBError.prepare(lastMessage)
            }
            defer { sqlite3_finalize(stmt) }
            bind(values, to: stmt)
            let code = sqlite3_step(stmt)
            guard code == SQLITE_DONE || code == SQLITE_ROW else {
                throw DBError.step(lastMessage)
            }
            return Int(sqlite3_changes(handle))
        }
    }

    /// Best-effort write: runs the statement and ignores a failure.
    func perform(_ sql: String, _ values: [Value] = []) {
        do { _ = try run(sql, values) } catch { return }
    }

    /// A single decoded row keyed by column name.
    struct Row {
        private let storage: [String: Any]
        init(_ storage: [String: Any]) { self.storage = storage }

        func int(_ key: String) -> Int? {
            if let v = storage[key] as? Int64 { return Int(v) }
            if let v = storage[key] as? Double { return Int(v) }
            return nil
        }
        func double(_ key: String) -> Double? {
            if let v = storage[key] as? Double { return v }
            if let v = storage[key] as? Int64 { return Double(v) }
            return nil
        }
        func string(_ key: String) -> String? { storage[key] as? String }
        func bool(_ key: String) -> Bool? { int(key).map { $0 != 0 } }
        func uuid(_ key: String) -> UUID? { string(key).flatMap { UUID(uuidString: $0) } }
    }

    func query(_ sql: String, _ values: [Value] = []) throws -> [Row] {
        try queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DBError.prepare(lastMessage)
            }
            defer { sqlite3_finalize(stmt) }
            bind(values, to: stmt)

            var rows: [Row] = []
            let columnCount = Int(sqlite3_column_count(stmt))
            while sqlite3_step(stmt) == SQLITE_ROW {
                var dict: [String: Any] = [:]
                for i in 0..<columnCount {
                    let idx = Int32(i)
                    guard let namePtr = sqlite3_column_name(stmt, idx) else { continue }
                    let name = String(cString: namePtr)
                    switch sqlite3_column_type(stmt, idx) {
                    case SQLITE_INTEGER: dict[name] = sqlite3_column_int64(stmt, idx)
                    case SQLITE_FLOAT: dict[name] = sqlite3_column_double(stmt, idx)
                    case SQLITE_TEXT:
                        if let c = sqlite3_column_text(stmt, idx) {
                            dict[name] = String(cString: c)
                        }
                    default: break
                    }
                }
                rows.append(Row(dict))
            }
            return rows
        }
    }

    private func bind(_ values: [Value], to stmt: OpaquePointer?) {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case .int(let v): sqlite3_bind_int64(stmt, index, Int64(v))
            case .double(let v): sqlite3_bind_double(stmt, index, v)
            case .text(let v): sqlite3_bind_text(stmt, index, v, -1, SQLITE_TRANSIENT)
            case .null: sqlite3_bind_null(stmt, index)
            }
        }
    }
}

/// `SQLITE_TRANSIENT` is a function pointer macro that Swift does not import.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
