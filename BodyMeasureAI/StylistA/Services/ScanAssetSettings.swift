//
//  ScanAssetSettings.swift
//  BodyMeasureAI
//
//  Per-install consent for retaining body-scan reference photos. Body imagery
//  is sensitive — we keep this opt-in and prompt explicitly on the first
//  scan so the user makes a deliberate choice. The prompt can be revisited
//  later from Settings.
//
//  Storage: UserDefaults. Two keys:
//    - hasPromptedForReferencePhotoConsent (Bool): true after the first
//      time we showed the prompt, so we don't re-prompt on every scan.
//    - referencePhotoConsentGranted (Bool): the user's actual choice.
//
//  Defaults to "not prompted, not granted" so the first scan triggers the
//  prompt and uploads no assets if the user declines or never sees it.
//

import Foundation

enum ScanAssetSettings {

    private static let promptedKey = "scanAsset.hasPromptedForReferencePhotoConsent"
    private static let grantedKey = "scanAsset.referencePhotoConsentGranted"

    /// Whether the consent prompt has been shown at least once. Used by the
    /// scan flow to decide whether to block on the prompt sheet.
    static var hasBeenPrompted: Bool {
        get { UserDefaults.standard.bool(forKey: promptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: promptedKey) }
    }

    /// Whether the user agreed to retain reference photos. Drives whether the
    /// upload pipeline encodes + uploads HEIC/mask assets after each scan.
    static var consentGranted: Bool {
        get { UserDefaults.standard.bool(forKey: grantedKey) }
        set { UserDefaults.standard.set(newValue, forKey: grantedKey) }
    }

    /// Apply the user's choice and remember that we asked. Idempotent.
    static func record(consent: Bool) {
        consentGranted = consent
        hasBeenPrompted = true
    }

    /// True when the next scan should pause to show the consent prompt.
    static var needsConsentPrompt: Bool {
        !hasBeenPrompted
    }
}
