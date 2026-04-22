//
//  Gender.swift
//  BodyMeasureAI
//
//  User-selected gender. Raw values match the backend enum labels in Postgres
//  (lower snake_case), so `rawValue` is the exact wire string.
//

import Foundation

enum Gender: String, CaseIterable, Codable, Equatable {
    case male
    case female
    case nonBinary = "non_binary"

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .nonBinary: return "Non-binary"
        }
    }
}
