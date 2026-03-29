import SwiftUI

struct AppRootView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            switch authService.authState {
            case .uninitialized, .checking:
                ProgressView("Signing in...")
            case .recoveryNeeded(let previousSessionId):
                RecoveryView(sessionId: previousSessionId)
            case .loggedIn:
                ContentView()
            case .error(let error):
                VStack {
                    Text("Error signing in")
                        .font(.headline)
                        .foregroundColor(Color("sError"))
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        Task {
                            await authService.initializeAuth()
                        }
                    }
                    .padding()
                    .background(Color("sAccent"))
                    .foregroundColor(Color("sBackground"))
                    .cornerRadius(8)
                }
            }
        }
        .onAppear {
            Task {
                if case .uninitialized = authService.authState {
                    await authService.initializeAuth()
                }
            }
        }
    }
}
