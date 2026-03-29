import SwiftUI

struct RecoveryView: View {
    let sessionId: String
    @StateObject private var authService = AuthService.shared
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: SSpacing.xl) {
            Image(systemName: "arrow.3.trianglepath")
                .font(.system(size: 60))
                .foregroundColor(Color("sAccent"))
            
            Text("Previous Scans Found")
                .font(SFont.display(24))
                .foregroundColor(Color("sPrimary"))
            
            Text("We found previous body scans linked to this device. Would you like to restore them, or start completely fresh?")
                .font(SFont.body(16))
                .foregroundColor(Color("sSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, SSpacing.lg)
            
            if isProcessing {
                ProgressView()
                    .padding()
            } else {
                VStack(spacing: SSpacing.md) {
                    Button(action: {
                        isProcessing = true
                        Task {
                            await authService.acceptRecovery()
                        }
                    }) {
                        Text("Restore My Data")
                            .font(SFont.label(15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSpacing.md)
                            .background(Color("sAccent"))
                            .foregroundColor(Color("sBackground"))
                            .cornerRadius(SRadius.md)
                    }
                    
                    Button(action: {
                        isProcessing = true
                        Task {
                            await authService.declineRecovery()
                        }
                    }) {
                        Text("Start Fresh (New Account)")
                            .font(SFont.label(15))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSpacing.md)
                            .background(Color("sSurface"))
                            .foregroundColor(Color("sAccent"))
                            .cornerRadius(SRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: SRadius.md)
                                    .stroke(Color("sBorder"), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, SSpacing.lg)
            }
        }
        .padding()
        .background(Color("sBackground").ignoresSafeArea())
    }
}
