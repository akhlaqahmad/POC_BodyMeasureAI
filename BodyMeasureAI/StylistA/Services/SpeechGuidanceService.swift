//
//  SpeechGuidanceService.swift
//  BodyMeasureAI
//
//  Spoken guidance during body capture. Wraps AVSpeechSynthesizer with a
//  dedup window so the same phrase isn't repeated on every frame.
//

import AVFoundation
import Foundation

/// Thin wrapper around AVSpeechSynthesizer for scan guidance prompts.
/// Thread-safe for main-thread callers; the synthesizer handles its own queue.
@MainActor
final class SpeechGuidanceService: ObservableObject {

    /// Named prompts keep call sites readable and make throttling behave per
    /// logical step rather than per utterance string.
    enum Prompt: String {
        case bodyDetected
        case holdStill
        case stepBack
        case countdown3
        case countdown2
        case countdown1
        case captured
        case turnForSide
        case sideDetected

        var text: String {
            switch self {
            case .bodyDetected: return "Stand in frame, arms slightly out"
            case .holdStill:    return "Good, hold still"
            case .stepBack:     return "Step back into frame"
            case .countdown3:   return "Capturing in 3"
            case .countdown2:   return "2"
            case .countdown1:   return "1"
            case .captured:     return "Captured"
            case .turnForSide:  return "Now turn 90 degrees to show your side"
            case .sideDetected: return "Good, hold still for the side scan"
            }
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    /// Minimum interval (seconds) between repeats of the same prompt.
    private let dedupWindow: TimeInterval = 3.0
    private var lastSpoken: [Prompt: Date] = [:]
    private var isConfigured = false

    init() {
        configureAudioSessionIfNeeded()
    }

    /// Speak the prompt if we haven't spoken it recently. `force` bypasses
    /// dedup (used for countdown numbers, which must always play).
    func speak(_ prompt: Prompt, force: Bool = false) {
        let now = Date()
        if !force, let last = lastSpoken[prompt],
           now.timeIntervalSince(last) < dedupWindow {
            return
        }
        lastSpoken[prompt] = now

        let utterance = AVSpeechUtterance(string: prompt.text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    /// Cancel any in-flight or queued utterances. Used on disappear.
    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Forget dedup history. Call when entering a fresh scan so "Good, hold
    /// still" plays on a re-scan even if it was spoken moments ago.
    func resetDedup() {
        lastSpoken.removeAll()
    }

    /// TTS needs to coexist with an active video session. `.playAndRecord`
    /// with `.defaultToSpeaker` routes synthesised speech through the speaker
    /// even while the mic-capable session is live. `.mixWithOthers` lets
    /// background audio (e.g. a user's music) continue.
    private func configureAudioSessionIfNeeded() {
        guard !isConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth]
            )
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
            isConfigured = true
        } catch {
            // Non-fatal: speech will still try to play through the default
            // route. Log but do not throw.
        }
    }
}
