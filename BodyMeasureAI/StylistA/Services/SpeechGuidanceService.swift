//
//  SpeechGuidanceService.swift
//  BodyMeasureAI
//
//  Spoken guidance during body capture. Wraps AVSpeechSynthesizer with a
//  dedup window so the same phrase isn't repeated on every frame.
//

import AVFoundation
import Foundation
import os

/// Thin wrapper around AVSpeechSynthesizer for scan guidance prompts.
/// Thread-safe for main-thread callers; the synthesizer handles its own queue.
@Observable
@MainActor
final class SpeechGuidanceService {

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
        // Re-assert the audio session each time in case it was deactivated
        // (e.g. interrupted by a call, or the AVCaptureSession changed state).
        configureAudioSessionIfNeeded()

        let now = Date()
        if !force, let last = lastSpoken[prompt],
           now.timeIntervalSince(last) < dedupWindow {
            return
        }
        lastSpoken[prompt] = now

        AppLog.capture.debug("speech: \(prompt.rawValue, privacy: .public)")

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

    /// TTS only — we don't record audio (AVCaptureSession is video-only), so
    /// `.playback` is correct. `.duckOthers` briefly lowers any background
    /// music while a guidance prompt plays. `.playback` also plays through
    /// the speaker regardless of the ringer/silent switch, which is what
    /// users expect from guided scan audio.
    private func configureAudioSessionIfNeeded() {
        guard !isConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            try session.setActive(true, options: [])
            isConfigured = true
        } catch {
            AppLog.capture.error("audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
