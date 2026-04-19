//
//  SyncStatusBadge.swift
//  BodyMeasureAI
//
//  Inline badge that mirrors AppCoordinator.uploadStatus. Reused by results
//  screens so users always know whether the scan reached the admin DB.
//

import SwiftUI

struct SyncStatusBadge: View {
    let status: AppCoordinator.UploadStatus

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .uploading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("SYNCING")
                    .font(SFont.label(9))
                    .tracking(2)
                    .foregroundStyle(Color("sTertiary"))
            }
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color("sTertiary"))
                Text("SYNCED")
                    .font(SFont.label(9))
                    .tracking(2)
                    .foregroundStyle(Color("sTertiary"))
            }
        case .failure:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color("sTertiary"))
                Text("SYNC FAILED")
                    .font(SFont.label(9))
                    .tracking(2)
                    .foregroundStyle(Color("sTertiary"))
            }
        }
    }
}
