//
//  Log.swift
//  BodyMeasureAI
//
//  Centralized logging facade. All app logging goes through Log.xyz().
//  To swap to a 3rd-party logger (Datadog, Firebase Crashlytics, OSLog, etc.),
//  implement LogBackend and set: Log.backend = YourBackend()
//

import Foundation

// MARK: - LogBackend Protocol

protocol LogBackend {
    func log(
        _ level: Log.Level,
        _ message: String,
        context: [String: Any]?,
        file: String,
        function: String,
        line: Int
    )
}

// MARK: - Log Facade

enum Log {

    enum Level: String {
        case debug = "DEBUG"
        case info  = "INFO"
        case warn  = "WARN"
        case error = "ERROR"
    }

    /// Swap this to change where logs go. Default: structured console output.
    static var backend: LogBackend = ConsoleLogBackend()

    /// Minimum level to emit. Set to .info in production to suppress debug noise.
    static var minimumLevel: Level = .debug

    static func debug(
        _ message: String,
        context: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        emit(.debug, message, context: context, file: file, function: function, line: line)
    }

    static func info(
        _ message: String,
        context: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        emit(.info, message, context: context, file: file, function: function, line: line)
    }

    static func warn(
        _ message: String,
        context: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        emit(.warn, message, context: context, file: file, function: function, line: line)
    }

    static func error(
        _ message: String,
        context: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        emit(.error, message, context: context, file: file, function: function, line: line)
    }

    // MARK: - Private

    private static let levelOrder: [Level: Int] = [
        .debug: 0, .info: 1, .warn: 2, .error: 3
    ]

    private static func emit(
        _ level: Level,
        _ message: String,
        context: [String: Any]?,
        file: String,
        function: String,
        line: Int
    ) {
        guard (levelOrder[level] ?? 0) >= (levelOrder[minimumLevel] ?? 0) else { return }
        backend.log(level, message, context: context, file: file, function: function, line: line)
    }
}

// MARK: - Console Backend (Default)

struct ConsoleLogBackend: LogBackend {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    func log(
        _ level: Log.Level,
        _ message: String,
        context: [String: Any]?,
        file: String,
        function: String,
        line: Int
    ) {
        let timestamp = Self.formatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        var output = "[\(level.rawValue)] \(timestamp) | \(filename):\(line) \(function) | \(message)"
        if let ctx = context, !ctx.isEmpty {
            let pairs = ctx.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
            output += " | {\(pairs)}"
        }
        print(output)
    }
}
