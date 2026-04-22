//
//  KeepScreenAwakeModifier.swift
//  BodyMeasureAI
//
//  Prevents auto-lock while camera/scanning views are onscreen.
//

import SwiftUI
import UIKit

private struct KeepScreenAwakeModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { setIdleTimerDisabled(true) }
            .onDisappear { setIdleTimerDisabled(false) }
            .onChange(of: scenePhase) { _, newPhase in
                // Reassert when the scene returns to foreground; release when
                // it leaves, so a backgrounded app doesn't hold the flag.
                setIdleTimerDisabled(newPhase == .active)
            }
    }

    private func setIdleTimerDisabled(_ disabled: Bool) {
        // Must run on main — UIApplication state is main-actor isolated.
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
    }
}

extension View {
    /// Keeps the screen awake while this view is visible and the app is active.
    /// Apply on camera, scanning, and long-review screens.
    func keepScreenAwake() -> some View {
        modifier(KeepScreenAwakeModifier())
    }
}
