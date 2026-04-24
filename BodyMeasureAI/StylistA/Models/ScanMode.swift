//
//  ScanMode.swift
//  BodyMeasureAI
//
//  Whether the user is scanning with a helper or solo. Captured during the
//  pre-scan instructions flow and used by the capture screen to decide
//  between tap-to-capture and voice-guided self-capture.
//

import Foundation

enum ScanMode: String, CaseIterable, Codable, Equatable {
    case withFriend = "with_friend"
    case bySelf = "by_self"

    var displayName: String {
        switch self {
        case .withFriend: return "With a friend"
        case .bySelf: return "By myself"
        }
    }
}
