//
//  AppLog.swift
//  BodyMeasureAI
//
//  Centralized os.Logger — appears in Xcode debug console and macOS Console.app.
//  Filter by subsystem `com.bodymeasureai` and per-category for noise control.
//

import Foundation
import os

enum AppLog {
    private static let subsystem = "com.bodymeasureai"

    /// Outbound HTTP — request/response, latency, status codes, errors.
    static let network = Logger(subsystem: subsystem, category: "network")

    /// High-level upload state changes (idempotency, queueing, retries).
    static let upload = Logger(subsystem: subsystem, category: "upload")

    /// Coordinator + view-stack lifecycle (navigation, scan reset, env).
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")

    /// Body capture pipeline (Vision pose, stability, capture trigger).
    static let capture = Logger(subsystem: subsystem, category: "capture")

    /// Garment + body classification work (timing, results, confidence).
    static let classification = Logger(subsystem: subsystem, category: "classification")
}
